export type RecordingItem = {
  id: string;
  started_at: string;
  ended_at?: string;
  duration_s?: number;
  size_bytes?: number;
  status: 'uploading' | 'uploaded' | 'failed';
  content_type?: 'audio/mp4';
};

type ListResult = {
  items: RecordingItem[];
  nextCursor?: string | null;
};

const recordings: RecordingItem[] = [
  {
    id: 'rec-20251002-1245',
    started_at: '2025-10-02T12:45:00.000Z',
    ended_at: '2025-10-02T13:28:12.000Z',
    duration_s: 2612,
    size_bytes: 9452812,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250928-0900',
    started_at: '2025-09-28T09:00:00.000Z',
    ended_at: '2025-09-28T10:05:44.000Z',
    duration_s: 3944,
    size_bytes: 13540992,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250921-1605',
    started_at: '2025-09-21T16:05:00.000Z',
    ended_at: '2025-09-21T16:55:37.000Z',
    duration_s: 3037,
    size_bytes: 10834221,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250914-1015',
    started_at: '2025-09-14T10:15:00.000Z',
    ended_at: '2025-09-14T11:02:41.000Z',
    duration_s: 2851,
    size_bytes: 9634201,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250908-0830',
    started_at: '2025-09-08T08:30:00.000Z',
    ended_at: '2025-09-08T09:12:12.000Z',
    duration_s: 252, // short daily standup
    size_bytes: 274330,
    status: 'failed',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250905-1400',
    started_at: '2025-09-05T14:00:00.000Z',
    ended_at: '2025-09-05T15:18:24.000Z',
    duration_s: 4704,
    size_bytes: 16123001,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250901-0930',
    started_at: '2025-09-01T09:30:00.000Z',
    ended_at: '2025-09-01T10:10:11.000Z',
    duration_s: 2411,
    size_bytes: 8420011,
    status: 'uploading',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250827-1100',
    started_at: '2025-08-27T11:00:00.000Z',
    ended_at: '2025-08-27T12:34:02.000Z',
    duration_s: 5642,
    size_bytes: 19344022,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250819-1500',
    started_at: '2025-08-19T15:00:00.000Z',
    ended_at: '2025-08-19T16:05:44.000Z',
    duration_s: 3944,
    size_bytes: 13700329,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250812-1005',
    started_at: '2025-08-12T10:05:00.000Z',
    ended_at: '2025-08-12T11:40:18.000Z',
    duration_s: 570, // follow-up call, still processing
    size_bytes: 638992,
    status: 'uploading',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250805-0940',
    started_at: '2025-08-05T09:40:00.000Z',
    ended_at: '2025-08-05T10:32:05.000Z',
    duration_s: 3125,
    size_bytes: 10923411,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250728-1300',
    started_at: '2025-07-28T13:00:00.000Z',
    ended_at: '2025-07-28T13:52:18.000Z',
    duration_s: 3138,
    size_bytes: 11128900,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250721-0915',
    started_at: '2025-07-21T09:15:00.000Z',
    ended_at: '2025-07-21T10:05:55.000Z',
    duration_s: 3055,
    size_bytes: 10455822,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250714-1705',
    started_at: '2025-07-14T17:05:00.000Z',
    ended_at: '2025-07-14T18:12:32.000Z',
    duration_s: 4032,
    size_bytes: 14011567,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250708-1100',
    started_at: '2025-07-08T11:00:00.000Z',
    ended_at: '2025-07-08T11:48:22.000Z',
    duration_s: 2902,
    size_bytes: 9823401,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250701-0830',
    started_at: '2025-07-01T08:30:00.000Z',
    ended_at: '2025-07-01T09:45:30.000Z',
    duration_s: 4530,
    size_bytes: 15822933,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250624-0945',
    started_at: '2025-06-24T09:45:00.000Z',
    ended_at: '2025-06-24T10:30:37.000Z',
    duration_s: 2737,
    size_bytes: 9588221,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250617-1505',
    started_at: '2025-06-17T15:05:00.000Z',
    ended_at: '2025-06-17T16:02:48.000Z',
    duration_s: 347, // call dropped
    size_bytes: 385550,
    status: 'failed',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250610-1200',
    started_at: '2025-06-10T12:00:00.000Z',
    ended_at: '2025-06-10T12:54:11.000Z',
    duration_s: 3241,
    size_bytes: 11233821,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
  {
    id: 'rec-20250603-1015',
    started_at: '2025-06-03T10:15:00.000Z',
    ended_at: '2025-06-03T11:20:45.000Z',
    duration_s: 3975,
    size_bytes: 13778920,
    status: 'uploaded',
    content_type: 'audio/mp4',
  },
];

const sortedRecordings = [...recordings].sort((a, b) => {
  return new Date(b.started_at).getTime() - new Date(a.started_at).getTime();
});

const PAGE_SIZE = 8;

const simulateLatency = async (min = 120, max = 260) => {
  const duration = Math.floor(Math.random() * (max - min + 1)) + min;
  await new Promise((resolve) => setTimeout(resolve, duration));
};

const resolveDuration = (item: RecordingItem): RecordingItem => {
  if (item.duration_s || !item.started_at || !item.ended_at) {
    return item;
  }

  const started = new Date(item.started_at).getTime();
  const ended = new Date(item.ended_at).getTime();
  const duration = Math.max(0, Math.round((ended - started) / 1000));
  return { ...item, duration_s: duration };
};

export async function listRecordings(cursor?: string): Promise<ListResult> {
  await simulateLatency();

  const offset = cursor ? Number.parseInt(cursor, 10) || 0 : 0;
  const slice = sortedRecordings.slice(offset, offset + PAGE_SIZE).map(resolveDuration);

  const nextCursor = offset + PAGE_SIZE < sortedRecordings.length ? String(offset + PAGE_SIZE) : null;

  return {
    items: slice,
    nextCursor,
  };
}

export async function getRecording(id: string): Promise<RecordingItem> {
  await simulateLatency();
  const found = sortedRecordings.find((recording) => recording.id === id);
  if (!found) {
    throw new Error('Recording not found');
  }
  return resolveDuration(found);
}

export async function getPlaybackUrl(id: string): Promise<string> {
  await simulateLatency(80, 180);
  return `https://cdn.ghostai.ru/recordings/${id}.mp4`;
}

export async function getTranscript(id: string): Promise<string> {
  await simulateLatency(150, 320);
  const recording = sortedRecordings.find((item) => item.id === id);
  if (!recording) {
    return 'Транскрипт будет доступен после завершения обработки записи.';
  }

  if (recording.status !== 'uploaded') {
    return 'Транскрипт будет доступен после завершения обработки записи.';
  }

  const startedAt = recording.started_at
    ? new Date(recording.started_at).toLocaleString('ru-RU', {
        dateStyle: 'medium',
        timeStyle: 'short',
      })
    : null;

  if (!startedAt) {
    return 'Транскрипт будет доступен позже. Пока мы готовим расшифровку, вы можете попросить ИИ составить резюме или список задач.';
  }

  return `Транскрипт будет доступен позже.\n\n` +
    `Пока мы готовим расшифровку встречи «${startedAt}», вы можете попросить ИИ составить резюме или список задач.`;
}

export async function askAi(id: string, prompt: string): Promise<string> {
  await simulateLatency(500, 820);
  const recording = sortedRecordings.find((item) => item.id === id);

  const cannedResponses = [
    'Это будет доступно после завершения обработки записи. Мы подготовим ключевые моменты и пришлем уведомление.',
    'Я зафиксировал основные темы и подготовлю подробное резюме, как только транскрипт будет доступен.',
    'По предварительным данным: обсуждали продуктовую дорожную карту, задачи по маркетингу и сроки релиза.',
    'Основные action items уже добавлены в черновик. Проверьте вкладку «Задачи» после финальной синхронизации.',
  ];

  const normalizedPrompt = prompt.trim().toLowerCase();
  if (!normalizedPrompt) {
    return 'Я готов помочь, как только вы сформулируете вопрос или выберете готовую подсказку.';
  }

  const seedId = recording ? recording.id : id;
  const seed = normalizedPrompt.length + seedId.length;
  const index = seed % cannedResponses.length;
  return cannedResponses[index];
}
