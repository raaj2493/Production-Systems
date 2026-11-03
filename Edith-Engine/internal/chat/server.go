package chat

import (
	"context"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"

	"edith-engine/internal/store"
	"edith-engine/internal/workflows"
)

//go:embed web/*
var webFS embed.FS

// ServerConfig defines configuration parameters for the Edith Chat local HTTP server.
type ServerConfig struct {
	Addr         string        // e.g. "127.0.0.1:8080"
	Service      *Service      // Grounded chat service instance
	VaultPath    string        // Display path for authoritative vault
	ReadTimeout  time.Duration // Default 30s
	WriteTimeout time.Duration // Default 60s
}

// Server provides the local HTTP server hosting the Chatbox UI and API endpoints.
type Server struct {
	addr      string
	service   *Service
	vaultPath string
	mux       *http.ServeMux
	httpSrv   *http.Server
	listener  net.Listener
}

// NewServer initializes the local chat server with safe route handling and security middleware.
func NewServer(cfg ServerConfig) (*Server, error) {
	if cfg.Service == nil {
		return nil, errors.New("chat service is required")
	}

	addr := strings.TrimSpace(cfg.Addr)
	if addr == "" {
		addr = "127.0.0.1:8080"
	}

	readTimeout := cfg.ReadTimeout
	if readTimeout <= 0 {
		readTimeout = 30 * time.Second
	}
	writeTimeout := cfg.WriteTimeout
	if writeTimeout <= 0 {
		writeTimeout = 90 * time.Second // streaming may take up to 90s
	}

	s := &Server{
		addr:      addr,
		service:   cfg.Service,
		vaultPath: cfg.VaultPath,
		mux:       http.NewServeMux(),
	}

	s.registerRoutes()

	s.httpSrv = &http.Server{
		Addr:         addr,
		Handler:      s.securityMiddleware(s.mux),
		ReadTimeout:  readTimeout,
		WriteTimeout: writeTimeout,
	}

	return s, nil
}

// Handler returns the root HTTP handler with security middleware applied (useful for tests).
func (s *Server) Handler() http.Handler {
	return s.securityMiddleware(s.mux)
}

// Start begins listening on the configured address.
func (s *Server) Start() error {
	ln, err := net.Listen("tcp", s.addr)
	if err != nil {
		return fmt.Errorf("failed to bind server to %s: %w", s.addr, err)
	}
	s.listener = ln
	return s.httpSrv.Serve(ln)
}

// Addr returns the bound network address.
func (s *Server) Addr() string {
	if s.listener != nil {
		return s.listener.Addr().String()
	}
	return s.addr
}

// Shutdown gracefully shuts down the server without interrupting active connections.
func (s *Server) Shutdown(ctx context.Context) error {
	if s.httpSrv != nil {
		return s.httpSrv.Shutdown(ctx)
	}
	return nil
}

func (s *Server) registerRoutes() {
	// API routes
	s.mux.HandleFunc("GET /api/v1/health", s.handleHealth)
	s.mux.HandleFunc("GET /api/v1/status", s.handleStatus)
	s.mux.HandleFunc("POST /api/v1/chat", s.handleChat)
	s.mux.HandleFunc("POST /api/v1/chat/stream", s.handleChatStream)
	s.mux.HandleFunc("POST /api/v1/capture", s.handleCapture)

	// Conversations persistence routes
	s.mux.HandleFunc("GET /api/v1/conversations", s.handleListConversations)
	s.mux.HandleFunc("POST /api/v1/conversations", s.handleCreateConversation)
	s.mux.HandleFunc("DELETE /api/v1/conversations", s.handleClearConversations)
	s.mux.HandleFunc("GET /api/v1/conversations/", s.handleGetConversation)
	s.mux.HandleFunc("DELETE /api/v1/conversations/", s.handleDeleteConversation)

	// Static web assets
	s.mux.HandleFunc("GET /", s.handleStaticIndex)
	s.mux.HandleFunc("GET /style.css", s.handleStaticCSS)
	s.mux.HandleFunc("GET /app.js", s.handleStaticJS)
}

// --- Middleware ---

func (s *Server) securityMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 1. Security Headers
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Content-Security-Policy", "default-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'; script-src 'self' 'unsafe-inline';")

		// 2. Validate Origin for mutating actions (CSRF protection)
		if r.Method == http.MethodPost || r.Method == http.MethodDelete || r.Method == http.MethodPut {
			origin := r.Header.Get("Origin")
			if origin != "" {
				if !isAllowedLocalOrigin(origin) {
					writeJSONError(w, http.StatusForbidden, "Forbidden cross-origin request")
					return
				}
			}
		}

		// 3. Request body size limit (1 MB max)
		r.Body = http.MaxBytesReader(w, r.Body, 1024*1024)

		next.ServeHTTP(w, r)
	})
}

