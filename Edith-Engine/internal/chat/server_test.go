package chat_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"edith-engine/internal/chat"
	"edith-engine/internal/config"
	"edith-engine/internal/engine"
	"edith-engine/internal/store"
)

func setupTestServer(t *testing.T, mockGroqHandler http.HandlerFunc) (*chat.Server, *store.DB, string, func()) {
	t.Helper()

	tempDir := t.TempDir()
	vaultDir := filepath.Join(tempDir, "vault")
	_ = os.MkdirAll(vaultDir, 0755)
	raftNote := `# Raft Consensus
Raft is a consensus algorithm designed to be easy to understand.
Safety is guaranteed through state machine safety and leader election invariants.
`
	_ = os.WriteFile(filepath.Join(vaultDir, "Raft.md"), []byte(raftNote), 0644)

	dbPath := filepath.Join(tempDir, "edith.db")
	cfg := &config.Config{
		VaultPath: vaultDir,
		DBPath:    dbPath,
	}

	eng, err := engine.New(cfg)
	if err != nil {
		t.Fatalf("engine.New failed: %v", err)
	}

	db, err := store.Open(dbPath)
	if err != nil {
		t.Fatalf("store.Open failed: %v", err)
	}

	if _, err := eng.Index(); err != nil {
		t.Fatalf("failed to index vault: %v", err)
	}

	var mockGroqSrv *httptest.Server
	if mockGroqHandler != nil {
		mockGroqSrv = httptest.NewServer(mockGroqHandler)
	} else {
		mockGroqSrv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			resp := chat.ChatResponse{
				ID:    "mock-turn",
				Model: "llama-3.3-70b-versatile",
				Choices: []chat.ChatChoice{
					{
						Index: 0,
						Message: chat.Message{
							Role:    "assistant",
							Content: "Raft provides safety through state machine safety [S1].",
						},
						FinishReason: "stop",
					},
				},
			}
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(resp)
		}))
	}

	client, err := chat.NewClient(chat.ClientConfig{
		APIKey:  "gsk_test_secret_key_12345",
		BaseURL: mockGroqSrv.URL,
		Model:   "llama-3.3-70b-versatile",
	})
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	service := chat.NewService(chat.ServiceConfig{
		Engine:          eng,
		Client:          client,
		DB:              db,
		MaxContextBytes: 16384,
	})

	srv, err := chat.NewServer(chat.ServerConfig{
		Addr:      "127.0.0.1:8080",
		Service:   service,
		VaultPath: vaultDir,
	})
	if err != nil {
		t.Fatalf("failed to create server: %v", err)
	}

	cleanup := func() {
		mockGroqSrv.Close()
		_ = db.Close()
		_ = eng.Close()
	}

	return srv, db, vaultDir, cleanup
}

func TestServer_StaticAssets(t *testing.T) {
	srv, _, _, cleanup := setupTestServer(t, nil)
	defer cleanup()

	handler := srv.Handler()

	// 1. GET / -> index.html
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for /, got %d", w.Code)
	}
	body := w.Body.String()
	if !strings.Contains(body, "EDITH") || !strings.Contains(body, "app.js") {
		t.Fatalf("index.html body missing expected content: %s", body)
	}

	// 2. GET /style.css
	req = httptest.NewRequest(http.MethodGet, "/style.css", nil)
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for /style.css, got %d", w.Code)
	}
	if !strings.Contains(w.Header().Get("Content-Type"), "text/css") {
		t.Fatalf("expected text/css content type, got %s", w.Header().Get("Content-Type"))
	}

	// 3. GET /app.js
	req = httptest.NewRequest(http.MethodGet, "/app.js", nil)
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for /app.js, got %d", w.Code)
	}
	if !strings.Contains(w.Header().Get("Content-Type"), "application/javascript") {
		t.Fatalf("expected application/javascript content type, got %s", w.Header().Get("Content-Type"))
	}
}

func TestServer_HealthAndStatus(t *testing.T) {
	srv, _, vaultDir, cleanup := setupTestServer(t, nil)
	defer cleanup()

	handler := srv.Handler()

	// Health
	req := httptest.NewRequest(http.MethodGet, "/api/v1/health", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for health, got %d", w.Code)
	}
	var health map[string]string
	_ = json.Unmarshal(w.Body.Bytes(), &health)
	if health["status"] != "ok" {
		t.Fatalf("expected status: ok, got: %v", health)
	}

	// Status
	req = httptest.NewRequest(http.MethodGet, "/api/v1/status", nil)
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for status, got %d", w.Code)
	}

	var status chat.StatusResponse
	_ = json.Unmarshal(w.Body.Bytes(), &status)

	if !status.Ready {
		t.Error("expected ready: true")
	}
	if !status.GroqConfigured {
		t.Error("expected groq_configured: true")
	}
	if status.Model != "llama-3.3-70b-versatile" {
		t.Errorf("expected model llama-3.3-70b-versatile, got %s", status.Model)
	}
	if status.VaultPath != vaultDir {
		t.Errorf("expected vault path %s, got %s", vaultDir, status.VaultPath)
	}

	// Crucial: ensure no API key or secrets leaked in JSON response!
	rawStatus := w.Body.String()
	if strings.Contains(rawStatus, "gsk_test_secret_key_12345") {
		t.Fatal("SECURITY ERROR: API key leaked in /api/v1/status response!")
	}
}

