(function () {
  const API_BASE_URL = 'https://api.ghostai.ru';
  const API_VERSION_PREFIX = '/v1';

  function buildApiUrl(path) {
    const normalizedPath = path.startsWith('/') ? path : `/${path}`;
    return new URL(`${API_VERSION_PREFIX}${normalizedPath}`, API_BASE_URL);
  }

  function apiFetch(path, { searchParams, ...options } = {}) {
    const url = buildApiUrl(path);
    if (searchParams) {
      Object.entries(searchParams).forEach(([key, value]) => {
        if (value != null && value !== '') {
          url.searchParams.set(key, value);
        }
      });
    }
    return fetch(url.toString(), {
      credentials: 'include',
      ...options,
    });
  }

  const STATUS_MAP = {
    uploaded: { label: 'Готово', badgeClass: 'status-badge status-badge--success' },
    uploading: { label: 'Загружается', badgeClass: 'status-badge status-badge--warning' },
    failed: { label: 'Ошибка', badgeClass: 'status-badge status-badge--danger' },
  };

  const dateFormatter = new Intl.DateTimeFormat('ru-RU', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  const timeFormatter = new Intl.DateTimeFormat('ru-RU', {
    hour: '2-digit',
    minute: '2-digit',
  });

  const summaryDateFormatter = new Intl.DateTimeFormat('ru-RU', {
    day: '2-digit',
    month: 'long',
    hour: '2-digit',
    minute: '2-digit',
  });

  function formatRecordingTitle(item) {
    if (!item || !item.started_at) {
      return 'Запись';
    }
    return `Запись от ${dateFormatter.format(new Date(item.started_at))}`;
  }

  function formatDuration(seconds) {
    if (!seconds || Number.isNaN(seconds)) {
      return '—';
    }
    const total = Math.max(0, Math.round(seconds));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const secs = total % 60;
    const minutesPart = hours > 0 ? String(minutes).padStart(2, '0') : String(minutes);
    const secondsPart = String(secs).padStart(2, '0');
    return hours > 0 ? `${hours}:${minutesPart}:${secondsPart}` : `${minutes}:${secondsPart}`;
  }

  function formatFileSize(bytes) {
    if (!bytes || Number.isNaN(bytes)) {
      return '—';
    }
    const units = ['Б', 'КБ', 'МБ', 'ГБ'];
    let size = bytes;
    let unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex += 1;
    }
    const formatter = new Intl.NumberFormat('ru-RU', {
      minimumFractionDigits: size < 10 && unitIndex > 0 ? 1 : 0,
      maximumFractionDigits: size < 10 && unitIndex > 0 ? 1 : 0,
    });
    return `${formatter.format(size)} ${units[unitIndex]}`;
  }

  function toFiniteNumber(value) {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
    return undefined;
  }

  function normalizeRecordingItem(item) {
    if (!item || typeof item !== 'object') {
      return null;
    }

    const id = 'id' in item ? String(item.id) : null;
    if (!id) {
      return null;
    }

    const startedAt = item.started_at || item.startedAt || null;
    const endedAt = item.ended_at || item.endedAt || null;

    const durationCandidates = [
      item.duration_s,
      item.durationSeconds,
      item.duration_seconds,
      item.duration,
      item.duration_sec,
      item.durationMs,
      item.duration_ms,
    ];
    let durationSeconds;
    for (const candidate of durationCandidates) {
      if (candidate == null) {
        continue;
      }
      if (candidate === item.durationMs || candidate === item.duration_ms) {
        const millis = toFiniteNumber(candidate);
        if (typeof millis === 'number') {
          durationSeconds = Math.round(millis / 1000);
          break;
        }
        continue;
      }
      const parsed = toFiniteNumber(candidate);
      if (typeof parsed === 'number') {
        durationSeconds = parsed;
        break;
      }
    }

    const sizeCandidates = [item.size_bytes, item.sizeBytes, item.size, item.file_size, item.bytes];
    let sizeBytes;
    for (const candidate of sizeCandidates) {
      const parsed = toFiniteNumber(candidate);
      if (typeof parsed === 'number') {
        sizeBytes = parsed;
        break;
      }
    }

    const status = typeof item.status === 'string' ? item.status : 'uploaded';
    const contentType = item.content_type || item.contentType || undefined;

    return {
      id,
      started_at: startedAt || null,
      ended_at: endedAt || null,
      duration_s: typeof durationSeconds === 'number' ? durationSeconds : undefined,
      size_bytes: typeof sizeBytes === 'number' ? sizeBytes : undefined,
      status,
      content_type: contentType,
    };
  }

  function normalizeCursor(value) {
    if (typeof value === 'string') {
      const trimmed = value.trim();
      return trimmed ? trimmed : null;
    }
    if (value === null || typeof value === 'undefined') {
      return null;
    }
    const stringified = String(value).trim();
    return stringified ? stringified : null;
  }

  function formatTranscriptTime(seconds) {
    const numeric = Number.parseFloat(String(seconds));
    if (!Number.isFinite(numeric) || Number.isNaN(numeric)) {
      return '00:00';
    }
    const total = Math.max(0, numeric);
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const secs = total % 60;
    const minutesPart = hours > 0 ? String(minutes).padStart(2, '0') : String(minutes);
    const secondsPart = String(secs).padStart(2, '0');
    return hours > 0
      ? `${hours}:${minutesPart}:${secondsPart}`
      : `${minutesPart}:${secondsPart}`;
  }

  function createStatusBadge(item) {
    const config = STATUS_MAP[item.status] || STATUS_MAP.uploaded;
    const span = document.createElement('span');
    span.className = `${config.badgeClass} recording-card__status`;
    span.innerHTML = `<span class="status-dot" aria-hidden="true"></span><span>${config.label}</span>`;
    span.setAttribute('aria-label', `Статус: ${config.label}`);
    return span;
  }

  function createChevron() {
    const wrapper = document.createElement('div');
    wrapper.className = 'recording-card__chevron';
    wrapper.innerHTML = `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <path d="m9 6 6 6-6 6" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"></path>
      </svg>
    `;
    return wrapper;
  }

  function createAvatar() {
    const avatar = document.createElement('div');
    avatar.className = 'recording-card__avatar';
    avatar.innerHTML = `
      <svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <path
          d="M9 16c6 0 6 16 12 16s6-16 12-16 6 16 12 16"
          stroke="currentColor"
          stroke-width="3"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <circle cx="8" cy="16" r="3" fill="currentColor" />
        <circle cx="24" cy="32" r="3" fill="currentColor" />
        <circle cx="40" cy="16" r="3" fill="currentColor" />
      </svg>
    `;
    return avatar;
  }

  function createRecordingCard(item) {
    const listItem = document.createElement('li');
    listItem.className = 'recordings-list__item';

    const anchor = document.createElement('a');
    anchor.className = 'recording-card';
    anchor.href = `/recordings/${encodeURIComponent(item.id)}`;
    anchor.setAttribute('aria-label', `${formatRecordingTitle(item)}. Открыть детальную страницу`);

    const avatar = createAvatar();
    const content = document.createElement('div');
    content.className = 'recording-card__content';

    const title = document.createElement('h3');
    title.className = 'recording-card__title';
    title.textContent = formatRecordingTitle(item);

    const meta = document.createElement('div');
    meta.className = 'recording-card__meta';

    const duration = formatDuration(item.duration_s);
    const size = formatFileSize(item.size_bytes);

    const info = document.createElement('span');
    info.textContent = `${duration} · ${size}`;

    meta.appendChild(info);
    meta.appendChild(createStatusBadge(item));

    content.appendChild(title);
    content.appendChild(meta);

    anchor.appendChild(avatar);
    anchor.appendChild(content);
    anchor.appendChild(createChevron());

    listItem.appendChild(anchor);

    return listItem;
  }

  function initRecordingsList(root) {
    const container = root.querySelector('.recordings-container');
    const loader = root.querySelector('[data-recordings-loader]');
    const list = root.querySelector('[data-recordings-items]');
    let emptyState = root.querySelector('[data-recordings-empty]');
    const errorState = root.querySelector('[data-recordings-error]');
    const retryButton = root.querySelector('[data-recordings-retry]');
    const loadMoreButton = root.querySelector('[data-recordings-load-more]');

    const state = {
      loading: false,
      nextCursor: undefined,
      initialized: false,
      recordingIds: new Set(),
    };

    function setLoading(isLoading, { initial = false } = {}) {
      state.loading = isLoading;
      if (container) {
        container.setAttribute('aria-busy', String(isLoading));
      }

      if (loader) {
        const hasItems = Boolean(list && list.children.length > 0);
        const shouldShowLoader = isLoading && !hasItems;
        loader.hidden = !shouldShowLoader;
        loader.setAttribute('aria-hidden', shouldShowLoader ? 'false' : 'true');
      }

      if (loadMoreButton && !initial) {
        loadMoreButton.disabled = isLoading;
      }
    }

    function showError(message) {
      if (errorState) {
        errorState.hidden = false;
        errorState.setAttribute('aria-hidden', 'false');
        if (message) {
          const text = errorState.querySelector('span');
          if (text) {
            text.textContent = message;
          }
        }
      }
    }

    function hideError() {
      if (errorState) {
        errorState.hidden = true;
        errorState.setAttribute('aria-hidden', 'true');
      }
    }

    function hideEmpty() {
      if (emptyState) {
        emptyState.hidden = true;
        emptyState.setAttribute('aria-hidden', 'true');
      }
    }

    function showEmpty() {
      if (emptyState) {
        emptyState.hidden = false;
        emptyState.setAttribute('aria-hidden', 'false');
      }
    }

    function removeEmptyState() {
      if (emptyState) {
        emptyState.remove();
        emptyState = null;
      }
    }

    function updateLoadMore(nextCursor) {
      state.nextCursor = nextCursor ?? null;
      if (loadMoreButton) {
        loadMoreButton.hidden = !state.nextCursor;
      }
    }

    async function fetchRecordings(cursor) {
      const response = await apiFetch('/recordings', {
        headers: { Accept: 'application/json' },
        searchParams: cursor ? { cursor } : undefined,
      });
      if (response.status === 401) {
        window.location.href = '/login';
        return null;
      }
      if (!response.ok) {
        throw new Error('Не удалось загрузить записи');
      }
      const data = await response.json();
      const rawItems = Array.isArray(data.items) ? data.items : [];
      const normalizedItems = rawItems
        .map((item) => normalizeRecordingItem(item))
        .filter((item) => item !== null);
      console.log('[recordings] loaded', normalizedItems.length, 'items');
      return {
        items: normalizedItems,
        nextCursor: normalizeCursor(data.next_cursor ?? data.nextCursor ?? null),
      };
    }

    async function load({ initial = false } = {}) {
      if (state.loading) {
        return;
      }
      hideError();
      if (initial) {
        hideEmpty();
        updateLoadMore(null);
      }
      setLoading(true, { initial });

      try {
        const payload = await fetchRecordings(initial ? undefined : state.nextCursor);
        if (!payload) {
          return;
        }
        state.initialized = true;

        if (initial) {
          list.innerHTML = '';
          state.recordingIds.clear();
        }

        const items = Array.isArray(payload.items) ? payload.items : [];
        const newItems = items.filter((item) => {
          if (!item || !item.id) {
            return false;
          }
          if (state.recordingIds.has(item.id)) {
            return false;
          }
          state.recordingIds.add(item.id);
          return true;
        });

        if (newItems.length === 0 && state.recordingIds.size === 0) {
          showEmpty();
          updateLoadMore(null);
          return;
        }

        if (newItems.length > 0) {
          removeEmptyState();
        }

        newItems.forEach((item) => {
          list.appendChild(createRecordingCard(item));
        });

        updateLoadMore(payload.nextCursor ?? null);
        hideError();
      } catch (err) {
        console.error(err);
        if (!state.initialized) {
          list.innerHTML = '';
          state.recordingIds.clear();
        }
        showError(err.message);
      } finally {
        setLoading(false, { initial });
      }
    }

    if (retryButton) {
      retryButton.addEventListener('click', () => {
        load({ initial: true });
      });
    }

    if (loadMoreButton) {
      loadMoreButton.addEventListener('click', () => {
        load({ initial: false });
      });
    }

    load({ initial: true });
  }

  function appendMessage(conversation, role, text, { typing = false } = {}) {
    const wrapper = document.createElement('div');
    wrapper.className = `qa-message qa-message--${role}`;

    const bubble = document.createElement('div');
    bubble.className = 'qa-message__bubble';
    const paragraph = document.createElement('p');
    paragraph.textContent = text;
    bubble.appendChild(paragraph);

    if (typing) {
      wrapper.classList.add('is-loading');
      bubble.classList.add('is-typing');
    }

    const meta = document.createElement('div');
    meta.className = 'qa-message__meta';
    const author = role === 'user' ? 'Вы' : 'Ghost AI';
    meta.textContent = `${author} • ${timeFormatter.format(new Date())}`;

    wrapper.appendChild(bubble);
    wrapper.appendChild(meta);
    conversation.appendChild(wrapper);
    conversation.scrollTo({ top: conversation.scrollHeight, behavior: 'smooth' });

    return { wrapper, bubble, paragraph, meta };
  }

  function prepareSummaryElements(root) {
    if (!root) {
      return null;
    }
    return {
      skeleton: root.querySelector('[data-summary-skeleton]'),
      content: root.querySelector('[data-summary-content]'),
      empty: root.querySelector('[data-summary-empty]'),
      intro: root.querySelector('[data-summary-intro]'),
      updated: root.querySelector('[data-summary-updated]'),
      highlights: root.querySelector('[data-summary-highlights]'),
      highlightsList: root.querySelector('[data-summary-highlights-list]'),
      actions: root.querySelector('[data-summary-actions]'),
      actionsList: root.querySelector('[data-summary-actions-list]'),
      decisions: root.querySelector('[data-summary-decisions]'),
      decisionsList: root.querySelector('[data-summary-decisions-list]'),
    };
  }

  function renderSummarySection(section, list, items) {
    if (!section || !list) {
      return;
    }
    list.innerHTML = '';
    if (!Array.isArray(items) || items.length === 0) {
      section.hidden = true;
      return;
    }
    const fragment = document.createDocumentFragment();
    items.forEach((item) => {
      const li = document.createElement('li');
      li.textContent = item;
      fragment.appendChild(li);
    });
    list.appendChild(fragment);
    section.hidden = false;
  }

  function renderSummary(elements, status, summary, message) {
    if (!elements) {
      return;
    }

    if (elements.skeleton) {
      elements.skeleton.hidden = true;
    }

    if (elements.content) {
      elements.content.hidden = true;
    }

    if (elements.empty) {
      elements.empty.hidden = true;
    }

    if (status !== 'ready' || !summary) {
      if (elements.empty) {
        elements.empty.hidden = false;
        const paragraph = elements.empty.querySelector('p');
        if (paragraph) {
          paragraph.textContent = message || 'Резюме появится сразу после обработки записи.';
        }
      }
      return;
    }

    if (elements.content) {
      elements.content.hidden = false;
    }

    if (elements.intro) {
      elements.intro.textContent = summary.intro;
    }

    if (elements.updated) {
      if (summary.updatedAt) {
        const parsed = new Date(summary.updatedAt);
        if (!Number.isNaN(parsed.getTime())) {
          elements.updated.hidden = false;
          elements.updated.textContent = `Обновлено ${summaryDateFormatter.format(parsed)}`;
        } else {
          elements.updated.hidden = true;
        }
      } else {
        elements.updated.hidden = true;
      }
    }

    renderSummarySection(elements.highlights, elements.highlightsList, summary.highlights);
    renderSummarySection(elements.actions, elements.actionsList, summary.actionItems);
    renderSummarySection(elements.decisions, elements.decisionsList, summary.decisions);
  }

  function renderTranscriptEntries(container, entries) {
    if (!container) {
      return;
    }

    container.innerHTML = '';

    const fragment = document.createDocumentFragment();
    const list = Array.isArray(entries) ? entries : [];
    list.forEach((entry) => {
      if (!entry || typeof entry.text !== 'string') {
        return;
      }

      const speakerName = entry.speaker || 'Участник';

      const item = document.createElement('article');
      item.className = 'transcript-entry';

      const time = document.createElement('span');
      time.className = 'transcript-entry__time';
      time.textContent = formatTranscriptTime(entry.start);
      item.appendChild(time);

      const body = document.createElement('div');
      body.className = 'transcript-entry__body';

      const speaker = document.createElement('div');
      speaker.className = 'transcript-entry__speaker';

      const name = document.createElement('span');
      name.className = 'transcript-entry__name';
      name.textContent = speakerName;
      speaker.appendChild(name);

      if (entry.role) {
        const role = document.createElement('span');
        role.className = 'transcript-entry__role';
        role.textContent = entry.role;
        speaker.appendChild(role);
      }

      body.appendChild(speaker);

      const text = document.createElement('p');
      text.className = 'transcript-entry__text';
      text.textContent = entry.text;
      body.appendChild(text);

      item.appendChild(body);
      fragment.appendChild(item);
    });

    container.appendChild(fragment);
  }

  function initTranscript(root, recordingId) {
    const panel = root.querySelector('[data-transcript-panel]');
    if (!panel) {
      return;
    }

    const summaryElements = prepareSummaryElements(root.querySelector('[data-recording-summary]'));

    const skeleton = panel.querySelector('[data-transcript-skeleton]');
    const content = panel.querySelector('[data-transcript-content]');
    const timeline = panel.querySelector('[data-transcript-list]');
    const emptyState = panel.querySelector('[data-transcript-empty]');
    const emptyMessage = emptyState ? emptyState.querySelector('[data-transcript-empty-message]') : null;
    const errorState = panel.querySelector('[data-transcript-error]');
    const errorMessage = errorState ? errorState.querySelector('[data-transcript-error-message]') : null;

    async function loadTranscript() {
      if (skeleton) {
        skeleton.hidden = false;
      }

      if (content) {
        content.hidden = true;
      }
      if (emptyState) {
        emptyState.hidden = true;
      }
      if (errorState) {
        errorState.hidden = true;
      }

      if (summaryElements?.skeleton) {
        summaryElements.skeleton.hidden = false;
      }

      try {
        const response = await apiFetch(`/recordings/${encodeURIComponent(recordingId)}/transcript`, {
          headers: { Accept: 'application/json' },
        });
        if (response.status === 401) {
          window.location.href = '/login';
          return;
        }
        if (!response.ok) {
          console.error('Не удалось загрузить транскрипт: статус %s', response.status);
          throw new Error('Не удалось загрузить транскрипт');
        }
        const data = await response.json();
        const status = typeof data.status === 'string' ? data.status : 'processing';
        const summary = data && typeof data.summary === 'object' ? data.summary : null;
        const entries = data && data.transcript && Array.isArray(data.transcript.entries)
          ? data.transcript.entries
          : [];
        const message = typeof data.message === 'string' ? data.message : '';

        if (summaryElements) {
          renderSummary(summaryElements, status, summary, message);
        }

        if (skeleton) {
          skeleton.hidden = true;
        }

        if (status === 'failed') {
          if (errorState) {
            errorState.hidden = false;
            if (errorMessage) {
              errorMessage.textContent = message || 'Не удалось загрузить транскрипт. Попробуйте обновить страницу.';
            }
          }
          return;
        }

        if (status !== 'ready' || entries.length === 0) {
          if (emptyState) {
            emptyState.hidden = false;
            if (emptyMessage) {
              emptyMessage.textContent = message || 'Транскрипт будет доступен после завершения обработки записи.';
            }
          }
          return;
        }

        if (content && timeline) {
          renderTranscriptEntries(timeline, entries);
          content.hidden = false;
        }
      } catch (err) {
        console.error('Ошибка при загрузке транскрипта', err);
        if (summaryElements) {
          renderSummary(summaryElements, 'failed', null, 'Не удалось загрузить резюме встречи. Попробуйте позже.');
        }
        if (skeleton) {
          skeleton.hidden = true;
        }
        if (errorState) {
          errorState.hidden = false;
          if (errorMessage) {
            errorMessage.textContent = 'Не удалось загрузить транскрипт. Попробуйте обновить страницу.';
          }
        }
      }
    }

    loadTranscript();
  }

  function initQaPanel(root, recordingId) {
    const panel = root.querySelector('[data-qa-panel]');
    if (!panel) {
      return;
    }
    const conversation = panel.querySelector('[data-qa-conversation]');
    const quickPrompts = Array.from(panel.querySelectorAll('[data-quick-prompt]'));
    const form = panel.querySelector('[data-qa-form]');
    const input = panel.querySelector('[data-qa-input]');
    const submit = panel.querySelector('[data-qa-submit]');

    if (!conversation || !form || !input || !submit) {
      return;
    }

    function setDisabled(disabled) {
      input.disabled = disabled;
      submit.disabled = disabled;
      quickPrompts.forEach((button) => {
        button.disabled = disabled;
      });
    }

    appendMessage(conversation, 'assistant', 'Ghost AI готов ответить на ваши вопросы по этой встрече.', {});

    async function sendPrompt(promptText) {
      const text = promptText.trim();
      if (!text) {
        return;
      }

      const userMessage = appendMessage(conversation, 'user', text);
      const assistantMessage = appendMessage(conversation, 'assistant', '', { typing: true });

      setDisabled(true);
      input.value = '';

      try {
        const response = await apiFetch(`/recordings/${encodeURIComponent(recordingId)}/ask`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
          },
          body: JSON.stringify({ prompt: text }),
        });
        if (response.status === 401) {
          window.location.href = '/login';
          return;
        }
        if (!response.ok) {
          throw new Error('Ghost AI временно недоступен. Попробуйте позже.');
        }
        const data = await response.json();
        const answer = typeof data.answer === 'string' ? data.answer.trim() : '';

        assistantMessage.wrapper.classList.remove('is-loading');
        assistantMessage.bubble.classList.remove('is-typing');
        assistantMessage.paragraph.textContent = answer || 'Ответ появится после завершения обработки записи.';
        assistantMessage.meta.textContent = `Ghost AI • ${timeFormatter.format(new Date())}`;
      } catch (err) {
        console.error(err);
        assistantMessage.wrapper.classList.remove('is-loading');
        assistantMessage.wrapper.classList.add('has-error');
        assistantMessage.bubble.classList.remove('is-typing');
        assistantMessage.paragraph.textContent = err.message || 'Не удалось получить ответ.';
        assistantMessage.meta.textContent = `Ghost AI • ${timeFormatter.format(new Date())}`;
      } finally {
        setDisabled(false);
        input.focus();
      }
    }

    form.addEventListener('submit', (event) => {
      event.preventDefault();
      sendPrompt(input.value);
    });

    quickPrompts.forEach((button) => {
      button.addEventListener('click', () => {
        sendPrompt(button.textContent || '');
      });
    });
  }

  function initTabs(root) {
    const tabButtons = Array.from(root.querySelectorAll('[data-tab-target]'));
    const panels = Array.from(root.querySelectorAll('[data-tab-panel]'));

    function activate(target) {
      tabButtons.forEach((button) => {
        const isActive = button.dataset.tabTarget === target;
        button.classList.toggle('is-active', isActive);
        button.setAttribute('aria-selected', String(isActive));
        if (isActive) {
          button.focus({ preventScroll: true });
        }
      });
      panels.forEach((panel) => {
        const isActive = panel.dataset.tabPanel === target;
        panel.hidden = !isActive;
      });
    }

    tabButtons.forEach((button) => {
      button.addEventListener('click', () => {
        if (!button.classList.contains('is-active')) {
          activate(button.dataset.tabTarget);
        }
      });
      button.addEventListener('keydown', (event) => {
        if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
          event.preventDefault();
          const currentIndex = tabButtons.indexOf(button);
          const nextIndex = event.key === 'ArrowRight'
            ? (currentIndex + 1) % tabButtons.length
            : (currentIndex - 1 + tabButtons.length) % tabButtons.length;
          activate(tabButtons[nextIndex].dataset.tabTarget);
        }
      });
    });
  }

  function initRecordingPage(root) {
    const recordingId = root.dataset.recordingId;
    if (!recordingId) {
      return;
    }

    initTabs(root);
    initTranscript(root, recordingId);
    initQaPanel(root, recordingId);
  }

  document.addEventListener('DOMContentLoaded', () => {
    const listRoot = document.querySelector('[data-recordings-list]');
    if (listRoot) {
      initRecordingsList(listRoot);
    }

    const recordingPage = document.querySelector('[data-recording-page]');
    if (recordingPage) {
      initRecordingPage(recordingPage);
    }
  });
})();
