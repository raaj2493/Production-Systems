package chat

import (
	"regexp"
	"strings"
)

// Intent represents the classified conversational intent of a user message.
type Intent string

const (
	// IntentConversation encompasses greetings, acknowledgments, casual remarks,
	// and unframed personal updates that should not trigger vault retrieval.
	IntentConversation Intent = "conversation"

	// IntentKnowledgeQuery represents direct questions seeking information from the vault.
	IntentKnowledgeQuery Intent = "knowledge_query"

	// IntentComplexQuery represents questions requiring multiple sources, cross-note
	// comparisons, reasoning across topics, or a detailed synthesis/report.
	IntentComplexQuery Intent = "complex_query"

	// IntentCaptureRequest represents explicit requests to save, capture, or record knowledge.
	IntentCaptureRequest Intent = "capture_request"

	// IntentActionWorkRequest represents requests to execute supported system operations
	// (e.g. proposals, status, lint) or guide the user through a task.
	IntentActionWorkRequest Intent = "action_or_work_request"
)

// ClassifyIntent analyzes a message using conservative deterministic heuristics.
// Ambiguous messages that might be seeking knowledge default to IntentKnowledgeQuery
// so that necessary vault retrieval is never blindly skipped.
func ClassifyIntent(msg string) Intent {
	trimmed := strings.TrimSpace(msg)
	if trimmed == "" {
		return IntentConversation
	}
	lower := strings.ToLower(trimmed)

	// 1. Explicit Capture Requests
	if isCaptureRequest(lower) {
		return IntentCaptureRequest
	}
	// A clearly framed daily reflection is an implicit save request. Casual
	// mentions of learning remain conversation; the user must signal a daily log.
	if isDailyReflection(lower) {
		return IntentCaptureRequest
	}

	// 2. Action or Work Requests (Proposals, status, system operations)
	if isActionWorkRequest(lower) {
		return IntentActionWorkRequest
	}

	// 3. Complex Queries (Comparisons, multi-source synthesis, explicit reports)
	if isComplexQuery(lower) {
		return IntentComplexQuery
	}

	// 4. Explicit Knowledge Queries (Phrases referencing vault, notes, or knowledge lookups)
	if isExplicitKnowledgeQuery(lower) {
		return IntentKnowledgeQuery
	}

	// 5. Casual Conversation & Personal Updates
	if isCasualConversationOrUpdate(lower) {
		return IntentConversation
	}

	// 6. Direct Questions
	// If the message has an interrogative structure and is not conversation,
	// treat as knowledge query.
	if isQuestionStructure(lower) {
		return IntentKnowledgeQuery
	}

	// 7. Ambiguous Queries
	// Conservative fallback: If a message is ambiguous (e.g., "Raft consensus" or "Database indexes"),
	// treat as knowledge query so we do not skip retrieval when the user is searching for knowledge.
	return IntentKnowledgeQuery
}

func isDailyReflection(lower string) bool {
	firstLine := strings.TrimSpace(strings.SplitN(lower, "\n", 2)[0])
	for _, prefix := range []string{
		"today i learned", "today i learnt", "today i did", "today i worked",
		"what i learned today", "what i learnt today", "what i did today",
		"today's learning", "today’s learning", "daily reflection:", "daily log:",
	} {
		if strings.HasPrefix(firstLine, prefix) {
			return true
		}
	}
	return false
}

// isCaptureRequest detects explicit commands to capture or save information into the vault.
func isCaptureRequest(lower string) bool {
	// Guard against past-tense personal updates ("I worked on capture", "I tested this", "I am learning").
	// Only check the FIRST LINE — the command prefix — not the full body, which may legitimately
	// contain words like "learnings", "tested", etc. inside book chapters or notes.
	firstLine := lower
	if nl := strings.IndexByte(lower, '\n'); nl != -1 {
		firstLine = lower[:nl]
	}
	firstLine = strings.TrimSpace(firstLine)
	if strings.HasPrefix(firstLine, "i worked on") || strings.HasPrefix(firstLine, "today i worked on") ||
		strings.HasPrefix(firstLine, "i tested") || strings.HasPrefix(firstLine, "today i tested") ||
		strings.HasPrefix(firstLine, "i am learning") || strings.HasPrefix(firstLine, "i'm learning") {
		return false
	}

	capturePrefixes := []string{
		"capture:", "save:", "record:", "log:", "add note:",
		"capture this", "please capture", "can you capture",
		"save this to my vault", "save to my vault", "save to vault", "save this note",
		"add to my notes", "add this to my notes", "add this to notes", "add to vault",
		"record this journal", "record this log", "log this entry",
		"store this in my vault", "store in vault",
		// Ingest / book capture prefixes
		"ingest this", "ingest the following", "ingest:",
		"please ingest", "can you ingest",
		"add this book", "save this book", "save this chapter",
		"capture this chapter", "capture this book",
		"save this reading", "add this reading",
		// Common typo variants of "ingest"
		"injest this", "injest the following", "injest:",
		"please injest", "can you injest",
		// Colloquial variants
		"add this in ", "ingest in ",
	}

	for _, prefix := range capturePrefixes {
		if strings.HasPrefix(lower, prefix) {
			return true
		}
	}

	reCapture := regexp.MustCompile(`^(?:please\s+)?(?:capture|ingest|injest|save\s+to\s+vault|save\s+this\s+note|save\s+this\s+to\s+my\s+vault)\b`)
	return reCapture.MatchString(lower)
}

