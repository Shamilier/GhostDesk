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

export type TranscriptEntry = {
  speaker: string;
  role?: string;
  start: number;
  text: string;
};

export type TranscriptSummary = {
  intro: string;
  highlights: string[];
  actionItems?: string[];
  decisions?: string[];
  updatedAt?: string;
};

type TranscriptData = {
  summary: TranscriptSummary;
  entries: TranscriptEntry[];
};

export type TranscriptResponse = {
  status: 'processing' | 'ready' | 'failed';
  message?: string;
  summary?: TranscriptSummary;
  transcript?: {
    entries: TranscriptEntry[];
  };
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

const transcriptLibrary: Record<string, TranscriptData> = {
  'rec-20251002-1245': {
    summary: {
      intro:
        'Команда синхронизировалась по запуску новой версии Ghost AI Assistant, уточнила состав релизного набора и распределила зоны ответственности.',
      highlights: [
        'Закрепили релиз 0.9 на 20 октября с ночным окном развертывания.',
        'Маркетинг запускает превью-кампанию с 9 октября и фокусируется на сегменте founder/PM.',
        'Поддержка подготовит сценарии ответов и откроет чат в helpdesk за сутки до релиза.',
      ],
      actionItems: [
        'Иван собирает контрольный чек-лист по инфраструктуре и шэрит его до 7 октября.',
        'Марина готовит демонстрационный сценарий и финализирует ролик с продакшеном.',
        'Алина согласует бюджет промокампании с финансами и возвращает апдейт к пятнице.',
      ],
      decisions: [
        'Стартовый тариф оставляем на уровне $39 с пересмотром ARPU через месяц после релиза.',
        'Обратную связь из беты собираем через Notion-борд и обрабатываем раз в два дня.',
      ],
      updatedAt: '2025-10-02T14:05:00.000Z',
    },
    entries: [
      {
        speaker: 'Анна Смирнова',
        role: 'CEO',
        start: 0,
        text: 'Коллеги, давайте ещё раз синхронизируемся по релизу 0.9 Ghost AI Assistant. Хотелось бы подтвердить дату и набор обязательных функций.',
      },
      {
        speaker: 'Иван Трофимов',
        role: 'CTO',
        start: 48,
        text: 'С технической стороны мы готовы к выкладке ночью 20 октября. Осталось пройтись по чек-листу резервирования и сделать финальный нагрузочный прогон.',
      },
      {
        speaker: 'Марина Лебедева',
        role: 'Marketing Lead',
        start: 118,
        text: 'Я подтвердила съёмку демо-ролика на следующую среду. Кампания стартует 9 октября, делаем акцент на фаундерах и продакт-лидах.',
      },
      {
        speaker: 'Дмитрий Ким',
        role: 'Head of Support',
        start: 206,
        text: 'Сценарии FAQ готовы на 70%. Команда поддержки будет на связи с ночи релиза, чат откроем за сутки, чтобы поймать ранние вопросы.',
      },
      {
        speaker: 'Анна Смирнова',
        role: 'CEO',
        start: 312,
        text: 'Тогда фиксируем: Иван закрывает инфраструктурный чек-лист до понедельника, Марина и Алина синхронизируются по бюджету, а поддержка готова к открытию чата.',
      },
    ],
  },
  'rec-20250928-0900': {
    summary: {
      intro:
        'Встреча была посвящена customer success-показателям: разобрали поведение новых команд и актуализировали план удержания пользователей.',
      highlights: [
        'MRR удержался на целевом уровне, но вырос отток среди команд до 10 человек.',
        'Главные триггеры оттока — медленный онбординг и отсутствие готовых шаблонов для product discovery.',
        'Support готов протестировать новый сценарий сопровождения с pro-аккаунтами.',
      ],
      actionItems: [
        'Катя готовит серию писем с лайфхаками по первым шагам в продукте.',
        'Саша запускает пилот по персональному онбордингу для сегмента 5–15 человек.',
        'Data-команда внедряет дашборд по retention в ежедневный отчёт.',
      ],
      decisions: [
        'Утверждён запуск библиотеки discovery-шаблонов в ноябре.',
      ],
      updatedAt: '2025-09-28T10:32:00.000Z',
    },
    entries: [
      {
        speaker: 'Катя Назарова',
        role: 'Head of Customer Success',
        start: 12,
        text: 'По сентябрю churn в сегменте 5–10 человек вырос до 7%. Пользователи уходят, не разобравшись с первыми шагами.',
      },
      {
        speaker: 'Саша Гончаров',
        role: 'Product Manager',
        start: 74,
        text: 'Я предлагаю добавить персональный welcome-call на первую неделю и упростить подключение календарей — это частая жалоба.',
      },
      {
        speaker: 'Лена Тарасова',
        role: 'Data Analyst',
        start: 142,
        text: 'Дашборд по retention можем вынести в ежедневный отчёт. Ещё видно, что те, кто попробовал шаблоны discovery, остаются в два раза чаще.',
      },
      {
        speaker: 'Катя Назарова',
        role: 'Head of Customer Success',
        start: 201,
        text: 'Тогда собираю серию писем с подсказками и запросим маркетинг помочь с оформлением. Пилот персонального онбординга стартует со следующей недели.',
      },
    ],
  },
  'rec-20250921-1605': {
    summary: {
      intro:
        'Продакт и инженеры обсудили дорожную карту по модулю транскрибации: выстроили приоритеты и синхронизировали команду по срокам.',
      highlights: [
        'Приоритет №1 — ускорить обработку длинных записей за счёт параллельной нарезки.',
        'Команда договорилась вынести smart-summary в отдельный сервис, чтобы упростить масштабирование.',
        'Для мобильного клиента нужен офлайн-кеш последних трёх встреч.',
      ],
      actionItems: [
        'Миша прототипирует параллельную обработку и выносит результаты на ревью через два дня.',
        'Юля описывает API smart-summary до пятницы и согласует контракт с веб-командой.',
        'QA готовит сценарии нагрузочного теста и синхронизируется с DevOps.',
      ],
      updatedAt: '2025-09-21T17:20:00.000Z',
    },
    entries: [
      {
        speaker: 'Юля Орлова',
        role: 'Lead Product Manager',
        start: 6,
        text: 'Нужно ускорить транскрибацию записей длиннее часа. Сейчас SLA в 15 минут, но клиенты ожидают 5–7.',
      },
      {
        speaker: 'Михаил Кузнецов',
        role: 'Senior Engineer',
        start: 58,
        text: 'Давайте порежем запись на сегменты и запустим параллельную обработку. Нужно проверить, насколько Deepgram потянет пять одновременных потоков.',
      },
      {
        speaker: 'Олег Белов',
        role: 'Mobile Lead',
        start: 126,
        text: 'Для мобильного клиента добавим офлайн-кеш последних трёх встреч, чтобы не ждать сети. Нужен API с инкрементальными обновлениями.',
      },
      {
        speaker: 'Юля Орлова',
        role: 'Lead Product Manager',
        start: 214,
        text: 'Супер, тогда я опишу API smart-summary и вынесу на обсуждение с вебом. Дедлайн — пятница.',
      },
    ],
  },
  'rec-20250914-1015': {
    summary: {
      intro:
        'Команда продаж и партнёрства обсудила результаты демо-недели и скорректировала стратегию по enterprise-лидам.',
      highlights: [
        'Conversion в пилот вырос до 32%, но cycle по крупным лидам всё ещё тянется 6 недель.',
        'Новые отраслевые истории успеха нужны для финала переговоров.',
        'Партнёры просят понятный прайсинг на white-label.',
      ],
      actionItems: [
        'Сергей собирает обновлённый pitch deck с примерами из финтеха и edtech.',
        'Ольга готовит матрицу цен для white-label и синхронизируется с юристами.',
        'Customer success включает enterprise-лидов в еженедельный health-check.',
      ],
      decisions: [
        'Фокус на отраслях финтех и образование в Q4.',
      ],
      updatedAt: '2025-09-14T11:15:00.000Z',
    },
    entries: [
      {
        speaker: 'Сергей Власов',
        role: 'Head of Sales',
        start: 10,
        text: 'По демо-неделе: 24 демо, 8 перешли в пилот. Конверсия ок, но enterprise-лиды зависают на юридическом блоке.',
      },
      {
        speaker: 'Ольга Егорова',
        role: 'Partnerships Lead',
        start: 79,
        text: 'Партнёры ждут прайс на white-label. Нужна матрица с опциями поддержки и SLA, чтобы можно было быстро считать.',
      },
      {
        speaker: 'Илья Петров',
        role: 'Customer Success',
        start: 151,
        text: 'Добавим enterprise-лидов в еженедельный health-check, чтобы ловить риски раньше. Для них подготовим персональные бейслайны.',
      },
      {
        speaker: 'Сергей Власов',
        role: 'Head of Sales',
        start: 228,
        text: 'Ок, обновляю pitch deck с кейсами из финтеха и edtech. Параллельно дожимаем два лида с юристами.',
      },
    ],
  },
};

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

export async function getTranscript(id: string): Promise<TranscriptResponse> {
  await simulateLatency(150, 320);
  const recording = sortedRecordings.find((item) => item.id === id);
  if (!recording) {
    throw new Error('Recording not found');
  }

  if (recording.status === 'failed') {
    return {
      status: 'failed',
      message:
        'Обработку записи завершить не удалось. Попробуйте повторно загрузить файл или обратитесь к поддержке.',
    };
  }

  if (recording.status !== 'uploaded') {
    return {
      status: 'processing',
      message:
        'Мы ещё готовим транскрипт этой встречи. Загляните позже или воспользуйтесь быстрыми подсказками Ghost AI.',
    };
  }

  const stored = transcriptLibrary[id];
  if (!stored) {
    return {
      status: 'processing',
      message:
        'Транскрипт ещё формируется. Мы уведомим вас, как только он будет готов.',
    };
  }

  return {
    status: 'ready',
    summary: stored.summary,
    transcript: {
      entries: stored.entries,
    },
  };
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