func TestServer_ChatNonStreaming(t *testing.T) {
	srv, _, _, cleanup := setupTestServer(t, nil)
	defer cleanup()

	handler := srv.Handler()

	// 1. Successful question
	chatPayload := `{"question": "What provides safety in Raft?"}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d, body: %s", w.Code, w.Body.String())
	}

	var turn chat.ChatTurnResponse
	if err := json.Unmarshal(w.Body.Bytes(), &turn); err != nil {
		t.Fatalf("failed to decode ChatTurnResponse: %v", err)
	}

	if !strings.Contains(turn.Answer, "Raft provides safety") {
		t.Errorf("unexpected answer: %s", turn.Answer)
	}
	if len(turn.Citations) == 0 {
		t.Errorf("expected at least 1 validated citation, got 0")
	} else if turn.Citations[0].RelPath != "Raft.md" {
		t.Errorf("expected citation rel_path Raft.md, got %s", turn.Citations[0].RelPath)
	}

	// 2. Missing question
	badPayload := `{"question": "   "}`
	req = httptest.NewRequest(http.MethodPost, "/api/v1/chat", strings.NewReader(badPayload))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for empty question, got %d", w.Code)
	}

	// 3. Non-JSON Content-Type
	req = httptest.NewRequest(http.MethodPost, "/api/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Content-Type", "text/plain")
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for text/plain, got %d", w.Code)
	}
}

func TestServer_ChatStreaming(t *testing.T) {
	mockStreamHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		flusher, _ := w.(http.Flusher)

		chunks := []string{
			`data: {"choices":[{"delta":{"content":"Safety "}}]}`,
			`data: {"choices":[{"delta":{"content":"in Raft "}}]}`,
			`data: {"choices":[{"delta":{"content":"is guaranteed [S1]."}}]}`,
			`data: [DONE]`,
		}
		for _, c := range chunks {
			_, _ = fmt.Fprintf(w, "%s\n\n", c)
			flusher.Flush()
			time.Sleep(5 * time.Millisecond)
		}
	})

	srv, _, _, cleanup := setupTestServer(t, mockStreamHandler)
	defer cleanup()

	handler := srv.Handler()

	chatPayload := `{"question": "How is safety guaranteed in Raft?"}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/chat/stream", strings.NewReader(chatPayload))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d, body: %s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Header().Get("Content-Type"), "text/event-stream") {
		t.Fatalf("expected text/event-stream, got %s", w.Header().Get("Content-Type"))
	}

	body := w.Body.String()
	if !strings.Contains(body, `{"token":"Safety "}`) {
		t.Errorf("stream missing token 'Safety ': %s", body)
	}
	if !strings.Contains(body, `[DONE]`) {
		t.Errorf("stream missing [DONE]: %s", body)
	}
}