// ExtractCaptureContent strips capture command prefixes to isolate the actual content.
func ExtractCaptureContent(msg string) string {
	trimmed := strings.TrimSpace(msg)
	// Keep book-ingest command lines intact: the capture workflow uses them to
	// identify the book and chapter. The book formatter removes these lines
	// from the saved note after extracting that metadata.
	bookCommand := regexp.MustCompile(`(?im)^\s*(?:please\s+)?(?:ingest|injest|capture|save|add)\s+(?:this\s+)?chapter\s+\d+\s*(?:[,;:\-]\s*|\s+(?:from|of)\s+).+\s*$|^\s*(?:please\s+)?(?:ingest|injest|capture|save|add)\s+(?:in|to|into)\s+.+\s*$`)
	if bookCommand.MatchString(trimmed) {
		return trimmed
	}
	patterns := []string{
		`^(?i)capture:\s*`,
		`^(?i)save:\s*`,
		`^(?i)record:\s*`,
		`^(?i)log:\s*`,
		`^(?i)add\s+note:\s*`,
		`^(?i)(?:please\s+)?capture\s+(?:this\s+note|this|the\s+following)?:\s*`,
		`^(?i)(?:please\s+)?capture\s+(?:this\s+note|this|the\s+following)\s+`,
		`^(?i)(?:please\s+)?save\s+this\s+to\s+my\s+vault:\s*`,
		`^(?i)(?:please\s+)?save\s+to\s+vault:\s*`,
		`^(?i)(?:please\s+)?save\s+this\s+note:\s*`,
		`^(?i)(?:please\s+)?add\s+this\s+to\s+my\s+notes:\s*`,
		`^(?i)(?:please\s+)?store\s+this\s+in\s+my\s+vault:\s*`,
		// Ingest / book patterns (including "injest" typo)
		`^(?i)in[jg]est:\s*`,
		`^(?i)(?:please\s+)?in[jg]est\s+(?:this\s+(?:book|chapter|article|reading|note|content|following)|the\s+following)?[:\s]+`,
		`^(?i)(?:please\s+)?in[jg]est\s+(?:this|the)\s+`,
		`^(?i)(?:please\s+)?in[jg]est\s+this[\s:]*`,
	}

	for _, pat := range patterns {
		re := regexp.MustCompile(pat)
		if loc := re.FindStringIndex(trimmed); loc != nil {
			extracted := strings.TrimSpace(trimmed[loc[1]:])
			if extracted != "" {
				return extracted
			}
		}
	}
	return trimmed
}

// isActionWorkRequest detects operational queries about proposals, system status, or task guidance.
func isActionWorkRequest(lower string) bool {
	actionPatterns := []string{
		`^(?:show|list|view|check|get)\s+(?:pending\s+)?proposals\b`,
		`^(?:are\s+there\s+any|any)\s+pending\s+proposals\b`,
		`^(?:how\s+(?:do|can)\s+i\s+)?(?:approve|reject|inspect|review)\s+(?:a\s+)?proposal\b`,
		`^(?:check|show|get)\s+(?:database\s+|vault\s+|system\s+)?status\b`,
		`^(?:run|check)\s+(?:vault\s+)?lint\b`,
		`^(?:show|list|find)\s+(?:broken\s+links|orphans)\b`,
		`^(?:how\s+(?:do|can)\s+i\s+)?(?:reindex|index|search|lint|capture)\b`,
	}

	for _, pat := range actionPatterns {
		re := regexp.MustCompile(pat)
		if re.MatchString(lower) {
			return true
		}
	}
	return false
}

// isComplexQuery detects questions requiring multi-source synthesis, comparisons, or reports.
func isComplexQuery(lower string) bool {
	// Explicit report requests
	if strings.Contains(lower, "detailed report") ||
		strings.Contains(lower, "comprehensive summary") ||
		strings.Contains(lower, "generate a report") ||
		strings.Contains(lower, "write a report") ||
		strings.Contains(lower, "full breakdown") {
		return true
	}

	// Comparisons
	if strings.Contains(lower, "compare") ||
		strings.Contains(lower, "comparison between") ||
		strings.Contains(lower, "tradeoffs between") ||
		strings.Contains(lower, "trade-offs between") ||
		strings.Contains(lower, "differences between") ||
		strings.Contains(lower, "versus") ||
		strings.Contains(lower, " vs ") ||
		strings.Contains(lower, " vs. ") {
		// Must not be a purely personal statement ("I love comparing X and Y")
		if !strings.HasPrefix(lower, "i love") && !strings.HasPrefix(lower, "i like") {
			return true
		}
	}

	// Synthesis across notes
	if strings.Contains(lower, "synthesize") ||
		strings.Contains(lower, "reconcile") ||
		strings.Contains(lower, "contradictions in") ||
		strings.Contains(lower, "disagreements in") ||
		strings.Contains(lower, "across my notes") ||
		strings.Contains(lower, "across notes") {
		return true
	}

	return false
}

