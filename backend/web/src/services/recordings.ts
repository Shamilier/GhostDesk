const API_BASE_URL = process.env.GHOSTAI_API_BASE_URL || 'https://api.ghostai.ru';

export type TranscriptStatus = 'none' | 'queued' | 'processing' | 'ready' | 'failed';

export type TranscriptResult = {
  status: TranscriptStatus;
  summary: string | null;
  transcript: string | null;
  error: string | null;
};

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const randomDelay = async (min = 120, max = 260) => {
  const duration = Math.floor(Math.random() * (max - min + 1)) + min;
  await delay(duration);
};

const buildApiUrl = (path: string) => {
  return new URL(path, API_BASE_URL).toString();
};

const buildAuthHeader = (userId: string) => `Bearer web-user-${userId}`;

const collectAlternatives = (transcript: any): string[] => {
  if (!transcript || typeof transcript !== 'object') {
    return [];
  }

  const channels = Array.isArray(transcript?.results?.channels) ? transcript.results.channels : [];
  const collected: string[] = [];

  for (const channel of channels) {
    const alternatives = Array.isArray(channel?.alternatives) ? channel.alternatives : [];
    const bestAlternative = alternatives.find((item: any) => {
      return typeof item?.transcript === 'string' && item.transcript.trim().length > 0;
    });
    if (bestAlternative && typeof bestAlternative.transcript === 'string') {
      collected.push(bestAlternative.transcript.trim());
      continue;
    }

    for (const item of alternatives) {
      if (typeof item?.transcript === 'string' && item.transcript.trim().length > 0) {
        collected.push(item.transcript.trim());
      }
    }
  }

  return collected;
};

const collectWords = (transcript: any): string => {
  if (!transcript || typeof transcript !== 'object') {
    return '';
  }

  const channels = Array.isArray(transcript?.results?.channels) ? transcript.results.channels : [];
  const words: string[] = [];

  for (const channel of channels) {
    const alternatives = Array.isArray(channel?.alternatives) ? channel.alternatives : [];
    for (const alternative of alternatives) {
      const alternativeWords = Array.isArray(alternative?.words) ? alternative.words : [];
      for (const word of alternativeWords) {
        if (typeof word?.punctuated_word === 'string' && word.punctuated_word.trim()) {
          words.push(word.punctuated_word.trim());
        } else if (typeof word?.word === 'string' && word.word.trim()) {
          words.push(word.word.trim());
        }
      }
      if (words.length > 0) {
        break;
      }
    }
    if (words.length > 0) {
      break;
    }
  }

  return words.join(' ').replace(/\s+/g, ' ').trim();
};

const extractTranscriptText = (payload: any): string => {
  if (!payload) {
    return '';
  }

  if (typeof payload === 'string') {
    return payload.trim();
  }

  const alternatives = collectAlternatives(payload);
  if (alternatives.length > 0) {
    const unique = Array.from(new Set(alternatives.map((item) => item.trim()).filter(Boolean)));
    return unique.join('\n\n');
  }

  const words = collectWords(payload);
  if (words) {
    return words;
  }

  try {
    return JSON.stringify(payload, null, 2);
  } catch (error) {
    return '';
  }
};

const KNOWN_STATUSES: TranscriptStatus[] = ['none', 'queued', 'processing', 'ready', 'failed'];

const parseTranscriptResponse = (body: string | null | undefined): TranscriptResult => {
  if (!body) {
    return { status: 'none', summary: null, transcript: null, error: null };
  }

  let payload: any = null;
  try {
    payload = JSON.parse(body);
  } catch (error) {
    const err = new Error('Invalid transcript payload received from API');
    (err as any).code = 'invalid_payload';
    throw err;
  }

  const rawStatus = typeof payload?.status === 'string' ? payload.status : 'none';
  const status = KNOWN_STATUSES.includes(rawStatus as TranscriptStatus) ? (rawStatus as TranscriptStatus) : 'none';
  const summary = typeof payload?.summary === 'string' && payload.summary.trim() ? payload.summary.trim() : null;
  const error = typeof payload?.error === 'string' && payload.error.trim() ? payload.error.trim() : null;

  let transcriptText: string | null = null;
  if (status === 'ready') {
    const extracted = extractTranscriptText(payload?.transcript);
    transcriptText = extracted ? extracted : null;
  }

  return {
    status,
    summary,
    transcript: transcriptText,
    error,
  };
};

export async function getTranscript(userId: string, recordingId: string): Promise<TranscriptResult> {
  if (!userId) {
    throw new Error('User ID is required to load transcript');
  }
  if (!recordingId) {
    throw new Error('Recording ID is required to load transcript');
  }

  await randomDelay(90, 180);

  const url = buildApiUrl(`/v1/recordings/${encodeURIComponent(recordingId)}/transcript`);
  const startedAt = Date.now();

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: buildAuthHeader(userId),
      Accept: 'application/json',
    },
  });

  const rawBody = await response.text();

  console.log(
    '[recordings] transcript user=%s rec=%s status=%s in=%dms bodyLen=%d',
    userId,
    recordingId,
    response.status,
    Date.now() - startedAt,
    rawBody.length,
  );

  if (response.status === 404) {
    throw new Error('Recording not found');
  }

  if (!response.ok) {
    const err = new Error('Failed to load transcript from upstream API');
    (err as any).code = 'upstream_error';
    (err as any).status = response.status;
    (err as any).body = rawBody;
    throw err;
  }

  return parseTranscriptResponse(rawBody);
}

export async function askAi(id: string, prompt: string): Promise<string> {
  await randomDelay(500, 820);

  const cannedResponses = [
    'Это будет доступно после завершения обработки записи. Мы подготовим ключевые моменты и пришлём уведомление.',
    'Я зафиксировал основные темы и подготовлю подробное резюме, как только транскрипт будет доступен.',
    'По предварительным данным: обсуждали продуктовую дорожную карту, задачи по маркетингу и сроки релиза.',
    'Основные action items уже добавлены в черновик. Проверьте вкладку «Задачи» после финальной синхронизации.',
  ];

  const normalizedPrompt = prompt.trim().toLowerCase();
  if (!normalizedPrompt) {
    return 'Я готов помочь, как только вы сформулируете вопрос или выберете готовую подсказку.';
  }

  const seed = normalizedPrompt.length + id.length;
  const index = seed % cannedResponses.length;
  return cannedResponses[index];
}
