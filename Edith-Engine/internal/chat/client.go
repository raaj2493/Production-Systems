package chat

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const (
	DefaultGroqBaseURL = "https://api.groq.com/openai/v1"
	DefaultGroqModel   = "llama-3.3-70b-versatile"
	DefaultTimeout     = 45 * time.Second
)

// Message represents a chat completion message role and content.
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// ChatRequest represents the JSON payload sent to Groq Chat Completions.
type ChatRequest struct {
	Model       string    `json:"model"`
	Messages    []Message `json:"messages"`
	Temperature float64   `json:"temperature,omitempty"`
	MaxTokens   int       `json:"max_tokens,omitempty"`
	Stream      bool      `json:"stream,omitempty"`
}

// ChatChoice represents a single completion choice.
type ChatChoice struct {
	Index        int     `json:"index"`
	Message      Message `json:"message"`
	FinishReason string  `json:"finish_reason"`
}

// ChatResponse represents the non-streaming JSON response from Groq.
type ChatResponse struct {
	ID      string       `json:"id"`
	Model   string       `json:"model"`
	Choices []ChatChoice `json:"choices"`
	Error   *GroqError   `json:"error,omitempty"`
}

// StreamDelta represents an incremental text chunk in a streaming response.
type StreamDelta struct {
	Content string `json:"content"`
	Role    string `json:"role,omitempty"`
}

// StreamChoice represents an incremental choice item.
type StreamChoice struct {
	Index        int         `json:"index"`
	Delta        StreamDelta `json:"delta"`
	FinishReason string      `json:"finish_reason,omitempty"`
}

// StreamChunk represents a single SSE chunk emitted by Groq.
type StreamChunk struct {
	ID      string         `json:"id"`
	Model   string         `json:"model"`
	Choices []StreamChoice `json:"choices"`
}

// GroqError represents error details returned by Groq API.
type GroqError struct {
	Message string `json:"message"`
	Type    string `json:"type"`
	Code    string `json:"code,omitempty"`
}

// Client interacts with the Groq API using standard HTTP.
type Client struct {
	apiKey     string
	baseURL    string
	model      string
	httpClient *http.Client
}

// ClientConfig parameters for initializing the Groq Client.
type ClientConfig struct {
	APIKey     string
	BaseURL    string
	Model      string
	HTTPClient *http.Client
	Timeout    time.Duration
}

// NewClient initializes a new Groq API client with safe defaults.
func NewClient(cfg ClientConfig) (*Client, error) {
	key := strings.TrimSpace(cfg.APIKey)
	baseURL := strings.TrimSpace(cfg.BaseURL)
	if baseURL == "" {
		baseURL = DefaultGroqBaseURL
	}
	baseURL = strings.TrimRight(baseURL, "/")

	model := strings.TrimSpace(cfg.Model)
	if model == "" {
		model = DefaultGroqModel
	}

	timeout := cfg.Timeout
	if timeout <= 0 {
		timeout = DefaultTimeout
	}

	httpClient := cfg.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{
			Timeout: timeout,
		}
	}

	return &Client{
		apiKey:     key,
		baseURL:    baseURL,
		model:      model,
		httpClient: httpClient,
	}, nil
}

// Model returns the configured model identifier.
func (c *Client) Model() string {
	return c.model
}

// IsConfigured returns true if an API key has been supplied.
func (c *Client) IsConfigured() bool {
	return c.apiKey != ""
}

// RedactSecret replaces any instance of the API key in a string with [REDACTED].
func (c *Client) RedactSecret(s string) string {
	if c.apiKey == "" {
		return s
	}
	return strings.ReplaceAll(s, c.apiKey, "[REDACTED]")
}

// Complete executes a non-streaming chat completion.
func (c *Client) Complete(ctx context.Context, req *ChatRequest) (*ChatResponse, error) {
	if !c.IsConfigured() {
		return nil, errors.New("GROQ_API_KEY is not configured; please set the environment variable")
	}

	req.Stream = false
	if req.Model == "" {
		req.Model = c.model
	}
	// Groq quirk: temperature=0 can trigger issues; use 0.1 for grounded answers
	if req.Temperature <= 0 {
		req.Temperature = 0.1
	}

	bodyBytes, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed encoding request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/chat/completions", bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("failed creating HTTP request: %w", err)
	}

	httpReq.Header.Set("Authorization", "Bearer "+c.apiKey)
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("request to Groq failed: %s", c.RedactSecret(err.Error()))
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 2*1024*1024)) // 2MB safety bound
	if err != nil {
		return nil, fmt.Errorf("failed reading response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, c.handleHTTPError(resp.StatusCode, respBody)
	}

	var chatResp ChatResponse
	if err := json.Unmarshal(respBody, &chatResp); err != nil {
		return nil, fmt.Errorf("failed parsing Groq response JSON: %w", err)
	}

	// Groq may return an error payload with HTTP 200; check the error field explicitly.
	if chatResp.Error != nil && chatResp.Error.Message != "" {
		return nil, fmt.Errorf("Groq API error: %s", c.RedactSecret(chatResp.Error.Message))
	}

	if len(chatResp.Choices) == 0 {
		return nil, errors.New("received empty choices list from Groq")
	}

	return &chatResp, nil
}

