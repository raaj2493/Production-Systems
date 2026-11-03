package chat_test

import (
	"testing"

	"edith-engine/internal/chat"
)

func TestClassifyIntent(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected chat.Intent
	}{
		// 1. Casual Conversation & Personal Updates
		{
			name:     "Personal progress update from prompt",
			input:    "Today I worked on Edith's intelligent capture system. I tested how it classifies notes and learned why preserving original content matters. Tomorrow I want to test search freshness and review the remaining safety checks.",
			expected: chat.IntentCaptureRequest,
		},
		{
			name:     "Excited personal realization",
			input:    "I finally understand database indexes!",
			expected: chat.IntentConversation,
		},
		{
			name:     "Casual greeting",
			input:    "Hello Edith! How are you today?",
			expected: chat.IntentConversation,
		},
		{
			name:     "Polite greeting",
			input:    "Good morning!",
			expected: chat.IntentConversation,
		},
		{
			name:     "Gratitude acknowledgment",
			input:    "Thanks for the explanation, got it!",
			expected: chat.IntentConversation,
		},
		{
			name:     "Mere sharing of a learning without capture command",
			input:    "I learned that LSM trees optimize write throughput.",
			expected: chat.IntentConversation,
		},
		{
			name:     "Casual closing",
			input:    "See you tomorrow, good night!",
			expected: chat.IntentConversation,
		},

		// 2. Knowledge Queries (Direct vault lookups)
		{
			name:     "Direct question about vault notes",
			input:    "What does my vault say about database indexes?",
			expected: chat.IntentKnowledgeQuery,
		},
		{
			name:     "Indirect reflection wondering about notes",
			input:    "I wonder what I wrote about database indexes",
			expected: chat.IntentKnowledgeQuery,
		},
		{
			name:     "Current projects and goals query",
			input:    "What are my current projects and learning goals?",
			expected: chat.IntentKnowledgeQuery,
		},
		{
			name:     "Decisions query",
			input:    "What decisions have I made about Edith?",
			expected: chat.IntentKnowledgeQuery,
		},
		{
			name:     "General factual question with question mark",
			input:    "What is the orbital velocity of Jupiter?",
			expected: chat.IntentKnowledgeQuery,
		},
		{
			name:     "Ambiguous phrase defaulting to knowledge query",
			input:    "Raft leader election",
			expected: chat.IntentKnowledgeQuery,
		},
		{
			name:     "Direct question without question mark",
			input:    "Tell me about Raft consensus algorithm",
			expected: chat.IntentKnowledgeQuery,
		},

		// 3. Complex Queries (Comparisons, multi-source synthesis, reports)
		{
			name:     "Comparison between concepts in notes",
			input:    "Compare the storage engines discussed in my notes",
			expected: chat.IntentComplexQuery,
		},
		{
			name:     "Tradeoffs comparison",
			input:    "What are the tradeoffs between WAL mode and rollback journal?",
			expected: chat.IntentComplexQuery,
		},
		{
			name:     "Multi-source synthesis request",
			input:    "Synthesize my technical roadmaps across backend and AI",
			expected: chat.IntentComplexQuery,
		},
		{
			name:     "Explicit detailed report request",
			input:    "Give me a detailed report on my distributed consensus notes",
			expected: chat.IntentComplexQuery,
		},
		{
			name:     "Contradictions synthesis",
			input:    "What contradictions exist across my notes on caching?",
			expected: chat.IntentComplexQuery,
		},

		// 4. Capture Requests (Explicit commands to save/capture)
		{
			name:     "Explicit capture with prefix",
			input:    "Capture this note: LSM trees optimize write throughput by using append-only immutable memtables.",
			expected: chat.IntentCaptureRequest,
		},
		{
			name:     "Save to vault command",
			input:    "Save this to my vault: ADR-002 We decided to use WAL mode for SQLite.",
			expected: chat.IntentCaptureRequest,
		},
		{
			name:     "Add note command",
			input:    "Add note: Daily reflections on testing and benchmarking.",
			expected: chat.IntentCaptureRequest,
		},
		{
			name:     "Record journal command",
			input:    "Record this journal entry: Finished the FTS5 retrieval integration.",
			expected: chat.IntentCaptureRequest,
		},

		// 5. Action or Work Requests
		{
			name:     "List pending proposals",
			input:    "Show pending proposals",
			expected: chat.IntentActionWorkRequest,
		},
		{
			name:     "Check system status",
			input:    "Check vault status",
			expected: chat.IntentActionWorkRequest,
		},
		{
			name:     "How to approve proposal",
			input:    "How do I approve a proposal?",
			expected: chat.IntentActionWorkRequest,
		},
		{
			name:     "Run vault lint command query",
			input:    "Run vault lint",
			expected: chat.IntentActionWorkRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := chat.ClassifyIntent(tc.input)
			if got != tc.expected {
				t.Errorf("ClassifyIntent(%q) = %v; want %v", tc.input, got, tc.expected)
			}
		})
	}
}

func TestExtractCaptureContent(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{
			input:    "Capture this note: LSM trees optimize write throughput",
			expected: "LSM trees optimize write throughput",
		},
		{
			input:    "Save this to my vault: ADR-002 We decided to use WAL mode",
			expected: "ADR-002 We decided to use WAL mode",
		},
		{
			input:    "capture: Simple note content",
			expected: "Simple note content",
		},
		{
			input:    "Unprefixed plain content without command",
			expected: "Unprefixed plain content without command",
		},
	}

	for _, tc := range tests {
		got := chat.ExtractCaptureContent(tc.input)
		if got != tc.expected {
			t.Errorf("ExtractCaptureContent(%q) = %q; want %q", tc.input, got, tc.expected)
		}
	}
}
