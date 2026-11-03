package chat

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestClientMissingAPIKey(t *testing.T) {
	client, err := NewClient(ClientConfig{APIKey: ""})
	if err != nil {
		t.Fatalf("NewClient failed: %v", err)
	}

	_, err = client.Complete(context.Background(), &ChatRequest{
		Messages: []Message{{Role: "user", Content: "Hello"}},
	})
	if err == nil || !strings.Contains(err.Error(), "GROQ_API_KEY is not configured") {
		t.Fatalf("expected missing API key error, got: %v", err)
	}

	_, _, err = client.Stream(context.Background(), &ChatRequest{
		Messages: []Message{{Role: "user", Content: "Hello"}},
	})
	if err == nil || !strings.Contains(err.Error(), "GROQ_API_KEY is not configured") {
		t.Fatalf("expected missing API key error on stream, got: %v", err)
	}
}

func TestClientSuccessfulCompletion(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer test-secret-key" {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintln(w, `{
			"id": "chatcmpl-123",
			"model": "llama-3.3-70b-versatile",
			"choices": [
				{
					"index": 0,
					"message": {
						"role": "assistant",
						"content": "According to your notes [S1], consensus is achieved through state machine replication."
					},
					"finish_reason": "stop"
				}
			]
		}`)
	}))
	defer ts.Close()

	client, err := NewClient(ClientConfig{
		APIKey:  "test-secret-key",
		BaseURL: ts.URL,
	})
	if err != nil {
		t.Fatalf("NewClient failed: %v", err)
	}

	resp, err := client.Complete(context.Background(), &ChatRequest{
		Messages: []Message{{Role: "user", Content: "What is consensus?"}},
	})
	if err != nil {
		t.Fatalf("Complete failed: %v", err)
	}

	content := resp.Choices[0].Message.Content
	if !strings.Contains(content, "[S1]") {
		t.Errorf("expected citation [S1] in response, got: %s", content)
	}
}

func TestClientSuccessfulStreaming(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		flusher, ok := w.(http.Flusher)
		if !ok {
			t.Fatalf("expected flusher")
		}

		chunks := []string{
			`data: {"id":"1","choices":[{"delta":{"content":"Consensus "}}]}`,
			`data: {"id":"2","choices":[{"delta":{"content":"requires "}}]}`,
			`data: {"id":"3","choices":[{"delta":{"content":"quorum [S1]."}}]}`,
			`data: [DONE]`,
		}

		for _, c := range chunks {
			fmt.Fprintf(w, "%s\n\n", c)
			flusher.Flush()
			time.Sleep(10 * time.Millisecond)
		}
	}))
	defer ts.Close()

	client, err := NewClient(ClientConfig{
		APIKey:  "test-key",
		BaseURL: ts.URL,
	})
	if err != nil {
		t.Fatalf("NewClient failed: %v", err)
	}

	tokenChan, errChan, err := client.Stream(context.Background(), &ChatRequest{
		Messages: []Message{{Role: "user", Content: "Explain consensus"}},
	})
	if err != nil {
		t.Fatalf("Stream failed: %v", err)
	}

	var sb strings.Builder
	for token := range tokenChan {
		sb.WriteString(token)
	}
	for err := range errChan {
		if err != nil {
			t.Fatalf("stream error: %v", err)
		}
	}

	result := sb.String()
	if result != "Consensus requires quorum [S1]." {
		t.Errorf("unexpected streamed text: %q", result)
	}
}

func TestClientErrorHandlingAndSecretRedaction(t *testing.T) {
	secretKey := "gsk_supersecret123456789"

	tests := []struct {
		name       string
		statusCode int
		body       string
		wantErr    string
	}{
		{
			name:       "401 Unauthorized",
			statusCode: http.StatusUnauthorized,
			body:       `{"error":{"message":"Invalid API Key: ` + secretKey + `"}}`,
			wantErr:    "Groq authentication failed (401)",
		},
		{
			name:       "429 Rate Limit",
			statusCode: http.StatusTooManyRequests,
			body:       `{"error":{"message":"Rate limit exceeded for key ` + secretKey + `"}}`,
			wantErr:    "Groq rate limit exceeded (429)",
		},
		{
			name:       "503 Service Unavailable",
			statusCode: http.StatusServiceUnavailable,
			body:       `{"error":{"message":"Service down"}}`,
			wantErr:    "Groq service error (503)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(tt.statusCode)
				w.Write([]byte(tt.body))
			}))
			defer ts.Close()

			client, err := NewClient(ClientConfig{
				APIKey:  secretKey,
				BaseURL: ts.URL,
			})
			if err != nil {
				t.Fatalf("NewClient failed: %v", err)
			}

			_, err = client.Complete(context.Background(), &ChatRequest{
				Messages: []Message{{Role: "user", Content: "Hello"}},
			})
			if err == nil {
				t.Fatalf("expected error, got nil")
			}

			errMsg := err.Error()
			if !strings.Contains(errMsg, tt.wantErr) {
				t.Errorf("expected error containing %q, got: %s", tt.wantErr, errMsg)
			}
			if strings.Contains(errMsg, secretKey) {
				t.Errorf("security leak: API key was not redacted from error message: %s", errMsg)
			}
		})
	}
}

func TestClientContextCancellation(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(200 * time.Millisecond)
		w.WriteHeader(http.StatusOK)
	}))
	defer ts.Close()

	client, _ := NewClient(ClientConfig{
		APIKey:  "key",
		BaseURL: ts.URL,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()

	_, err := client.Complete(ctx, &ChatRequest{
		Messages: []Message{{Role: "user", Content: "Hello"}},
	})
	if err == nil || !strings.Contains(err.Error(), "context deadline exceeded") {
		t.Fatalf("expected deadline exceeded error, got: %v", err)
	}
}
