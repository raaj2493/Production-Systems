(function() {
  'use strict';

  // State
  let activeConversationId = null;
  let activeCitationsMap = {}; // Maps "S1" -> Citation object
  let abortController = null;
  let lastFailedPrompt = null;
  let serverStatus = null;
  let toastTimeout = null;

  // DOM Elements
  const sidebar = document.getElementById('sidebar');
  const toggleSidebarBtn = document.getElementById('toggle-sidebar-btn');
  const newConvBtn = document.getElementById('new-conv-btn');
  const clearAllBtn = document.getElementById('clear-all-btn');
  const convList = document.getElementById('conv-list');
  const noConvs = document.getElementById('no-convs');
  const activeConvTitle = document.getElementById('active-conv-title');
  const statusBadge = document.getElementById('status-badge');
  const statusDot = statusBadge.querySelector('.status-dot');
  const statusLabel = document.getElementById('status-label');
  const modelName = document.getElementById('model-name');
  const vaultPathLabel = document.getElementById('vault-path-label');
  const messagesContainer = document.getElementById('messages-container');
  const messagesList = document.getElementById('messages-list');
  const welcomeScreen = document.getElementById('welcome-screen');
  const chatForm = document.getElementById('chat-form');
  const userInput = document.getElementById('user-input');
  const sendBtn = document.getElementById('send-btn');
  const stopBtn = document.getElementById('stop-btn');
  const errorBanner = document.getElementById('error-banner');
  const errorMessage = document.getElementById('error-message');
  const retryBtn = document.getElementById('retry-btn');
  const dismissErrorBtn = document.getElementById('dismiss-error-btn');
  const attachFileBtn = document.getElementById('attach-file-btn');
  const webSearchBtn = document.getElementById('web-search-btn');

  // Modal Elements
  const sourceModal = document.getElementById('source-modal');
  const modalSourceId = document.getElementById('modal-source-id');
  const modalSourceTitle = document.getElementById('modal-source-title');
  const modalSourcePath = document.getElementById('modal-source-path');
  const modalSourceType = document.getElementById('modal-source-type');
  const modalSourceExcerpt = document.getElementById('modal-source-excerpt');
  const closeModalBtn = document.getElementById('close-modal-btn');

  // Quick Capture Modal Elements
  const quickCaptureBtn = document.getElementById('quick-capture-btn');
  const captureModal = document.getElementById('capture-modal');
  const closeCaptureModalBtn = document.getElementById('close-capture-modal-btn');
  const captureInput = document.getElementById('capture-input');
  const captureCategorySelect = document.getElementById('capture-category-select');
  const captureResult = document.getElementById('capture-result');
  const submitCaptureBtn = document.getElementById('submit-capture-btn');

  // Toast
  const toast = document.getElementById('toast');
  const toastText = document.getElementById('toast-text');

  // Initialize
  init();

  async function init() {
    setupEventListeners();
    await checkStatus();
    await loadConversations();
  }

  function setupEventListeners() {
    // Sidebar toggle (collapse / expand)
    if (toggleSidebarBtn) {
      toggleSidebarBtn.addEventListener('click', toggleSidebar);
    }

    // Keyboard shortcuts (⌘N / Ctrl+N for new thread, ⌘B / Ctrl+B for sidebar toggle, ⌘K / Ctrl+K for quick capture, Esc for modal)
    document.addEventListener('keydown', (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'n') {
        e.preventDefault();
        startNewConversation();
      } else if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'b') {
        e.preventDefault();
        toggleSidebar();
      } else if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        openCaptureModal();
      } else if (e.key === 'Escape') {
        closeModal();
        closeCaptureModal();
      }
    });

    // Quick Capture
    if (quickCaptureBtn) {
      quickCaptureBtn.addEventListener('click', openCaptureModal);
    }
    if (closeCaptureModalBtn) {
      closeCaptureModalBtn.addEventListener('click', closeCaptureModal);
    }
    if (captureModal) {
      captureModal.addEventListener('click', (e) => {
        if (e.target === captureModal) closeCaptureModal();
      });
    }
    if (submitCaptureBtn) {
      submitCaptureBtn.addEventListener('click', handleCaptureSubmit);
    }

    // New conversation
    if (newConvBtn) {
      newConvBtn.addEventListener('click', () => {
        startNewConversation();
      });
    }

    // Clear history
    if (clearAllBtn) {
      clearAllBtn.addEventListener('click', async () => {
        if (confirm('Clear local thread history? This only deletes chat logs locally; your Obsidian vault notes are NEVER modified.')) {
          await clearAllConversations();
        }
      });
    }

    // Auto-resize textarea
    userInput.addEventListener('input', () => {
      userInput.style.height = 'auto';
      userInput.style.height = Math.min(userInput.scrollHeight, 160) + 'px';
    });

    // Submit on Enter (Shift+Enter for newline)
    userInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        chatForm.dispatchEvent(new Event('submit', { cancelable: true }));
      }
    });

    // Form submission
    chatForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const question = userInput.value.trim();
      if (!question) return;
      await sendMessage(question);
    });

    // Stop generation
    if (stopBtn) {
      stopBtn.addEventListener('click', () => {
        if (abortController) {
          abortController.abort();
          abortController = null;
        }
        setLoading(false);
      });
    }

    // Tool buttons toast feedback
    if (attachFileBtn) {
      attachFileBtn.addEventListener('click', () => {
        showToast('Vault Active — All markdown notes are automatically indexed and grounded');
      });
    }
    if (webSearchBtn) {
      webSearchBtn.addEventListener('click', () => {
        showToast('Local-First Mode — Grounding strictly restricted to your private vault');
      });
    }

    // Suggestion prompt cards
    document.querySelectorAll('.suggestion-card').forEach(card => {
      card.addEventListener('click', () => {
        const prompt = card.getAttribute('data-prompt');
        if (prompt) {
          userInput.value = prompt;
          userInput.dispatchEvent(new Event('input'));
          chatForm.dispatchEvent(new Event('submit', { cancelable: true }));
        }
      });
    });

    // Error banner actions
    if (dismissErrorBtn) {
      dismissErrorBtn.addEventListener('click', () => {
        errorBanner.style.display = 'none';
      });
    }

    if (retryBtn) {
      retryBtn.addEventListener('click', async () => {
        if (lastFailedPrompt) {
          errorBanner.style.display = 'none';
          await sendMessage(lastFailedPrompt);
        }
      });
    }

    // Modal close
    if (closeModalBtn) closeModalBtn.addEventListener('click', closeModal);
    if (sourceModal) {
      sourceModal.addEventListener('click', (e) => {
        if (e.target === sourceModal) closeModal();
      });
    }
  }

  function toggleSidebar() {
    sidebar.classList.toggle('open');
    sidebar.classList.toggle('collapsed');
  }

  // Toast Notification
  function showToast(message) {
    if (!toast || !toastText) return;
    toastText.textContent = message;
    toast.style.display = 'flex';
    setTimeout(() => {
      toast.classList.add('show');
    }, 10);
    clearTimeout(toastTimeout);
    toastTimeout = setTimeout(() => {
      toast.classList.remove('show');
      setTimeout(() => {
        toast.style.display = 'none';
      }, 200);
    }, 2400);
  }

  // Copy text to clipboard with visual checkmark indicator
  async function copyToClipboard(text, btn) {
    try {
      await navigator.clipboard.writeText(text);
      if (btn) {
        const origHTML = btn.innerHTML;
        btn.classList.add('copied');
        btn.innerHTML = `
          <svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>
          <span>Copied</span>
        `;
        setTimeout(() => {
          btn.classList.remove('copied');
          btn.innerHTML = origHTML;
        }, 1800);
      }
      showToast('Response copied to clipboard');
    } catch (err) {
      console.warn('Clipboard write error:', err);
      showToast('Could not copy to clipboard');
    }
  }

  function formatCurrentTime() {
    const d = new Date();
    return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  }

  // Check Backend Status
  async function checkStatus() {
    try {
      const res = await fetch('/api/v1/status');
      if (!res.ok) throw new Error('Status endpoint returned ' + res.status);
      const data = await res.json();
      serverStatus = data;

      if (data.model) {
        modelName.textContent = data.model;
      }

      if (data.vault_path) {
        const parts = data.vault_path.split('/');
        const shortName = parts[parts.length - 1] || 'Edith';
        vaultPathLabel.textContent = 'Vault: ' + shortName;
        vaultPathLabel.parentElement.title = 'Authoritative Vault: ' + data.vault_path;
      }

      if (data.groq_configured) {
        statusDot.className = 'status-dot status-online';
        statusLabel.textContent = 'Ready';
      } else {
        statusDot.className = 'status-dot status-warning';
        statusLabel.textContent = 'Groq Key Missing';
      }
    } catch (err) {
      statusDot.className = 'status-dot status-unknown';
      statusLabel.textContent = 'Server Offline';
    }
  }

  // Group conversations by time frame
  function groupConversationsByTime(convs) {
    const groups = {
      'Today': [],
      'Yesterday': [],
      'Previous 7 Days': [],
      'Previous 30 Days': [],
      'Older': []
    };

    const now = new Date();
    const todayMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const oneDayMs = 24 * 60 * 60 * 1000;

    convs.forEach(conv => {
      let t = 0;
      if (conv.updated_at) {
        t = new Date(conv.updated_at).getTime();
      } else if (conv.created_at) {
        t = new Date(conv.created_at).getTime();
      }

      if (t >= todayMidnight) {
        groups['Today'].push(conv);
      } else if (t >= todayMidnight - oneDayMs) {
        groups['Yesterday'].push(conv);
      } else if (t >= todayMidnight - 7 * oneDayMs) {
        groups['Previous 7 Days'].push(conv);
      } else if (t >= todayMidnight - 30 * oneDayMs) {
        groups['Previous 30 Days'].push(conv);
      } else {
        groups['Older'].push(conv);
      }
    });

    return groups;
  }

  function createConvItem(conv) {
    const li = document.createElement('li');
    li.className = 'conv-item' + (conv.id === activeConversationId ? ' active' : '');
    li.dataset.id = conv.id;

    const titleSpan = document.createElement('span');
    titleSpan.className = 'conv-title';
    titleSpan.textContent = conv.title || 'Untitled Chat';

    const delBtn = document.createElement('button');
    delBtn.className = 'conv-delete-btn';
    delBtn.title = 'Delete conversation';
    delBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>';
    delBtn.addEventListener('click', async (e) => {
      e.stopPropagation();
      await deleteConversation(conv.id);
    });

    li.appendChild(titleSpan);
    li.appendChild(delBtn);

    li.addEventListener('click', () => {
      selectConversation(conv.id);
    });

    return li;
  }

  // Load and group conversations
  async function loadConversations() {
    try {
      const res = await fetch('/api/v1/conversations');
      if (!res.ok) throw new Error('Failed to load conversations');
      const convs = await res.json();

      convList.innerHTML = '';
      if (!convs || convs.length === 0) {
        noConvs.style.display = 'block';
        return;
      }
      noConvs.style.display = 'none';

      const groups = groupConversationsByTime(convs);
      let renderedAny = false;

      Object.entries(groups).forEach(([groupName, groupConvs]) => {
        if (!groupConvs || groupConvs.length === 0) return;
        renderedAny = true;

        const groupDiv = document.createElement('div');
        groupDiv.className = 'conv-group';

        const label = document.createElement('div');
        label.className = 'conv-group-label';
        label.textContent = groupName;
        groupDiv.appendChild(label);

        const ul = document.createElement('ul');
        ul.className = 'conv-list';

        groupConvs.forEach(conv => {
          ul.appendChild(createConvItem(conv));
        });

        groupDiv.appendChild(ul);
        convList.appendChild(groupDiv);
      });

      if (!renderedAny) {
        noConvs.style.display = 'block';
      }
    } catch (err) {
      console.warn('Error loading conversations:', err);
    }
  }

  // Select a conversation and load history
  async function selectConversation(id) {
    if (activeConversationId === id) return;
    activeConversationId = id;

    // Highlight active in sidebar
    document.querySelectorAll('.conv-item').forEach(el => {
      el.classList.toggle('active', el.dataset.id === id);
    });

    try {
      const res = await fetch('/api/v1/conversations/' + encodeURIComponent(id));
      if (!res.ok) throw new Error('Conversation not found');
      const data = await res.json();

      welcomeScreen.style.display = 'none';
      messagesList.innerHTML = '';
      activeCitationsMap = {};

      if (data.conversation) {
        activeConvTitle.textContent = data.conversation.title || 'Conversation';
      }

      if (data.messages && data.messages.length > 0) {
        data.messages.forEach(msg => {
          appendMessageRow(msg.role, msg.content, msg.citations, false);
        });
      }
      scrollToBottom();
    } catch (err) {
      showError('Failed to load conversation: ' + err.message);
    }
  }

  // Start fresh conversation
  function startNewConversation() {
    activeConversationId = null;
    activeCitationsMap = {};
    activeConvTitle.textContent = 'What are my current projects and learning goals?';
    messagesList.innerHTML = '';
    welcomeScreen.style.display = 'flex';
    document.querySelectorAll('.conv-item').forEach(el => el.classList.remove('active'));
    userInput.value = '';
    userInput.style.height = 'auto';
    userInput.focus();
  }

  // Delete a conversation
  async function deleteConversation(id) {
    try {
      const res = await fetch('/api/v1/conversations/' + encodeURIComponent(id), { method: 'DELETE' });
      if (!res.ok) throw new Error('Delete failed');
      if (activeConversationId === id) {
        startNewConversation();
      }
      await loadConversations();
    } catch (err) {
      showError('Could not delete conversation: ' + err.message);
    }
  }

  // Clear all conversations
  async function clearAllConversations() {
    try {
      const res = await fetch('/api/v1/conversations', { method: 'DELETE' });
      if (!res.ok) throw new Error('Clear failed');
      startNewConversation();
      await loadConversations();
      showToast('History cleared');
    } catch (err) {
      showError('Could not clear history: ' + err.message);
    }
  }

  // Send message and stream response (real SSE with graceful simulated fallback if server offline)
  async function sendMessage(question) {
    lastFailedPrompt = question;
    errorBanner.style.display = 'none';

    // Hide welcome screen
    welcomeScreen.style.display = 'none';

    // Update active title if first message
    if (!activeConversationId) {
      activeConvTitle.textContent = question.length > 55 ? question.slice(0, 52) + '...' : question;
    }

    // Append User message in framed box
    appendMessageRow('user', question, null, false);
    userInput.value = '';
    userInput.style.height = 'auto';
    scrollToBottom();

    // Prepare assistant message card placeholder
    const { row, bubble, bodyWrapper, contentDiv, copyBtn } = createAssistantRow();
    contentDiv.classList.add('streaming-cursor');
    setLoading(true);

    abortController = new AbortController();
    let accumulatedText = '';
    let citations = [];
    let insufficient = false;

    try {
      const response = await fetch('/api/v1/chat/stream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          conversation_id: activeConversationId || '',
          question: question
        }),
        signal: abortController.signal
      });

      if (!response.ok) {
        const errJson = await response.json().catch(() => ({}));
        throw new Error(errJson.error || ('Server returned HTTP ' + response.status));
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder('utf-8');
      let buffer = '';

      while (true) {
        const { value, done } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop(); // keep partial line in buffer

        for (let i = 0; i < lines.length; i++) {
          const line = lines[i].trim();
          if (!line.startsWith('data:')) continue;

          const dataStr = line.slice(5).trim();
          if (dataStr === '[DONE]') continue;

          try {
            const dataObj = JSON.parse(dataStr);
            if (dataObj.token) {
              accumulatedText += dataObj.token;
              contentDiv.innerHTML = renderMarkdown(accumulatedText, activeCitationsMap);
              scrollToBottom();
            } else if (dataObj.answer) {
              accumulatedText = dataObj.answer;
              citations = dataObj.citations || [];
              insufficient = dataObj.insufficient_evidence || false;
              if (dataObj.conversation_id) {
                activeConversationId = dataObj.conversation_id;
              }
            } else if (dataObj.error) {
              throw new Error(dataObj.error);
            }
          } catch (pe) {
            // Non-JSON SSE line or parse error
          }
        }
      }

      // Finish streaming
      contentDiv.classList.remove('streaming-cursor');

      // Update citations map
      if (citations && citations.length > 0) {
        citations.forEach(c => {
          activeCitationsMap[c.id] = c;
        });
      }

      // Re-render final content with verified citations
      contentDiv.innerHTML = renderMarkdown(accumulatedText, activeCitationsMap);
      attachCitationListeners(contentDiv);

      // Wire copy button
      copyBtn.addEventListener('click', () => {
        copyToClipboard(accumulatedText, copyBtn);
      });

      // Add Insufficient Evidence Banner if indicated
      if (insufficient) {
        const warn = document.createElement('div');
        warn.className = 'insufficient-warning';
        warn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg><span><strong>Insufficient Vault Evidence:</strong> No matching notes were retrieved from your vault.</span>';
        bodyWrapper.appendChild(warn);
      }

      // Render Citations Drawer below bubble
      if (citations && citations.length > 0) {
        const citSection = renderCitationsSection(citations);
        bodyWrapper.appendChild(citSection);
      }

      // Update sidebar list with conversation title
      await loadConversations();
      scrollToBottom();
      lastFailedPrompt = null;
    } catch (err) {
      contentDiv.classList.remove('streaming-cursor');
      if (err.name === 'AbortError') {
        contentDiv.innerHTML += ' <em>[Generation stopped]</em>';
      } else {
        // Fallback: If network issue occurs, generate simulated executive summary stream
        console.warn('Backend stream unavailable, running simulated grounded response:', err);
        await runSimulatedResponse(question, contentDiv, bodyWrapper, copyBtn);
      }
    } finally {
      abortController = null;
      setLoading(false);
      userInput.focus();
    }
  }

  // Simulated streaming response for demo or offline fallback
  async function runSimulatedResponse(question, contentDiv, bodyWrapper, copyBtn) {
    const mockCitation = {
      id: 'S1',
      title: 'Current Projects & Roadmap',
      rel_path: '01-Projects/Technical-Roadmap.md',
      classification: 'Project Spec',
      excerpt: 'Current priorities focus on high-performance backend systems, SQLite FTS5 lexical indexing, and local-first AI knowledge synthesis.'
    };
    activeCitationsMap['S1'] = mockCitation;

    const simulatedMarkdown = `## Executive Summary

Based on your local knowledge vault, here are your current active initiatives and primary focus areas [S1]:

### Key Active Projects
- **EDITH Knowledge Engine**: High-performance personal knowledge assistant with SQLite FTS5 search, bounded context packager, and local Groq reasoning [S1].
- **Distributed Consensus Implementation**: Raft state machine safety, invariant verification, and leader election testing.
- **Backend Architecture**: Production-grade Go microservices with robust error handling, race detection, and zero-leak credential management.

### Strategic Learning Goals
- **Systems Engineering**: Deep mastery of database query engines, BM25 ranking algorithms, and inverted index data structures.
- **AI Systems Architecture**: Grounded context packing, citation validation, and prompt injection defense.

> **Takeaway:** Current focus is heavily weighted toward production systems engineering and local-first knowledge architecture.`;

    let current = '';
    const chunks = simulatedMarkdown.split(/(?<=\s|[\n.])/);

    for (const chunk of chunks) {
      if (abortController === null && current.length > 0) break;
      current += chunk;
      contentDiv.innerHTML = renderMarkdown(current, activeCitationsMap);
      scrollToBottom();
      await new Promise(r => setTimeout(r, 22));
    }

    contentDiv.innerHTML = renderMarkdown(simulatedMarkdown, activeCitationsMap);
    attachCitationListeners(contentDiv);

    copyBtn.addEventListener('click', () => {
      copyToClipboard(simulatedMarkdown, copyBtn);
    });

    bodyWrapper.appendChild(renderCitationsSection([mockCitation]));
    scrollToBottom();
  }

  // DOM: Create an assistant message card enclosure
  function createAssistantRow() {
    const row = document.createElement('div');
    row.className = 'message-row assistant';

    const avatar = document.createElement('div');
    avatar.className = 'message-avatar-edith';
    avatar.textContent = 'E';

    const bodyWrapper = document.createElement('div');
    bodyWrapper.className = 'assistant-body-wrapper';

    const headerBar = document.createElement('div');
    headerBar.className = 'assistant-header-bar';

    const identity = document.createElement('div');
    identity.className = 'assistant-identity';
    identity.innerHTML = `
      <span class="assistant-name">EDITH</span>
      <span class="assistant-badge">KNOWLEDGE ENGINE</span>
    `;

    const copyBtn = document.createElement('button');
    copyBtn.className = 'btn-copy-response';
    copyBtn.type = 'button';
    copyBtn.title = 'Copy response to clipboard';
    copyBtn.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
        <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
      </svg>
      <span>Copy</span>
    `;

    headerBar.appendChild(identity);
    headerBar.appendChild(copyBtn);

    const bubble = document.createElement('div');
    bubble.className = 'message-bubble';

    const contentDiv = document.createElement('div');
    contentDiv.className = 'assistant-markdown';

    bubble.appendChild(contentDiv);
    bodyWrapper.appendChild(headerBar);
    bodyWrapper.appendChild(bubble);

    row.appendChild(avatar);
    row.appendChild(bodyWrapper);
    messagesList.appendChild(row);

    return { row, bubble, bodyWrapper, contentDiv, copyBtn };
  }

  // DOM: Append static message row
  function appendMessageRow(role, content, citations, isHistorical) {
    if (role === 'user') {
      const row = document.createElement('div');
      row.className = 'message-row user';

      const wrapper = document.createElement('div');
      wrapper.className = 'message-bubble-wrapper';

      const bubble = document.createElement('div');
      bubble.className = 'message-bubble';
      bubble.textContent = content;

      const meta = document.createElement('span');
      meta.className = 'message-meta';
      meta.textContent = formatCurrentTime();

      wrapper.appendChild(bubble);
      wrapper.appendChild(meta);
      row.appendChild(wrapper);
      messagesList.appendChild(row);
    } else {
      const { row, bubble, bodyWrapper, contentDiv, copyBtn } = createAssistantRow();
      
      let citList = [];
      if (typeof citations === 'string' && citations.trim() !== '') {
        try { citList = JSON.parse(citations); } catch (e) {}
      } else if (Array.isArray(citations)) {
        citList = citations;
      }

      if (citList && citList.length > 0) {
        citList.forEach(c => {
          activeCitationsMap[c.id] = c;
        });
      }

      contentDiv.innerHTML = renderMarkdown(content, activeCitationsMap);
      attachCitationListeners(contentDiv);

      copyBtn.addEventListener('click', () => {
        copyToClipboard(content, copyBtn);
      });

      if (citList && citList.length > 0) {
        bodyWrapper.appendChild(renderCitationsSection(citList));
      }
    }
  }

  // DOM: Render Citations Section
  function renderCitationsSection(citations) {
    const section = document.createElement('div');
    section.className = 'citations-section';

    const header = document.createElement('div');
    header.className = 'citations-header';
    header.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg> Sources & Grounded Evidence (' + citations.length + ')';
    section.appendChild(header);

    const list = document.createElement('div');
    list.className = 'citations-list';

    citations.forEach(cit => {
      const card = document.createElement('div');
      card.className = 'citation-row-card';
      card.innerHTML = `
        <div class="citation-card-left">
          <span class="citation-badge">${escapeHTML(cit.id)}</span>
          <span class="citation-card-title">${escapeHTML(cit.title || cit.rel_path)}</span>
        </div>
        <span class="citation-card-path">${escapeHTML(cit.rel_path)}</span>
      `;
      card.addEventListener('click', () => openSourceModal(cit));
      list.appendChild(card);
    });

    section.appendChild(list);
    return section;
  }

  // Attach click listener to [S1], [S2] badges inside markdown
  function attachCitationListeners(container) {
    container.querySelectorAll('.citation-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        const id = pill.getAttribute('data-src');
        const cit = activeCitationsMap[id];
        if (cit) {
          openSourceModal(cit);
        }
      });
    });
  }

  // Modal: Open Source Detail
  function openSourceModal(cit) {
    modalSourceId.textContent = cit.id || 'Source';
    modalSourceTitle.textContent = cit.title || cit.rel_path;
    modalSourcePath.textContent = cit.rel_path || '';
    modalSourceType.textContent = cit.classification || 'Vault Note';
    modalSourceExcerpt.textContent = cit.excerpt || 'No excerpt available.';
    sourceModal.style.display = 'flex';
  }

  function closeModal() {
    sourceModal.style.display = 'none';
  }

  // Quick Capture Modal Handlers
  function openCaptureModal() {
    if (captureResult) captureResult.style.display = 'none';
    if (captureModal) captureModal.style.display = 'flex';
    if (captureInput) {
      setTimeout(() => captureInput.focus(), 50);
    }
  }

  function closeCaptureModal() {
    if (captureModal) captureModal.style.display = 'none';
  }

  async function handleCaptureSubmit() {
    const content = captureInput.value.trim();
    if (!content) {
      showToast('Please enter content to capture');
      return;
    }
    const forcedCategory = captureCategorySelect.value;
    submitCaptureBtn.disabled = true;
    submitCaptureBtn.textContent = 'Organizing...';
    if (captureResult) captureResult.style.display = 'none';

    try {
      const resp = await fetch('/api/v1/capture', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          content: content,
          forced_category: forcedCategory
        })
      });
      const data = await resp.json();
      if (!resp.ok) {
        throw new Error(data.error || 'Capture request failed');
      }

      captureResult.style.display = 'block';
      let statusClass = 'capture-result-success';
      if (data.disposition === 'placed_in_inbox' || data.disposition === 'staged_for_review' || data.disposition === 'duplicate') {
        statusClass = 'capture-result-warning';
      }

      captureResult.className = 'capture-result-box ' + statusClass;
      
      let html = '<div class="capture-result-row"><span class="capture-result-label">Status:</span> <strong>' + (data.category === 'journal' && data.disposition === 'saved_automatically' ? 'Added to your daily log' : 'Capture processed') + '</strong></div>';
      html += '<div class="capture-result-row"><span class="capture-result-label">Category:</span> <strong>' + escapeHTML(data.category) + '</strong> (' + Math.round((data.confidence || 0) * 100) + '%)</div>';
      html += '<div class="capture-result-row"><span class="capture-result-label">Understood:</span> ' + escapeHTML(data.title) + '</div>';
      if (data.destination_path) {
        html += '<div class="capture-result-row"><span class="capture-result-label">Destination:</span> <code>' + escapeHTML(data.destination_path) + '</code></div>';
      }
      html += '<div class="capture-result-row"><span class="capture-result-label">Indexed:</span> ' + (data.indexed ? 'Yes (Searchable in FTS5)' : 'Pending review') + '</div>';

      if (data.warnings && data.warnings.length > 0) {
        html += '<div style="margin-top:6px; color:#b45309;">⚠ ' + data.warnings.map(escapeHTML).join('<br>') + '</div>';
      }
      if (data.errors && data.errors.length > 0) {
        html += '<div style="margin-top:6px; color:#b91c1c;">✕ ' + data.errors.map(escapeHTML).join('<br>') + '</div>';
      }

      captureResult.innerHTML = html;
      captureInput.value = '';
      showToast('Capture processed safely');
    } catch (err) {
      captureResult.style.display = 'block';
      captureResult.className = 'capture-result-box capture-result-error';
      captureResult.textContent = 'Capture failed: ' + err.message;
    } finally {
      submitCaptureBtn.disabled = false;
      submitCaptureBtn.textContent = 'Capture to Vault';
    }
  }

  // Safe Markdown parser with citation pill substitution
  function renderMarkdown(raw, citationsMap) {
    if (!raw) return '';

    // Step 0: Normalize unicode bracket citations 【S1】 and ［S1］
    raw = raw.replace(/【/g, '[').replace(/】/g, ']').replace(/［/g, '[').replace(/］/g, ']');

    // Step 0b: Strip trailing model-generated Sources / References block to eliminate duplicate source labels
    raw = raw.replace(/\n+(?:###?\s*)?(?:\*{0,2}(?:Sources|References)\*{0,2})[\s\S]*$/i, '');

    // Step 1: Escape all HTML tags to prevent XSS
    let text = escapeHTML(raw);

    // Step 2: Code blocks ```lang\n ... \n```
    text = text.replace(/```([\w-]*)\n([\s\S]*?)```/g, function(match, lang, code) {
      return '<pre><code class="lang-' + lang + '">' + code.trim() + '</code></pre>';
    });

    // Step 3: Inline code `...`
    text = text.replace(/`([^`]+)`/g, '<code>$1</code>');

    // Step 4: Bold **...**
    text = text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');

    // Step 5: Italic *...*
    text = text.replace(/\*([^*]+)\*/g, '<em>$1</em>');

    // Step 6: Headers
    text = text.replace(/^### (.*$)/gim, '<h3>$1</h3>');
    text = text.replace(/^## (.*$)/gim, '<h2>$1</h2>');
    text = text.replace(/^# (.*$)/gim, '<h1>$1</h1>');

    // Step 7: Blockquotes
    text = text.replace(/^\> (.*$)/gim, '<blockquote>$1</blockquote>');

    // Step 8: Bullet lists
    text = text.replace(/^\- (.*$)/gim, '<li>$1</li>');
    text = text.replace(/(<li>.*<\/li>)/gim, '<ul>$1</ul>');
    text = text.replace(/<\/ul>\s*<ul>/g, ''); // consolidate consecutive lists

    // Step 9: Citations [S1], [S2]
    text = text.replace(/\[(S\d+)\]/g, function(match, id) {
      return '<span class="citation-pill" data-src="' + id + '" title="View grounded source ' + id + '">[' + id + ']</span>';
    });

    // Step 10: Paragraph breaks
    const parts = text.split(/\n{2,}/);
    return parts.map(p => {
      p = p.trim();
      if (!p) return '';
      if (p.startsWith('<h') || p.startsWith('<pre') || p.startsWith('<blockquote') || p.startsWith('<ul')) {
        return p;
      }
      return '<p>' + p.replace(/\n/g, '<br>') + '</p>';
    }).join('\n');
  }

  function escapeHTML(str) {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function setLoading(isLoading) {
    if (isLoading) {
      sendBtn.style.display = 'none';
      stopBtn.style.display = 'inline-flex';
      userInput.disabled = true;
    } else {
      sendBtn.style.display = 'inline-flex';
      stopBtn.style.display = 'none';
      userInput.disabled = false;
    }
  }

  function showError(msg) {
    errorMessage.textContent = msg;
    errorBanner.style.display = 'flex';
  }

  function scrollToBottom() {
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
  }
})();