// isExplicitKnowledgeQuery detects explicit queries asking what the vault contains.
func isExplicitKnowledgeQuery(lower string) bool {
	phrases := []string{
		"what does my vault say",
		"what do my notes say",
		"what did i write",
		"what did i note",
		"do i have notes on",
		"do my notes mention",
		"in my vault",
		"in my notes",
		"from my notes",
		"from my vault",
		"i wonder what i wrote",
		"curious what my notes say",
		"remind me what i noted",
		"look up in my notes",
		"search my vault",
		"what are my current projects",
		"what are my projects",
		"what are my learning goals",
		"what decisions have i made",
		"what decisions did i make",
		"technical roadmaps",
	}

	for _, p := range phrases {
		if strings.Contains(lower, p) {
			return true
		}
	}
	return false
}

// isCasualConversationOrUpdate detects personal updates, reflections, greetings, and pleasantries.
func isCasualConversationOrUpdate(lower string) bool {
	// 1. Common Greetings
	greetings := []string{
		"hi", "hello", "hey", "good morning", "good afternoon", "good evening",
		"howdy", "yo", "greetings", "hi edith", "hello edith", "hey edith",
		"how are you", "how are you today", "how's it going", "how is it going",
		"how are things", "what's up", "how do you do",
	}
	for _, g := range greetings {
		if lower == g || strings.HasPrefix(lower, g+" ") || strings.HasPrefix(lower, g+",") || strings.HasPrefix(lower, g+"!") {
			// If it's a greeting followed immediately by a question about notes, let question rule handle it
			if !strings.Contains(lower, "what does my vault") && !strings.Contains(lower, "search") {
				return true
			}
		}
	}

	// 2. Acknowledgments & Closures
	acknowledgments := []string{
		"thanks", "thank you", "thx", "appreciate it", "got it", "cool",
		"awesome", "nice", "great", "sounds good", "ok", "okay", "perfect",
		"bye", "goodbye", "see ya", "good night", "gn", "see you tomorrow",
		"see you", "take care",
	}
	for _, ack := range acknowledgments {
		if lower == ack || strings.HasPrefix(lower, ack+" ") || strings.HasPrefix(lower, ack+",") ||
			strings.HasPrefix(lower, ack+"!") || strings.HasPrefix(lower, ack+".") ||
			strings.Contains(lower, "good night") || strings.HasPrefix(lower, "see you") {
			return true
		}
	}

	// 3. Personal progress updates & reflections
	// Examples:
	// "Today I worked on Edith's intelligent capture system..."
	// "I finally understand database indexes!"
	// "I learned why preserving original content matters."
	// "Tomorrow I want to test search freshness..."
	updatePrefixes := []string{
		"today i ", "today was ", "today we ",
		"yesterday i ", "this morning i ", "tonight i ", "this week i ",
		"tomorrow i ", "tomorrow let's ", "tomorrow we ",
		"i finally understand", "i finally figured out", "i finally got",
		"i just realized", "i just finished", "i just deployed", "i just completed",
		"i learned that", "i learned how", "i learned why",
		"i feel like", "i'm feeling", "i am feeling", "feeling good about",
		"i love ", "i enjoy ", "i'm thinking about", "i am thinking about",
		"just finished", "just deployed", "just testing",
	}

	for _, p := range updatePrefixes {
		if strings.HasPrefix(lower, p) {
			// Ensure it doesn't contain an explicit question asking for retrieval
			if !strings.Contains(lower, "what did i write") && !strings.Contains(lower, "can you look up") {
				return true
			}
		}
	}

	// 4. Conversational statements ending with period or exclamation without question marks
	// If it starts with personal reflection "i worked on", "i spent", "i tested"
	if (strings.HasPrefix(lower, "i worked on") || strings.HasPrefix(lower, "i spent") || strings.HasPrefix(lower, "i tested")) &&
		!strings.Contains(lower, "?") {
		return true
	}

	return false
}

// isQuestionStructure checks if message follows typical interrogative question syntax.
func isQuestionStructure(lower string) bool {
	if strings.HasSuffix(lower, "?") {
		return true
	}

	questionStarters := []string{
		"what is ", "what are ", "what was ", "what were ",
		"how does ", "how do ", "how can ", "how is ", "how are ",
		"why does ", "why do ", "why is ", "why are ",
		"when did ", "when was ", "when were ", "when is ",
		"where is ", "where are ", "where did ",
		"which ", "who is ", "who was ",
		"tell me about ", "explain ", "describe ",
	}

	for _, qs := range questionStarters {
		if strings.HasPrefix(lower, qs) {
			return true
		}
	}
	return false
}