func isAllowedLocalOrigin(origin string) bool {
	// Strip scheme
	trimmed := strings.TrimPrefix(origin, "http://")
	trimmed = strings.TrimPrefix(trimmed, "https://")

	host := trimmed
	if idx := strings.Index(host, "/"); idx != -1 {
		host = host[:idx]
	}

	hostname := host
	if h, _, err := net.SplitHostPort(host); err == nil {
		hostname = h
	}

	return hostname == "127.0.0.1" || hostname == "localhost"
}

// --- Static Handlers ---

func (s *Server) handleStaticIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	content, err := webFS.ReadFile("web/index.html")
	if err != nil {
		http.Error(w, "Asset not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write(content)
}

func (s *Server) handleStaticCSS(w http.ResponseWriter, r *http.Request) {
	content, err := webFS.ReadFile("web/style.css")
	if err != nil {
		http.Error(w, "Asset not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "text/css; charset=utf-8")
	_, _ = w.Write(content)
}

func (s *Server) handleStaticJS(w http.ResponseWriter, r *http.Request) {
	content, err := webFS.ReadFile("web/app.js")
	if err != nil {
		http.Error(w, "Asset not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/javascript; charset=utf-8")
	_, _ = w.Write(content)
}

// --- API Handlers ---

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
	})
}

type StatusResponse struct {
	Ready              bool   `json:"ready"`
	GroqConfigured     bool   `json:"groq_configured"`
	Model              string `json:"model"`
	VaultPath          string `json:"vault_path"`
	ConversationsCount int    `json:"conversations_count"`
}

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	var count int
	if db := s.service.DB(); db != nil {
		convs, err := db.ListConversations()
		if err == nil {
			count = len(convs)
		}
	}

	writeJSON(w, http.StatusOK, StatusResponse{
		Ready:              true,
		GroqConfigured:     s.service.Client().IsConfigured(),
		Model:              s.service.Client().Model(),
		VaultPath:          s.vaultPath,
		ConversationsCount: count,
	})
}

type ChatAPIRequest struct {
	ConversationID string   `json:"conversation_id"`
	Question       string   `json:"question"`
	SelectedNotes  []string `json:"selected_notes,omitempty"`
}

func (s *Server) handleChat(w http.ResponseWriter, r *http.Request) {
	if !strings.HasPrefix(r.Header.Get("Content-Type"), "application/json") {
		writeJSONError(w, http.StatusBadRequest, "Content-Type must be application/json")
		return
	}

	var req ChatAPIRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSONError(w, http.StatusBadRequest, "Invalid JSON payload: "+err.Error())
		return
	}

	if strings.TrimSpace(req.Question) == "" {
		writeJSONError(w, http.StatusBadRequest, "Question cannot be empty")
		return
	}

	turnResp, err := s.service.Ask(r.Context(), req.ConversationID, req.Question, req.SelectedNotes)
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, s.service.Client().RedactSecret(err.Error()))
		return
	}

	writeJSON(w, http.StatusOK, turnResp)
}

func (s *Server) handleChatStream(w http.ResponseWriter, r *http.Request) {
	if !strings.HasPrefix(r.Header.Get("Content-Type"), "application/json") {
		writeJSONError(w, http.StatusBadRequest, "Content-Type must be application/json")
		return
	}

	var req ChatAPIRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSONError(w, http.StatusBadRequest, "Invalid JSON payload: "+err.Error())
		return
	}

	if strings.TrimSpace(req.Question) == "" {
		writeJSONError(w, http.StatusBadRequest, "Question cannot be empty")
		return
	}

	flusher, ok := w.(http.Flusher)
	if !ok {
		writeJSONError(w, http.StatusInternalServerError, "Streaming unsupported by server connection")
		return
	}

	// Set SSE response headers
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	onToken := func(token string) error {
		payload, _ := json.Marshal(map[string]string{"token": token})
		_, err := fmt.Fprintf(w, "data: %s\n\n", payload)
		if err != nil {
			return err
		}
		flusher.Flush()
		return nil
	}

	turnResp, err := s.service.AskStream(r.Context(), req.ConversationID, req.Question, req.SelectedNotes, onToken)
	if err != nil {
		errPayload, _ := json.Marshal(map[string]string{"error": s.service.Client().RedactSecret(err.Error())})
		_, _ = fmt.Fprintf(w, "data: %s\n\n", errPayload)
		flusher.Flush()
		return
	}

	// Send complete event payload with citations and metadata
	completePayload, _ := json.Marshal(turnResp)
	_, _ = fmt.Fprintf(w, "data: %s\n\n", completePayload)
	_, _ = fmt.Fprintf(w, "data: [DONE]\n\n")
	flusher.Flush()
}