func TestServer_SecurityOriginAndBodyLimits(t *testing.T) {
	srv, _, _, cleanup := setupTestServer(t, nil)
	defer cleanup()

	handler := srv.Handler()

	// 1. Cross-Origin CSRF attack from unauthorized origin
	chatPayload := `{"question": "Explain Raft"}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Origin", "http://malicious-website.com")
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Errorf("expected 403 Forbidden for malicious origin, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "Forbidden cross-origin") {
		t.Errorf("expected error message in body, got %s", w.Body.String())
	}

	// 2. Allowed local origin
	req = httptest.NewRequest(http.MethodPost, "/api/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Origin", "http://127.0.0.1:8080")
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200 for local 127.0.0.1 origin, got %d", w.Code)
	}

	// 3. Body limit (> 1MB)
	largeBody := bytes.Repeat([]byte("A"), 1024*1024+100)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/chat", bytes.NewReader(largeBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code == http.StatusOK {
		t.Errorf("expected failure for >1MB body, got 200 OK")
	}
}

func TestServer_ConversationsPersistenceAPI(t *testing.T) {
	srv, db, _, cleanup := setupTestServer(t, nil)
	defer cleanup()

	handler := srv.Handler()

	// 1. Create Conversation
	createPayload := `{"title": "Distributed Systems Study"}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/conversations", strings.NewReader(createPayload))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created, got %d: %s", w.Code, w.Body.String())
	}
	var created store.Conversation
	_ = json.Unmarshal(w.Body.Bytes(), &created)
	if created.Title != "Distributed Systems Study" || created.ID == "" {
		t.Fatalf("unexpected conversation: %+v", created)
	}

	// 2. List Conversations
	req = httptest.NewRequest(http.MethodGet, "/api/v1/conversations", nil)
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var list []*store.Conversation
	_ = json.Unmarshal(w.Body.Bytes(), &list)
	if len(list) != 1 || list[0].ID != created.ID {
		t.Fatalf("expected 1 conversation matching id %s, got %+v", created.ID, list)
	}

	// 3. Add message via Chat API and Get Conversation
	chatPayload := fmt.Sprintf(`{"conversation_id": "%s", "question": "What is Raft?"}`, created.ID)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for chat, got %d", w.Code)
	}

	// 4. Get Conversation with messages
	req = httptest.NewRequest(http.MethodGet, "/api/v1/conversations/"+created.ID, nil)
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var detail chat.ConversationDetailResponse
	_ = json.Unmarshal(w.Body.Bytes(), &detail)
	if detail.Conversation == nil || len(detail.Messages) < 2 {
		t.Fatalf("expected conversation and at least 2 messages (user + assistant), got %d messages", len(detail.Messages))
	}

	// 5. Delete single conversation
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/conversations/"+created.ID, nil)
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for delete, got %d", w.Code)
	}

	// Verify conversation is gone from db
	c, _ := db.GetConversation(created.ID)
	if c != nil {
		t.Errorf("expected conversation %s to be deleted from DB", created.ID)
	}

	// 6. Clear all conversations
	_, _ = db.CreateConversation("Another Conv")
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/conversations", nil)
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for clear all, got %d", w.Code)
	}
	remaining, _ := db.ListConversations()
	if len(remaining) != 0 {
		t.Fatalf("expected 0 conversations remaining, got %d", len(remaining))
	}
}

func TestChatServer_UIRenderingAndAssets(t *testing.T) {
	srv, _, _, cleanup := setupTestServer(t, nil)
	defer cleanup()

	handler := srv.Handler()

	// 1. Check index.html serving
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for root, got %d", w.Code)
	}
	html := w.Body.String()
	if !strings.Contains(html, "EDITH") || !strings.Contains(html, "app.js") {
		t.Errorf("expected EDITH brand and app.js reference in index.html")
	}

	// 2. Check app.js static script serving and contents
	req = httptest.NewRequest(http.MethodGet, "/app.js", nil)
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for app.js, got %d", w.Code)
	}
	appJS := w.Body.String()

	// Verify duplicate Sources block suppression in Markdown renderer
	if !strings.Contains(appJS, "Sources|References") {
		t.Errorf("expected duplicate Sources/References suppression regex in app.js")
	}

	// Verify SVG attributes for valid SVG DOM rendering
	if !strings.Contains(appJS, `xmlns="http://www.w3.org/2000/svg"`) {
		t.Errorf("expected SVG xmlns attribute in app.js")
	}
	if !strings.Contains(appJS, `aria-hidden="true"`) {
		t.Errorf("expected aria-hidden in app.js SVG definitions")
	}

	// Verify insufficient evidence warning message
	if !strings.Contains(appJS, "No matching notes were retrieved from your vault") {
		t.Errorf("expected honest missing evidence message in app.js")
	}

	// 3. Check style.css serving and flex-shrink rules for SVGs
	req = httptest.NewRequest(http.MethodGet, "/style.css", nil)
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for style.css, got %d", w.Code)
	}
	css := w.Body.String()
	if !strings.Contains(css, "flex-shrink: 0") {
		t.Errorf("expected flex-shrink: 0 for SVGs in style.css")
	}
}

func TestServer_CaptureAPI(t *testing.T) {
	srv, _, _, cleanup := setupTestServer(t, nil)
	defer cleanup()

	handler := srv.Handler()

	// 1. Post capture
	payload := `{"content": "# LSM Trees\nLog-structured merge-trees handle high write throughput."}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/capture", strings.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for /api/v1/capture, got %d: %s", w.Code, w.Body.String())
	}
	respBody := w.Body.String()
	if !strings.Contains(respBody, "LSM Trees") || !strings.Contains(respBody, "knowledge") {
		t.Errorf("unexpected capture response: %s", respBody)
	}

	// 2. Empty payload rejected
	req = httptest.NewRequest(http.MethodPost, "/api/v1/capture", strings.NewReader(`{}`))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for empty capture payload, got %d", w.Code)
	}
}