// Stream executes a streaming chat completion, emitting incremental text tokens.
func (c *Client) Stream(ctx context.Context, req *ChatRequest) (<-chan string, <-chan error, error) {
	if !c.IsConfigured() {
		return nil, nil, errors.New("GROQ_API_KEY is not configured; please set the environment variable")
	}

	req.Stream = true
	if req.Model == "" {
		req.Model = c.model
	}
	if req.Temperature <= 0 {
		req.Temperature = 0.1
	}

	bodyBytes, err := json.Marshal(req)
	if err != nil {
		return nil, nil, fmt.Errorf("failed encoding streaming request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/chat/completions", bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, nil, fmt.Errorf("failed creating HTTP request: %w", err)
	}

	httpReq.Header.Set("Authorization", "Bearer "+c.apiKey)
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Accept", "text/event-stream")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, nil, fmt.Errorf("request to Groq failed: %s", c.RedactSecret(err.Error()))
	}

	if resp.StatusCode != http.StatusOK {
		defer resp.Body.Close()
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 64*1024))
		return nil, nil, c.handleHTTPError(resp.StatusCode, respBody)
	}

	tokenChan := make(chan string, 64)
	errChan := make(chan error, 1)

	go func() {
		defer resp.Body.Close()
		defer close(tokenChan)
		defer close(errChan)

		reader := bufio.NewReader(resp.Body)
		for {
			select {
			case <-ctx.Done():
				errChan <- ctx.Err()
				return
			default:
			}

			line, err := reader.ReadString('\n')
			if err != nil {
				if errors.Is(err, io.EOF) {
					return
				}
				errChan <- fmt.Errorf("stream read error: %w", err)
				return
			}

			trimmed := strings.TrimSpace(line)
			if trimmed == "" || strings.HasPrefix(trimmed, ":") {
				continue // Keep-alive comment or empty line
			}

			if !strings.HasPrefix(trimmed, "data: ") {
				continue
			}

			payload := strings.TrimPrefix(trimmed, "data: ")
			if payload == "[DONE]" {
				return
			}

			// Check for an API-level error chunk (e.g. "model output error") before
			// attempting to parse as a normal token chunk.
			var errChunk struct {
				Error *GroqError `json:"error"`
			}
			if json.Unmarshal([]byte(payload), &errChunk) == nil && errChunk.Error != nil && errChunk.Error.Message != "" {
				errChan <- fmt.Errorf("Groq API error: %s", c.RedactSecret(errChunk.Error.Message))
				return
			}

			var chunk StreamChunk
			if err := json.Unmarshal([]byte(payload), &chunk); err != nil {
				continue
			}

			for _, choice := range chunk.Choices {
				if choice.Delta.Content != "" {
					select {
					case tokenChan <- choice.Delta.Content:
					case <-ctx.Done():
						errChan <- ctx.Err()
						return
					}
				}
			}
		}
	}()

	return tokenChan, errChan, nil
}

func (c *Client) handleHTTPError(statusCode int, body []byte) error {
	var groqErr struct {
		Error GroqError `json:"error"`
	}
	_ = json.Unmarshal(body, &groqErr)
	errMsg := groqErr.Error.Message
	if errMsg == "" {
		errMsg = string(body)
	}
	errMsg = c.RedactSecret(errMsg)

	switch statusCode {
	case http.StatusUnauthorized:
		return fmt.Errorf("Groq authentication failed (401): invalid or expired API key. %s", errMsg)
	case http.StatusForbidden:
		return fmt.Errorf("Groq access forbidden (403): %s", errMsg)
	case http.StatusTooManyRequests:
		return fmt.Errorf("Groq rate limit exceeded (429): please wait before retrying. %s", errMsg)
	case http.StatusInternalServerError, http.StatusBadGateway, http.StatusServiceUnavailable:
		return fmt.Errorf("Groq service error (%d): provider temporarily unavailable. %s", statusCode, errMsg)
	default:
		return fmt.Errorf("Groq API error (%d): %s", statusCode, errMsg)
	}
}
