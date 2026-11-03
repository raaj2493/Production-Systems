package store

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"fmt"
	"time"
)

// Conversation represents a persisted local chat thread.
type Conversation struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// ChatMessage represents a single message turn in a conversation.
type ChatMessage struct {
	ID             string    `json:"id"`
	ConversationID string    `json:"conversation_id"`
	Role           string    `json:"role"` // "user" | "assistant"
	Content        string    `json:"content"`
	CitationsJSON  string    `json:"citations_json"` // JSON encoded []Citation
	CreatedAt      time.Time `json:"created_at"`
}

func generateChatID(prefix string) string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return fmt.Sprintf("%s-%d-%s", prefix, time.Now().Unix(), hex.EncodeToString(b))
}

// CreateConversation inserts a new conversation record.
func (db *DB) CreateConversation(title string) (*Conversation, error) {
	if title == "" {
		title = "New Conversation"
	}
	now := time.Now().UTC()
	id := generateChatID("conv")

	query := `INSERT INTO chat_conversations (id, title, created_at_unix, updated_at_unix) VALUES (?, ?, ?, ?)`
	_, err := db.conn.Exec(query, id, title, now.Unix(), now.Unix())
	if err != nil {
		return nil, fmt.Errorf("failed creating conversation: %w", err)
	}

	return &Conversation{
		ID:        id,
		Title:     title,
		CreatedAt: now,
		UpdatedAt: now,
	}, nil
}

// GetConversation retrieves a conversation by ID.
func (db *DB) GetConversation(id string) (*Conversation, error) {
	query := `SELECT id, title, created_at_unix, updated_at_unix FROM chat_conversations WHERE id = ? LIMIT 1`
	row := db.conn.QueryRow(query, id)

	var c Conversation
	var createdUnix, updatedUnix int64
	err := row.Scan(&c.ID, &c.Title, &createdUnix, &updatedUnix)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed getting conversation %s: %w", id, err)
	}

	c.CreatedAt = time.Unix(createdUnix, 0).UTC()
	c.UpdatedAt = time.Unix(updatedUnix, 0).UTC()
	return &c, nil
}

// ListConversations returns all conversations ordered by most recently updated.
func (db *DB) ListConversations() ([]*Conversation, error) {
	query := `SELECT id, title, created_at_unix, updated_at_unix FROM chat_conversations ORDER BY updated_at_unix DESC`
	rows, err := db.conn.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed listing conversations: %w", err)
	}
	defer rows.Close()

	var convs []*Conversation
	for rows.Next() {
		var c Conversation
		var createdUnix, updatedUnix int64
		if err := rows.Scan(&c.ID, &c.Title, &createdUnix, &updatedUnix); err != nil {
			return nil, fmt.Errorf("failed scanning conversation: %w", err)
		}
		c.CreatedAt = time.Unix(createdUnix, 0).UTC()
		c.UpdatedAt = time.Unix(updatedUnix, 0).UTC()
		convs = append(convs, &c)
	}
	return convs, rows.Err()
}

// UpdateConversationTitle updates the display title and updated timestamp.
func (db *DB) UpdateConversationTitle(id, title string) error {
	query := `UPDATE chat_conversations SET title = ?, updated_at_unix = ? WHERE id = ?`
	_, err := db.conn.Exec(query, title, time.Now().UTC().Unix(), id)
	return err
}

// DeleteConversation deletes a conversation and all its messages (via cascade).
func (db *DB) DeleteConversation(id string) error {
	query := `DELETE FROM chat_conversations WHERE id = ?`
	_, err := db.conn.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed deleting conversation: %w", err)
	}
	return nil
}

// ClearAllConversations deletes all conversation records and messages. Never touches vault notes.
func (db *DB) ClearAllConversations() error {
	_, err := db.conn.Exec(`DELETE FROM chat_conversations`)
	if err != nil {
		return fmt.Errorf("failed clearing conversations: %w", err)
	}
	return nil
}

// AddChatMessage stores a message turn in a conversation.
func (db *DB) AddChatMessage(msg *ChatMessage) error {
	if msg.ID == "" {
		msg.ID = generateChatID("msg")
	}
	if msg.CreatedAt.IsZero() {
		msg.CreatedAt = time.Now().UTC()
	}
	if msg.CitationsJSON == "" {
		msg.CitationsJSON = "[]"
	}

	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed beginning transaction: %w", err)
	}
	defer tx.Rollback()

	msgQuery := `INSERT INTO chat_messages (id, conversation_id, role, content, citations_json, created_at_unix)
	             VALUES (?, ?, ?, ?, ?, ?)`
	_, err = tx.Exec(msgQuery, msg.ID, msg.ConversationID, msg.Role, msg.Content, msg.CitationsJSON, msg.CreatedAt.Unix())
	if err != nil {
		return fmt.Errorf("failed inserting message: %w", err)
	}

	updateQuery := `UPDATE chat_conversations SET updated_at_unix = ? WHERE id = ?`
	_, err = tx.Exec(updateQuery, msg.CreatedAt.Unix(), msg.ConversationID)
	if err != nil {
		return fmt.Errorf("failed updating conversation timestamp: %w", err)
	}

	return tx.Commit()
}

// GetChatMessages retrieves all messages for a conversation ordered chronologically.
func (db *DB) GetChatMessages(conversationID string) ([]*ChatMessage, error) {
	query := `SELECT id, conversation_id, role, content, citations_json, created_at_unix
	          FROM chat_messages WHERE conversation_id = ? ORDER BY created_at_unix ASC`
	rows, err := db.conn.Query(query, conversationID)
	if err != nil {
		return nil, fmt.Errorf("failed querying chat messages: %w", err)
	}
	defer rows.Close()

	var msgs []*ChatMessage
	for rows.Next() {
		var m ChatMessage
		var createdUnix int64
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.Role, &m.Content, &m.CitationsJSON, &createdUnix); err != nil {
			return nil, fmt.Errorf("failed scanning chat message: %w", err)
		}
		m.CreatedAt = time.Unix(createdUnix, 0).UTC()
		msgs = append(msgs, &m)
	}
	return msgs, rows.Err()
}