type CaptureAPIRequest struct {
	Content        string `json:"content"`
	FilePath       string `json:"file_path,omitempty"`
	ForcedCategory string `json:"category,omitempty"`
	TargetNote     string `json:"target_note,omitempty"`
	Author         string `json:"author,omitempty"`
	URL            string `json:"url,omitempty"`
}

func (s *Server) handleCapture(w http.ResponseWriter, r *http.Request) {
	if !strings.HasPrefix(r.Header.Get("Content-Type"), "application/json") {
		writeJSONError(w, http.StatusBadRequest, "Content-Type must be application/json")
		return
	}

	var req CaptureAPIRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSONError(w, http.StatusBadRequest, "Invalid JSON payload: "+err.Error())
		return
	}

	if strings.TrimSpace(req.Content) == "" && strings.TrimSpace(req.FilePath) == "" {
		writeJSONError(w, http.StatusBadRequest, "Either content or file_path must be provided")
		return
	}

	report, err := s.service.Capture(r.Context(), workflows.CaptureRequest{
		RawContent:     req.Content,
		FilePath:       req.FilePath,
		ForcedCategory: req.ForcedCategory,
		TargetNote:     req.TargetNote,
		Author:         req.Author,
		URL:            req.URL,
	})
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, report)
}

// --- Conversations API Handlers ---

func (s *Server) handleListConversations(w http.ResponseWriter, r *http.Request) {
	db := s.service.DB()
	if db == nil {
		writeJSON(w, http.StatusOK, []*store.Conversation{})
		return
	}

	convs, err := db.ListConversations()
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, "Failed to list conversations: "+err.Error())
		return
	}

	if convs == nil {
		convs = []*store.Conversation{}
	}
	writeJSON(w, http.StatusOK, convs)
}

type CreateConversationRequest struct {
	Title string `json:"title"`
}

func (s *Server) handleCreateConversation(w http.ResponseWriter, r *http.Request) {
	db := s.service.DB()
	if db == nil {
		writeJSONError(w, http.StatusServiceUnavailable, "Conversation persistence is disabled")
		return
	}

	var req CreateConversationRequest
	_ = json.NewDecoder(r.Body).Decode(&req)

	title := strings.TrimSpace(req.Title)
	if title == "" {
		title = "New Conversation"
	}

	conv, err := db.CreateConversation(title)
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, "Failed to create conversation: "+err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, conv)
}

type ConversationDetailResponse struct {
	Conversation *store.Conversation  `json:"conversation"`
	Messages     []*store.ChatMessage `json:"messages"`
}

func (s *Server) handleGetConversation(w http.ResponseWriter, r *http.Request) {
	db := s.service.DB()
	if db == nil {
		writeJSONError(w, http.StatusNotFound, "Conversation not found")
		return
	}

	id := strings.TrimPrefix(r.URL.Path, "/api/v1/conversations/")
	id = strings.TrimSpace(id)
	if id == "" {
		writeJSONError(w, http.StatusBadRequest, "Missing conversation ID")
		return
	}

	conv, err := db.GetConversation(id)
	if err != nil {
		writeJSONError(w, http.StatusNotFound, "Conversation not found")
		return
	}

	msgs, err := db.GetChatMessages(id)
	if err != nil {
		msgs = []*store.ChatMessage{}
	}

	writeJSON(w, http.StatusOK, ConversationDetailResponse{
		Conversation: conv,
		Messages:     msgs,
	})
}

func (s *Server) handleDeleteConversation(w http.ResponseWriter, r *http.Request) {
	db := s.service.DB()
	if db == nil {
		writeJSONError(w, http.StatusServiceUnavailable, "Conversation persistence is disabled")
		return
	}

	id := strings.TrimPrefix(r.URL.Path, "/api/v1/conversations/")
	id = strings.TrimSpace(id)
	if id == "" {
		writeJSONError(w, http.StatusBadRequest, "Missing conversation ID")
		return
	}

	if err := db.DeleteConversation(id); err != nil {
		writeJSONError(w, http.StatusInternalServerError, "Failed to delete conversation: "+err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"deleted": true,
		"id":      id,
	})
}

func (s *Server) handleClearConversations(w http.ResponseWriter, r *http.Request) {
	db := s.service.DB()
	if db == nil {
		writeJSONError(w, http.StatusServiceUnavailable, "Conversation persistence is disabled")
		return
	}

	if err := db.ClearAllConversations(); err != nil {
		writeJSONError(w, http.StatusInternalServerError, "Failed to clear conversations: "+err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"cleared": true,
	})
}

// --- JSON Helpers ---

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func writeJSONError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"error": message,
	})
}

// ReadCloserHelper for tests if needed
type nopCloser struct {
	io.Reader
}

func (nopCloser) Close() error { return nil }
