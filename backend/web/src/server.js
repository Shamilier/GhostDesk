require('ts-node/register/transpile-only');

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });
require('dotenv').config();
const express = require('express');
const session = require('express-session');
const helmet = require('helmet');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { customAlphabet } = require('nanoid');

const recordingsService = require('./services/recordings');

const db = require('./db');
const oauth = require('./oauth');
const { getTokensForPlan, hasPlanTokenConfig } = require('./planTokens');
const { store: sessionStore, shutdownSessionStore } = require('./sessionStore');

const app = express();
const GHOSTAI_API_BASE = 'https://api.ghostai.ru';
const ASK_TIMEOUT_MS = 60_000;
const PORT = process.env.PORT || 3000;
const SESSION_SECRET = process.env.SESSION_SECRET || 'ghostai_super_secret';
const INTERNAL_API_SECRET = process.env.INTERNAL_API_SECRET || null;
const nanoid = customAlphabet('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz', 32);

const YOOKASSA_SHOP_ID = process.env.YOOKASSA_SHOP_ID || '1205952';
const YOOKASSA_API_KEY = process.env.YOOKASSA_API_KEY || process.env.YOOKASSA_SECRET_KEY || null;
const YOOKASSA_API_BASE = 'https://api.yookassa.ru/v3';
const BILLING_RETURN_BASE_URL = process.env.BILLING_RETURN_BASE_URL || process.env.APP_BASE_URL || null;
const PLAN_REFRESH_INTERVAL_MS = 60_000;

const TOKEN_DECIMAL_PLACES = 4;
const TOKEN_SCALE = 10 ** TOKEN_DECIMAL_PLACES;

const toTokenUnits = (value) => {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return 0;
  }
  return Math.round(numeric * TOKEN_SCALE);
};

const fromTokenUnits = (units) => units / TOKEN_SCALE;

const normalizeTokenValue = (value) => fromTokenUnits(toTokenUnits(value));

const BILLING_PLANS = {
  plus: {
    label: 'Plus',
    prices: {
      monthly: {
        amount: { value: '1199.00', currency: 'RUB' },
        description: 'Ghostdesk Plus — ежемесячная подписка',
      },
      annual: {
        amount: { value: '11990.00', currency: 'RUB' },
        description: 'Ghostdesk Plus — годовая подписка',
      },
    },
  },
  pro: {
    label: 'Pro',
    prices: {
      monthly: {
        amount: { value: '4999.00', currency: 'RUB' },
        description: 'Ghostdesk Pro — ежемесячная подписка',
      },
      annual: {
        amount: { value: '49990.00', currency: 'RUB' },
        description: 'Ghostdesk Pro — годовая подписка',
      },
    },
  },
};

const PLAN_LABELS = {
  free: 'Free',
  plus_monthly: 'Plus — Месячная подписка',
  plus_annual: 'Plus — Годовая подписка',
  pro_monthly: 'Pro — Месячная подписка',
  pro_annual: 'Pro — Годовая подписка',
};

const isBillingConfigured = () => Boolean(YOOKASSA_SHOP_ID && YOOKASSA_API_KEY);

const buildPlanValue = (planId, cycle) => `${planId}_${cycle}`;

const isSupportedPlanSelection = (planId, cycle) => {
  if (!planId || !cycle) {
    return false;
  }

  const normalizedPlanId = String(planId).toLowerCase();
  const normalizedCycle = String(cycle).toLowerCase();
  const plan = BILLING_PLANS[normalizedPlanId];

  if (!plan) {
    return false;
  }

  return Boolean(plan.prices[normalizedCycle]);
};

const getPlanPricing = (planId, cycle) => {
  if (!isSupportedPlanSelection(planId, cycle)) {
    return null;
  }

  return BILLING_PLANS[String(planId).toLowerCase()].prices[String(cycle).toLowerCase()];
};

const buildYookassaAuthHeader = () => {
  const credentials = Buffer.from(`${YOOKASSA_SHOP_ID}:${YOOKASSA_API_KEY}`).toString('base64');
  return `Basic ${credentials}`;
};

const getPlanLabel = (planValue) => {
  if (!planValue) {
    return '';
  }

  const key = String(planValue);
  if (PLAN_LABELS[key]) {
    return PLAN_LABELS[key];
  }

  return key
    .split(/[_\s-]+/)
    .filter(Boolean)
    .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
    .join(' ');
};

const persistUserPlan = (userId, planValue) =>
  new Promise((resolve, reject) => {
    if (!userId) {
      return reject(new Error('User id is required to update plan'));
    }

    const baseTokens = getTokensForPlan(planValue);
    const baseTokenUnits = toTokenUnits(baseTokens);
    const hasConfiguredPlan = hasPlanTokenConfig(planValue);
    const updateSql = baseTokenUnits > 0
      ? 'UPDATE users SET plan = ?, token_balance = ? WHERE id = ?'
      : 'UPDATE users SET plan = ? WHERE id = ?';
    const params = baseTokenUnits > 0
      ? [planValue, fromTokenUnits(baseTokenUnits), userId]
      : [planValue, userId];

    db.run(updateSql, params, (err) => {
      if (err) {
        return reject(err);
      }

      if (!hasConfiguredPlan && planValue) {
        console.warn('No token configuration found for plan', { userId, plan: planValue });
      }

      return resolve({
        tokenBalance: baseTokenUnits > 0 ? fromTokenUnits(baseTokenUnits) : null,
      });
    });
  });

const loadUserById = (userId) =>
  new Promise((resolve, reject) => {
    db.get('SELECT id, email, token, plan, referral, created_at, token_balance FROM users WHERE id = ?', [userId], (err, row) => {
      if (err) {
        return reject(err);
      }
      if (!row) {
        return resolve(null);
      }

      return resolve({
        ...row,
        token_balance: normalizeTokenValue(row.token_balance),
      });
    });
  });

class InsufficientTokensError extends Error {
  constructor(tokenBalance) {
    super('Insufficient tokens');
    this.name = 'InsufficientTokensError';
    this.tokenBalance = tokenBalance;
  }
}

const getUserTokenBalance = (userId) =>
  new Promise((resolve, reject) => {
    if (!userId) {
      return reject(new Error('User id is required to load token balance'));
    }

    db.get('SELECT token_balance FROM users WHERE id = ?', [userId], (err, row) => {
      if (err) {
        return reject(err);
      }
      if (!row) {
        return reject(new Error('User not found'));
      }
      return resolve(normalizeTokenValue(row.token_balance));
    });
  });

const debitUserTokens = (userId, amount) =>
  new Promise((resolve, reject) => {
    if (!userId) {
      return reject(new Error('User id is required to debit tokens'));
    }

    const parsedAmount = Number(amount);
    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      return reject(new Error('Amount must be a positive number'));
    }

    const debitUnits = toTokenUnits(parsedAmount);
    if (debitUnits <= 0) {
      return reject(new Error('Amount must be a positive number'));
    }

    db.serialize(() => {
      db.run('BEGIN IMMEDIATE TRANSACTION', (beginErr) => {
        if (beginErr) {
          return reject(beginErr);
        }

        db.get('SELECT token_balance FROM users WHERE id = ?', [userId], (selectErr, row) => {
          if (selectErr) {
            return db.run('ROLLBACK', (rollbackErr) => {
              if (rollbackErr) {
                console.error('Failed to rollback transaction after select error', rollbackErr);
              }
              return reject(selectErr);
            });
          }

          if (!row) {
            return db.run('ROLLBACK', (rollbackErr) => {
              if (rollbackErr) {
                console.error('Failed to rollback transaction after missing user', rollbackErr);
              }
              return reject(new Error('User not found'));
            });
          }

          const currentBalanceUnits = toTokenUnits(row.token_balance);
          if (currentBalanceUnits < debitUnits) {
            return db.run('ROLLBACK', (rollbackErr) => {
              if (rollbackErr) {
                console.error('Failed to rollback transaction after insufficient tokens', rollbackErr);
              }
              return reject(new InsufficientTokensError(fromTokenUnits(currentBalanceUnits)));
            });
          }

          const newBalanceUnits = currentBalanceUnits - debitUnits;
          const newBalance = fromTokenUnits(newBalanceUnits);
          db.run(
            'UPDATE users SET token_balance = ? WHERE id = ?',
            [newBalance, userId],
            (updateErr) => {
              if (updateErr) {
                return db.run('ROLLBACK', (rollbackErr) => {
                  if (rollbackErr) {
                    console.error('Failed to rollback transaction after update error', rollbackErr);
                  }
                  return reject(updateErr);
                });
              }

              db.run('COMMIT', (commitErr) => {
                if (commitErr) {
                  return db.run('ROLLBACK', (rollbackErr) => {
                    if (rollbackErr) {
                      console.error('Failed to rollback transaction after commit error', rollbackErr);
                    }
                    return reject(commitErr);
                  });
                }

                return resolve({ token_balance: newBalance });
              });
            }
          );
        });
      });
    });
  });

const isValidYookassaWebhookAuth = (authorizationHeader) => {
  if (!authorizationHeader || typeof authorizationHeader !== 'string') {
    return false;
  }

  if (!authorizationHeader.startsWith('Basic ')) {
    return false;
  }

  try {
    const decoded = Buffer.from(authorizationHeader.slice(6), 'base64').toString('utf8');
    return decoded === `${YOOKASSA_SHOP_ID}:${YOOKASSA_API_KEY}`;
  } catch (err) {
    return false;
  }
};

const createYookassaPayment = async ({ planId, cycle, userId, returnUrl }) => {
  const pricing = getPlanPricing(planId, cycle);
  if (!pricing) {
    throw new Error('Unsupported plan or billing cycle');
  }

  const idempotenceKey = crypto.randomUUID();

  const body = {
    amount: pricing.amount, // { value: '...', currency: 'RUB' } — как у тебя в getPlanPricing
    capture: true,
    confirmation: {
      type: 'redirect',
      return_url: returnUrl,
    },
    description: pricing.description,
    metadata: {
      user_id: String(userId),
      plan: String(planId).toLowerCase(),
      cycle: String(cycle).toLowerCase(),
    },
  };

  const response = await fetch(`${YOOKASSA_API_BASE}/payments`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Idempotence-Key': idempotenceKey,
      Authorization: buildYookassaAuthHeader(),
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errorBody = await response.text();

    console.error(
      '[YooKassa] Failed to create payment',
      {
        status: response.status,
        body: errorBody,
        requestBody: body,
      }
    );

    const error = new Error('Failed to create YooKassa payment');
    error.status = response.status;
    error.details = errorBody;
    throw error;
  }

  return await response.json();
};


const fetchYookassaPayment = async (paymentId) => {
  const response = await fetch(`${YOOKASSA_API_BASE}/payments/${paymentId}`, {
    headers: {
      Authorization: buildYookassaAuthHeader(),
    },
  });

  if (!response.ok) {
    const error = new Error('Failed to fetch YooKassa payment');
    error.status = response.status;
    error.details = await response.text();
    throw error;
  }

  return response.json();
};

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '..', 'views'));
app.set('trust proxy', 1);

app.use(
  helmet({
    contentSecurityPolicy: {
      useDefaults: true,
      directives: {
        "img-src": [
          "'self'",
          "data:",
          "https://images.unsplash.com",
        ],
        "script-src": ["'self'"],
        "style-src": [
          "'self'",
          "'unsafe-inline'",
          "https://fonts.googleapis.com",
        ],
        "font-src": [
          "'self'",
          "https://fonts.gstatic.com",
          "data:",
        ],
        "form-action": [
          "'self'",
          "https://disciplaner.online",
          "https://app.disciplaner.online",
          "https://yookassa.ru",
          "https://yoomoney.ru",
          "https://checkout.yookassa.ru",
        ],
        "navigate-to": [
          "'self'",
          "ghostai:",
          "https://yookassa.ru",
          "https://yoomoney.ru",
          "https://checkout.yookassa.ru",
        ],
      },
    },
    crossOriginEmbedderPolicy: false,
  })
);


app.use(express.urlencoded({ extended: true }));
app.use(express.json());

const sessionCookie = {
  httpOnly: true,
  maxAge: 1000 * 60 * 60 * 24, // 1 day
  sameSite: 'lax',
};

const sessionCookieDomain = process.env.SESSION_COOKIE_DOMAIN;
if (sessionCookieDomain) {
  sessionCookie.domain = sessionCookieDomain;
}

if (process.env.NODE_ENV === 'production') {
  sessionCookie.secure = true;
}

app.use(
  session({
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    store: sessionStore,
    cookie: sessionCookie,
  })
);

app.use(express.static(path.join(__dirname, '..', 'public')));

app.use(async (req, res, next) => {
  if (!req.session?.user?.id) {
    return next();
  }

  const now = Date.now();
  const lastRefreshedAt = req.session.userPlanRefreshedAt || 0;
  if (now - lastRefreshedAt < PLAN_REFRESH_INTERVAL_MS) {
    return next();
  }

  try {
    const freshUser = await loadUserById(req.session.user.id);
    req.session.userPlanRefreshedAt = now;

    if (freshUser) {
      req.session.user = {
        id: freshUser.id,
        email: freshUser.email,
        token: freshUser.token,
        plan: freshUser.plan,
        referral: freshUser.referral,
        created_at: freshUser.created_at,
        token_balance: freshUser.token_balance,
      };
      res.locals.currentUser = req.session.user;
      res.locals.currentUserPlanLabel = getPlanLabel(freshUser.plan);
    }
  } catch (err) {
    console.error('Failed to refresh user plan from session', err);
  }

  return next();
});

app.use((req, res, next) => {
  res.locals.currentUser = req.session.user || null;
  res.locals.currentUserPlanLabel = req.session.user ? getPlanLabel(req.session.user.plan) : null;
  res.locals.flash = req.session.flash || null;
  delete req.session.flash;
  next();
});

app.use((req, res, next) => {
  if (typeof req.session.oauthRequest === 'undefined') {
    req.session.oauthRequest = null;
  }
  if (typeof req.session.oauthReturnTo === 'undefined') {
    req.session.oauthReturnTo = null;
  }
  next();
});

const DEFAULT_CLIENT_ID = 'ghostai-desktop';

const landingContent = {
  heroBenefits: [
    'Реал-тайм: транскрибация и подсказки без задержек',
    'Невидимый слой: поверх любых приложений и вкладок',
    'Пост-аналитика: итоги, тезисы, задачи, инсайты',
    'Архив: поиск по встречам, темам, людям',
    'Конфиденциальность: локальные фильтры, контроль источников',
  ],
  socialProof: [
    { value: '40–60%', description: 'Ускоряет подготовку к встречам', note: 'По данным ранних пользователей' },
    { value: '↓ утомление', description: 'Снижает утомление от разговоров', note: 'По данным ранних пользователей' },
    { value: '30–45 мин', description: 'Экономит на пост-разбор каждой сессии', note: 'По данным ранних пользователей' },
  ],
  features: [
    {
      title: 'Прослушивание системного звука',
      highlight: 'Слышит то, что слышите вы',
      description: 'софта, браузера, звонков и любых вкладок.',
    },
    {
      title: 'Микрофон и речевые подсказки',
      highlight: 'Понимает ваш голос',
      description: 'и шепчет релевантные фразы на лету.',
    },
    {
      title: 'Захват экрана',
      highlight: 'Видит контекст окна',
      description: 'и помогает решать задачи «с экрана».',
    },
    {
      title: 'Реал-тайм транскрибация',
      highlight: 'Текст беседы с тайм-кодами',
      description: 'и говорящими — сразу, без ожидания.',
    },
    {
      title: 'AI-подсказки и шаблоны ответов',
      highlight: 'Интервью, собеседования, продажи',
      description: '— уверенные формулировки в один клик.',
    },
    {
      title: 'Пост-анализ и архив встреч',
      highlight: 'Итоги, экшены, темы',
      description: 'поиск по людям и вопросам. Глубокий AI-разбор по запросу.',
    },
  ],
  workflowSteps: [
    {
      title: 'Подключите источники',
      description: 'Системный звук, микрофон, экран — один клик, и Ghost AI в курсе контекста.',
    },
    {
      title: 'В разговоре',
      description: 'Ghost AI транскрибирует и подсказывает в реальном времени прямо поверх вашего экрана.',
    },
    {
      title: 'После звонка',
      description: 'Авто-итоги, заметки, задачи и тайм-коды без ручной рутины.',
    },
    {
      title: 'В архиве',
      description: 'Умный поиск, темы, участники и AI-анализ по запросу.',
    },
  ],
  workflowHighlights: [
    {
      title: 'Прозрачный контроль',
      copy: 'Выбирайте, какие приложения слушать и что сохранять. Личные разговоры остаются личными.',
      accent: 'Гибкие фильтры позволяют отключить запись в один клик.',
    },
    {
      title: 'Эффект присутствия',
      copy: 'Подсказки появляются рядом с курсором и не перекрывают важный контент.',
      accent: 'Ключевые формулировки выделены крупным шрифтом, чтобы вы не искали их глазами.',
    },
    {
      title: 'Память, которой можно доверять',
      copy: 'После встречи доступен структурированный отчёт с задачами и цитатами.',
      accent: 'Экспортируйте его в CRM или отправьте в командный чат за секунды.',
    },
  ],
  useCases: [
    {
      title: 'Собеседования',
      description: 'Вопросы, проверочные сценарии, оценка ответов.',
      headline: 'Нанимайте уверенно',
      summary:
        'Фиксируйте ключевые ответы кандидатов, подстраивайте вопросы под диалог и получайте готовый отчёт для Hiring Manager.',
      bullets: [
        'Сценарии для HR, технических и культурных интервью',
        'Автоматическое выделение сильных и слабых сторон',
        'Отправка отчёта в ATS или командный чат',
      ],
      cta: 'Собрать интервью',
    },
    {
      title: 'Продажи/CS',
      description: 'Обработка возражений, next steps, CRM-конспект.',
      headline: 'Закрывайте сделки быстрее',
      summary:
        'Ghost AI фиксирует боли клиента, помнит договорённости и подсказывает, что предложить дальше — без переключения вкладок.',
      bullets: [
        'Темплейты ответов на возражения и FAQ',
        'Подбор action items и сроков по каждой встрече',
        'Экспорт заметок в CRM за секунду',
      ],
      cta: 'Усилить продажи',
    },
    {
      title: 'Исследования/UX',
      description: 'Маркировка инсайтов, темы и цитаты.',
      headline: 'Глубокие инсайты без ручной расшифровки',
      summary:
        'Помечайте инсайты во время интервью, сортируйте по темам и делитесь выдержками с дизайнерами и разработчиками.',
      bullets: [
        'Метки сегментов, гипотез и неожиданных находок',
        'Цитаты участников с тайм-кодами',
        'Экспорт в Miro, Notion или презентацию',
      ],
      cta: 'Систематизировать инсайты',
    },
    {
      title: 'Лекции/курсы',
      description: 'Шпаргалки, термины, конспекты, тайм-коды.',
      headline: 'Учите и обучайтесь осознанно',
      summary:
        'Создавайте структурированные конспекты, выделяйте ключевые определения и делитесь материалами со студентами.',
      bullets: [
        'Автономные заметки для каждого занятия',
        'Быстрые шпаргалки и карточки терминов',
        'Подготовка к экзаменам и контрольным',
      ],
      cta: 'Оцифровать лекцию',
    },
    {
      title: 'Командные созвоны',
      description: 'Роли, action items, follow-ups.',
      headline: 'Синхронизируйте команду',
      summary:
        'Собирайте решение, ответственных и дедлайны в одном документе. Команда получает follow-up сразу после звонка.',
      bullets: [
        'Назначение ответственных по каждому решению',
        'Трекер задач с дедлайнами',
        'Автоматическое напоминание в Slack или почте',
      ],
      cta: 'Систематизировать созвон',
    },
    {
      title: 'Техподдержка',
      description: 'Пошаговые инструкции и автосаммари.',
      headline: 'Помогайте клиентам без задержек',
      summary:
        'Подсказки с готовыми ответами и ссылки на базы знаний позволяют закрывать тикеты быстрее.',
      bullets: [
        'Шаблоны ответов для разных каналов',
        'История обращений и контекст клиента',
        'Экспорт отчёта по тикету',
      ],
      cta: 'Ускорить поддержку',
    },
  ],
  testimonials: [
    {
      quote:
        'Ghost AI стал вторым мозгом на собеседованиях. Подсказки с примерными ответами и тайм-коды экономят часы подготовки.',
      name: 'Анна Морозова',
      role: 'Head of Operations, Nimbly',
      metric: '-47% времени на разбор звонков',
    },
    {
      quote:
        'Команде продаж стало легче вести диалоги: Ghost AI подсказывает, когда углубиться в боли клиента и что записать в CRM.',
      name: 'Вадим Сафронов',
      role: 'Product Lead, Quantum',
      metric: '+32% закрытых задач в спринте',
    },
    {
      quote:
        'Лекции перестали теряться. Через пару минут после созвона есть транскрипт, конспект и подборка инсайтов для студентов.',
      name: 'Мария Крылова',
      role: 'Founder, iTeach',
      metric: 'NPS 73 вместо 41',
    },
  ],
  plans: [
    {
      name: 'Starter',
      description: 'Личные встречи, базовые подсказки и транскрибация',
      monthly: { price: '29', suffix: '$/мес' },
      yearly: { price: '24', suffix: '$/мес при оплате за год' },
      benefits: [
        'До 30 часов транскрибации в месяц',
        'Личные подсказки и заметки',
        'Экспорт в Markdown и PDF',
        'История встреч за 3 месяца',
        'Локальные фильтры конфиденциальности',
      ],
      highlighted: false,
    },
    {
      name: 'Pro',
      description: 'Реал-тайм подсказки+, пост-аналитика, расширенный архив',
      monthly: { price: '59', suffix: '$/мес' },
      yearly: { price: '49', suffix: '$/мес при оплате за год' },
      benefits: [
        'Неограниченные часы распознавания',
        'Глубокая пост-аналитика и темы',
        'Готовые шаблоны ответов',
        'Расширенный архив и поиск по людям',
        'Интеграции Slack/Notion',
        'Экспорт итогов в CRM',
      ],
      highlighted: true,
    },
    {
      name: 'Team',
      description: 'Совместный доступ, общие коллекции, роли и безопасность',
      monthly: { price: '89', suffix: '$/место/мес' },
      yearly: { price: '75', suffix: '$/место/мес при оплате за год' },
      benefits: [
        'Общие коллекции и роли',
        'SAML SSO и контроль доступа',
        'Голосовые подсказки под команды',
        'Общий архив и разрешения',
        'Приоритетная поддержка 24/7',
        'Собственный лимит хранения',
      ],
      highlighted: false,
    },
  ],
  faq: [
    {
      question: 'Как Ghost AI работает поверх любых приложений?',
      answer:
        'Ghost AI — это лёгкий оверлей, который закрепляется поверх окон и вкладок. Он слушает системный звук, микрофон и считывает активное окно, не вмешиваясь в само приложение.',
    },
    {
      question: 'Какие данные обрабатываются локально, а какие — в облаке?',
      answer:
        'Вы контролируете источники. Часть фильтрации и распознавания проходит локально, а для глубокого анализа используется зашифрованная обработка в облаке. Чувствительные фрагменты можно исключать.',
    },
    {
      question: 'Поддерживается ли мой язык?',
      answer:
        'Ghost AI работает с десятками языков, включая русский и английский. Для редких языков доступны fallback-модели и возможность обучить словари.',
    },
    {
      question: 'Можно ли отключить экран/звук и оставить только микрофон?',
      answer: 'Да. В настройках можно быстро выключить любой канал — Ghost AI продолжит слушать только выбранный источник.',
    },
    {
      question: 'Как экспортировать заметки и итоги встречи?',
      answer:
        'Итоги можно выгрузить в Markdown, PDF или напрямую отправить в Notion, Slack, CRM. Также доступен API для собственных интеграций.',
    },
    {
      question: 'Чем планы Pro и Team отличаются от Starter?',
      answer:
        'Starter рассчитан на личное использование. Pro добавляет пост-аналитику, шаблоны и расширенный архив. Team расширяет совместную работу: роли, коллекции, безопасность, приоритетную поддержку.',
    },
  ],
  ctaPoints: [
    'Видите подсказки и заметки прямо на экране',
    'Получаете итоги и задачи сразу после звонка',
    'Делитесь конспектом с командой в два клика',
  ],
};

const normalizeOAuthQuery = (query = {}) => {
  if (!query.client_id || !query.redirect_uri || !query.code_challenge) {
    return null;
  }

  return {
    clientId: query.client_id,
    redirectUri: query.redirect_uri,
    state: query.state || null,
    codeChallenge: query.code_challenge,
    codeChallengeMethod: query.code_challenge_method || 'S256',
  };
};

const canonicalizeAuthorizePath = (value) => {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed.startsWith('/oauth/authorize')) {
    return null;
  }

  try {
    const parsed = new URL(trimmed, 'http://localhost');
    if (parsed.origin !== 'http://localhost') {
      return null;
    }

    if (!parsed.pathname.startsWith('/oauth/authorize')) {
      return null;
    }

    const normalizedSearch = parsed.search || '';
    return `${parsed.pathname}${normalizedSearch}`;
  } catch (err) {
    return null;
  }
};

const rememberAuthorizePath = (req, authorizePath) => {
  const canonical = canonicalizeAuthorizePath(authorizePath);
  if (canonical) {
    req.session.oauthReturnTo = canonical;
  } else {
    req.session.oauthReturnTo = null;
  }
};

const pickAuthorizePath = (candidateFromQuery, candidateFromSession) => {
  const canonicalFromQuery = canonicalizeAuthorizePath(candidateFromQuery);
  if (canonicalFromQuery) {
    return canonicalFromQuery;
  }

  const canonicalFromSession = canonicalizeAuthorizePath(candidateFromSession);
  if (canonicalFromSession) {
    return canonicalFromSession;
  }

  return null;
};

const buildOAuthSuccessPayload = ({ redirectUri, code, state }) => {
  const separator = redirectUri.includes('?') ? '&' : '?';
  const redirectUrl = `${redirectUri}${separator}code=${encodeURIComponent(code)}${
    state ? `&state=${encodeURIComponent(state)}` : ''
  }`;

  return { redirectUrl };
};

const finalizeOAuthIfNeeded = async (req, user) => {
  const pending = req.session.oauthRequest;
  if (!pending) {
    return null;
  }

  const client = oauth.getClient(pending.clientId);
  if (!client || !oauth.validateRedirectUri(client, pending.redirectUri)) {
    req.session.oauthRequest = null;
    return null;
  }

  try {
    const { code } = await oauth.createAuthorizationCode({
      userId: user.id,
      clientId: pending.clientId,
      redirectUri: pending.redirectUri,
      codeChallenge: pending.codeChallenge,
      codeChallengeMethod: pending.codeChallengeMethod,
      state: pending.state,
    });

    req.session.oauthRequest = null;
    req.session.oauthReturnTo = null;

    return buildOAuthSuccessPayload({
      redirectUri: pending.redirectUri,
      code,
      state: pending.state,
    });
  } catch (err) {
    console.error('Error creating authorization code', err);
    req.session.oauthRequest = null;
    req.session.oauthReturnTo = null;
    throw err;
  }
};

const requireAuth = (req, res, next) => {
  if (!req.session.user) {
    req.session.flash = { type: 'error', message: 'Пожалуйста, войдите в аккаунт.' };
    return res.redirect('/login');
  }
  return next();
};

app.post('/api/billing/checkout', requireAuth, async (req, res) => {
  // 1. Проверяем, вообще настроен ли биллинг
  if (!isBillingConfigured()) {
    return res.status(503).json({ error: 'billing_not_configured' });
  }

  // 2. Достаём план и цикл из тела запроса
  const { plan, cycle } = req.body || {};
  const normalizedCycle = cycle === 'annual' ? 'annual' : 'monthly';

  if (!isSupportedPlanSelection(plan, normalizedCycle)) {
    return res.status(400).json({ error: 'invalid_plan_selection' });
  }

  // 3. Формируем returnUrl
  const baseUrl = BILLING_RETURN_BASE_URL
    ? BILLING_RETURN_BASE_URL.replace(/\/$/, '')
    : `${req.protocol}://${req.get('host')}`;
  const returnUrl = `${baseUrl}/billing/return`;

  try {
    // 4. Создаём платёж в YooKassa
    const payment = await createYookassaPayment({
      planId: plan,
      cycle: normalizedCycle,
      userId: req.session.user.id,
      returnUrl,
    });

    const confirmationUrl = payment?.confirmation?.confirmation_url;
    if (!confirmationUrl) {
      console.error('YooKassa response missing confirmation URL', payment);
      return res.status(502).json({ error: 'missing_confirmation_url' });
    }

    // 5. Сохраняем последний платеж в сессию — пригодится в /billing/return
    req.session.lastYookassaPayment = {
      id: payment.id,
      plan: String(plan),
      cycle: normalizedCycle,
      createdAt: Date.now(),
    };

    // 6. Отдаём фронту URL для редиректа
    return res.json({
      confirmationUrl,
      paymentId: payment.id,
    });
  } catch (err) {
    console.error('Failed to create YooKassa payment', {
      message: err.message,
      status: err.status,
      details: err.details,
    });
    return res.status(502).json({ error: 'payment_creation_failed' });
  }
});


app.get('/billing/return', requireAuth, async (req, res) => {
  // 1. Проверяем, вообще настроен ли биллинг
  if (!isBillingConfigured()) {
    req.session.flash = {
      type: 'error',
      message: 'Оплата временно недоступна. Попробуйте позже.',
    };
    return res.redirect('/dashboard');
  }

  // 2. Пытаемся достать paymentId:
  //    сначала из query (payment_id/paymentId),
  //    потом из сессии (куда мы его положили при создании платежа)
  let paymentId = req.query.payment_id || req.query.paymentId;
  const lastPayment = req.session.lastYookassaPayment;

  if (!paymentId && lastPayment && lastPayment.id) {
    paymentId = lastPayment.id;
  }

  if (!paymentId) {
    req.session.flash = {
      type: 'error',
      message: 'Не удалось определить платеж YooKassa.',
    };
    return res.redirect('/dashboard');
  }

  try {
    const payment = await fetchYookassaPayment(paymentId);

    if (!payment || payment.status !== 'succeeded') {
      req.session.flash = {
        type: 'error',
        message: 'Платеж не был завершен.',
      };
      return res.redirect('/dashboard');
    }

    const metadata = payment.metadata || {};
    const planId = metadata.plan;
    const cycle = metadata.cycle;
    const userId = metadata.user_id ? Number(metadata.user_id) : null;

    if (!userId || userId !== req.session.user.id || !isSupportedPlanSelection(planId, cycle)) {
      req.session.flash = {
        type: 'error',
        message: 'Не удалось применить тариф по платежу.',
      };
      return res.redirect('/dashboard');
    }

    const planValue = buildPlanValue(planId, cycle);
    const { tokenBalance: updatedTokenBalance } = await persistUserPlan(userId, planValue);

    // Обновляем сессию и locals, чтобы на /dashboard сразу был новый план
    req.session.user.plan = planValue;
    if (typeof updatedTokenBalance === 'number') {
      req.session.user.token_balance = updatedTokenBalance;
    }
    req.session.userPlanRefreshedAt = Date.now();
    res.locals.currentUser = req.session.user;
    res.locals.currentUserPlanLabel = getPlanLabel(planValue);

    // Можно почистить сохранённый платеж — он больше не нужен
    req.session.lastYookassaPayment = null;

    req.session.flash = {
      type: 'success',
      message: `Подписка «${getPlanLabel(planValue)}» активирована.`,
    };

    return res.redirect('/dashboard');
  } catch (err) {
    console.error('Failed to finalize YooKassa payment', err);

    req.session.flash = {
      type: 'error',
      message: 'Не удалось подтвердить оплату. Свяжитесь с поддержкой.',
    };
    return res.redirect('/dashboard');
  }
});


app.post('/webhooks/yookassa', async (req, res) => {
  if (!isBillingConfigured()) {
    return res.status(503).json({ error: 'billing_not_configured' });
  }

  if (!isValidYookassaWebhookAuth(req.get('authorization'))) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const event = req.body;
  if (!event || event.event !== 'payment.succeeded') {
    return res.status(200).json({ received: true });
  }

  const payment = event.object;
  if (!payment || payment.status !== 'succeeded') {
    return res.status(200).json({ received: true });
  }

  const metadata = payment.metadata || {};
  const planId = metadata.plan;
  const cycle = metadata.cycle;
  const userId = metadata.user_id ? Number(metadata.user_id) : null;

  if (!userId || !isSupportedPlanSelection(planId, cycle)) {
    return res.status(200).json({ received: true });
  }

  try {
    const planValue = buildPlanValue(planId, cycle);
    await persistUserPlan(userId, planValue);
    console.info('YooKassa webhook applied plan', {
      userId,
      planValue,
      paymentId: payment.id,
    });
    return res.status(200).json({ received: true });
  } catch (err) {
    console.error('Failed to persist plan from YooKassa webhook', err);
    return res.status(500).json({ error: 'plan_update_failed' });
  }
});

const buildGhostAiAuthHeader = (user) => {
  if (!user) {
    return null;
  }

  if (process.env.GHOSTAI_AUTH_MODE === 'user-token') {
    if (user.token) {
      return `Bearer ${user.token}`;
    }
    return null;
  }

  if (!user.id) {
    return null;
  }

  return `Bearer web-user-${user.id}`;
};

const respondUnauthorized = (res) => {
  res.set('WWW-Authenticate', 'Bearer error="invalid_token"');
  return res.status(401).json({ error: 'unauthorized' });
};

const formatAsIso8601 = (value) => {
  if (!value) {
    return null;
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  const str = String(value);
  const parsed = new Date(str);
  if (!Number.isNaN(parsed.getTime())) {
    return parsed.toISOString();
  }

  const match = str.match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?$/);
  if (match) {
    const [, year, month, day, hour, minute, second, fraction] = match;
    const fractional = fraction ? Number(`0.${fraction}`) : 0;
    const milliseconds = Math.round(fractional * 1000);
    const date = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), Number(second), milliseconds));
    if (!Number.isNaN(date.getTime())) {
      return date.toISOString();
    }
  }

  const normalized = str.includes('T') ? str : str.replace(' ', 'T');
  const withTimezone = /[zZ]$/.test(normalized) ? normalized : `${normalized}Z`;
  const normalizedDate = new Date(withTimezone);
  if (!Number.isNaN(normalizedDate.getTime())) {
    return normalizedDate.toISOString();
  }

  return null;
};

const formatDuration = (seconds) => {
  if (!seconds || Number.isNaN(seconds)) {
    return '—';
  }

  const totalSeconds = Math.max(0, Math.round(seconds));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const secs = totalSeconds % 60;

  const minutesPart = hours > 0 ? String(minutes).padStart(2, '0') : String(minutes);
  const secondsPart = String(secs).padStart(2, '0');

  return hours > 0 ? `${hours}:${minutesPart}:${secondsPart}` : `${minutes}:${secondsPart}`;
};

const formatFileSize = (bytes) => {
  if (!bytes || Number.isNaN(bytes)) {
    return '—';
  }

  const units = ['Б', 'КБ', 'МБ', 'ГБ'];
  let value = bytes;
  let unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }

  const formatter = new Intl.NumberFormat('ru-RU', {
    minimumFractionDigits: value < 10 && unitIndex > 0 ? 1 : 0,
    maximumFractionDigits: value < 10 && unitIndex > 0 ? 1 : 0,
  });

  return `${formatter.format(value)} ${units[unitIndex]}`;
};

const formatRecordingTitle = (recording) => {
  if (!recording || !recording.started_at) {
    return 'Запись';
  }

  const started = new Date(recording.started_at);
  const date = started.toLocaleDateString('ru-RU');
  const time = started.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
  return `Запись от ${date}, ${time}`;
};

app.get('/', (req, res) => {
  res.render('index', {
    title: 'Ghost AI — Невидимый AI-ассистент для разговоров',
    landing: landingContent,
  });
});

app.get('/oauth/client-config', (req, res) => {
  const requestedClientId = req.query.client_id || DEFAULT_CLIENT_ID;
  const clientConfig = oauth.getPublicClientConfig(requestedClientId);

  if (!clientConfig || !clientConfig.redirectUri) {
    return res.status(404).json({ error: 'invalid_client' });
  }

  return res.json({
    client_id: clientConfig.clientId,
    redirect_uri: clientConfig.redirectUri,
    scope: clientConfig.scope,
    prompt: clientConfig.prompt,
  });
});

app.get('/register', (req, res) => {
  const oauthRequest = normalizeOAuthQuery(req.query) || req.session.oauthRequest;
  if (oauthRequest) {
    req.session.oauthRequest = oauthRequest;
  }

  const oauthContinue = pickAuthorizePath(req.query.continue, req.session.oauthReturnTo);
  if (oauthContinue) {
    req.session.oauthReturnTo = oauthContinue;
  } else {
    req.session.oauthReturnTo = null;
  }

  res.render('register', { title: 'Регистрация', oauthRequest, oauthContinue });
});

app.post('/register', async (req, res) => {
  const { email, password, confirmPassword, referral } = req.body;

  const oauthFromBody = normalizeOAuthQuery({
    client_id: req.body.client_id,
    redirect_uri: req.body.redirect_uri,
    code_challenge: req.body.code_challenge,
    state: req.body.state,
    code_challenge_method: req.body.code_challenge_method,
  });
  if (oauthFromBody) {
    req.session.oauthRequest = oauthFromBody;
  }

  const oauthContinue = pickAuthorizePath(req.body.continue, req.session.oauthReturnTo);
  if (oauthContinue) {
    req.session.oauthReturnTo = oauthContinue;
  } else {
    req.session.oauthReturnTo = null;
  }

  if (!email || !password || !confirmPassword) {
    req.session.flash = { type: 'error', message: 'Заполните все обязательные поля.' };
    return res.redirect('/register');
  }

  if (password !== confirmPassword) {
    req.session.flash = { type: 'error', message: 'Пароли не совпадают.' };
    return res.redirect('/register');
  }

  if (password.length < 8) {
    req.session.flash = { type: 'error', message: 'Пароль должен быть не короче 8 символов.' };
    return res.redirect('/register');
  }

  db.get('SELECT id FROM users WHERE email = ?', [email.toLowerCase()], async (err, row) => {
    if (err) {
      console.error('Error checking user', err);
      req.session.flash = { type: 'error', message: 'Не удалось создать аккаунт. Попробуйте позже.' };
      return res.redirect('/register');
    }

    if (row) {
      req.session.flash = { type: 'error', message: 'Этот email уже зарегистрирован.' };
      return res.redirect('/register');
    }

    try {
      const passwordHash = await bcrypt.hash(password, 12);
      const token = nanoid();
      const planValue = 'free';
      const initialTokenUnits = toTokenUnits(getTokensForPlan(planValue));
      const initialTokenBalance = fromTokenUnits(initialTokenUnits);
      db.run(
        'INSERT INTO users (email, password_hash, token, plan, referral, token_balance) VALUES (?, ?, ?, ?, ?, ?)',
        [
          email.toLowerCase(),
          passwordHash,
          token,
          planValue,
          referral || null,
          initialTokenBalance,
        ],
        function (insertErr) {
          if (insertErr) {
            console.error('Error inserting user', insertErr);
            req.session.flash = { type: 'error', message: 'Не удалось создать аккаунт. Попробуйте позже.' };
            return res.redirect('/register');
          }

          req.session.user = {
            id: this.lastID,
            email: email.toLowerCase(),
            token,
            plan: planValue,
            referral: referral || null,
            token_balance: initialTokenBalance,
          };
          req.session.userPlanRefreshedAt = Date.now();
          req.session.flash = { type: 'success', message: 'Добро пожаловать в Ghost AI!' };

          if (oauthContinue) {
            req.session.oauthReturnTo = null;
            return res.redirect(oauthContinue);
          }

          return finalizeOAuthIfNeeded(req, req.session.user)
            .then((oauthSuccess) => {
              if (oauthSuccess && oauthSuccess.redirectUrl) {
                const statusMessage = req.session.flash ? req.session.flash.message : null;
                if (req.session.flash) {
                  req.session.flash = null;
                }

                return res.render('oauth-success', {
                  title: 'Авторизация завершена',
                  redirectUrl: oauthSuccess.redirectUrl,
                  statusMessage: statusMessage || 'Ваш аккаунт создан. Переключаемся в приложение Ghost AI.',
                  fallbackUrl: '/dashboard',
                });
              }
              return res.redirect('/dashboard');
            })
            .catch(() => {
              req.session.flash = { type: 'error', message: 'Не удалось завершить OAuth-аутентификацию.' };
              return res.redirect('/dashboard');
            });
        }
      );
    } catch (hashErr) {
      console.error('Error hashing password', hashErr);
      req.session.flash = { type: 'error', message: 'Не удалось создать аккаунт. Попробуйте позже.' };
      return res.redirect('/register');
    }
  });
});

app.get('/login', (req, res) => {
  const oauthRequest = normalizeOAuthQuery(req.query) || req.session.oauthRequest;
  if (oauthRequest) {
    req.session.oauthRequest = oauthRequest;
  }

  const oauthContinue = pickAuthorizePath(req.query.continue, req.session.oauthReturnTo);
  if (oauthContinue) {
    req.session.oauthReturnTo = oauthContinue;
  } else {
    req.session.oauthReturnTo = null;
  }

  res.render('login', { title: 'Вход', oauthRequest, oauthContinue });
});

app.post('/login', (req, res) => {
  const { email, password } = req.body;

  const oauthFromBody = normalizeOAuthQuery({
    client_id: req.body.client_id,
    redirect_uri: req.body.redirect_uri,
    code_challenge: req.body.code_challenge,
    state: req.body.state,
    code_challenge_method: req.body.code_challenge_method,
  });
  if (oauthFromBody) {
    req.session.oauthRequest = oauthFromBody;
  }

  const oauthContinue = pickAuthorizePath(req.body.continue, req.session.oauthReturnTo);
  if (oauthContinue) {
    req.session.oauthReturnTo = oauthContinue;
  } else {
    req.session.oauthReturnTo = null;
  }

  if (!email || !password) {
    req.session.flash = { type: 'error', message: 'Введите email и пароль.' };
    return res.redirect('/login');
  }

  db.get('SELECT * FROM users WHERE email = ?', [email.toLowerCase()], async (err, user) => {
    if (err) {
      console.error('Error fetching user', err);
      req.session.flash = { type: 'error', message: 'Не удалось войти. Попробуйте позже.' };
      return res.redirect('/login');
    }

    if (!user) {
      req.session.flash = { type: 'error', message: 'Неверный email или пароль.' };
      return res.redirect('/login');
    }

    const passwordMatches = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatches) {
      req.session.flash = { type: 'error', message: 'Неверный email или пароль.' };
      return res.redirect('/login');
    }

    req.session.user = {
      id: user.id,
      email: user.email,
      token: user.token,
      plan: user.plan,
      referral: user.referral,
      created_at: user.created_at,
      token_balance: normalizeTokenValue(user.token_balance),
    };
    req.session.userPlanRefreshedAt = Date.now();
    req.session.flash = { type: 'success', message: 'С возвращением!' };

    if (oauthContinue) {
      req.session.oauthReturnTo = null;
      return res.redirect(oauthContinue);
    }

    return finalizeOAuthIfNeeded(req, req.session.user)
      .then((oauthSuccess) => {
        if (oauthSuccess && oauthSuccess.redirectUrl) {
          const statusMessage = req.session.flash ? req.session.flash.message : null;
          if (req.session.flash) {
            req.session.flash = null;
          }

          return res.render('oauth-success', {
            title: 'Авторизация завершена',
            redirectUrl: oauthSuccess.redirectUrl,
            statusMessage: statusMessage || 'С возвращением! Переключаемся в приложение Ghost AI.',
            fallbackUrl: '/dashboard',
          });
        }
        return res.redirect('/dashboard');
      })
      .catch(() => {
        req.session.flash = { type: 'error', message: 'Не удалось завершить OAuth-аутентификацию.' };
        return res.redirect('/dashboard');
      });
  });
});

app.post('/logout', (req, res) => {
  req.session.destroy(() => {
    res.redirect('/');
  });
});

app.get('/dashboard', requireAuth, async (req, res, next) => {
  try {
    const freshUser = await loadUserById(req.session.user.id);
    if (freshUser) {
      req.session.user = {
        id: freshUser.id,
        email: freshUser.email,
        token: freshUser.token,
        plan: freshUser.plan,
        referral: freshUser.referral,
        created_at: freshUser.created_at,
        token_balance: freshUser.token_balance,
      };
      res.locals.currentUser = req.session.user;
      res.locals.currentUserPlanLabel = getPlanLabel(freshUser.plan);
    }
  } catch (err) {
    console.error('Failed to refresh user data before dashboard render', err);
    return next(err);
  }

  return res.render('dashboard', {
    title: 'Личный кабинет',
    user: req.session.user,
    planLabel: getPlanLabel(req.session.user?.plan),
  });
});

app.get('/recordings', requireAuth, (req, res) => {
  res.render('recordings/index', {
    title: 'Мои записи',
  });
});

const toFiniteNumber = (value) => {
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
};

const normalizeRecordingFromApi = (payload) => {
  if (!payload || typeof payload !== 'object') {
    return null;
  }

  const id = payload.id ? String(payload.id) : null;
  if (!id) {
    return null;
  }

  const startedAt = payload.started_at || payload.startedAt || null;
  const endedAt = payload.ended_at || payload.endedAt || null;

  const durationSources = [
    payload.duration_s,
    payload.duration_seconds,
    payload.duration,
    payload.duration_sec,
    payload.duration_ms,
    payload.durationMs,
  ];
  let durationSeconds;
  for (const candidate of durationSources) {
    if (candidate == null) {
      continue;
    }
    if (candidate === payload.duration_ms || candidate === payload.durationMs) {
      const millis = toFiniteNumber(candidate);
      if (typeof millis === 'number') {
        durationSeconds = Math.round(millis / 1000);
        break;
      }
    }
    const parsed = toFiniteNumber(candidate);
    if (typeof parsed === 'number') {
      durationSeconds = parsed;
      break;
    }
  }

  const sizeSources = [payload.size_bytes, payload.sizeBytes, payload.size, payload.file_size, payload.bytes];
  let sizeBytes;
  for (const candidate of sizeSources) {
    const parsed = toFiniteNumber(candidate);
    if (typeof parsed === 'number') {
      sizeBytes = parsed;
      break;
    }
  }

  const status = typeof payload.status === 'string' ? payload.status : 'uploaded';
  const contentType = payload.content_type || payload.contentType || null;

  return {
    id,
    started_at: startedAt || null,
    ended_at: endedAt || null,
    duration_s: typeof durationSeconds === 'number' ? durationSeconds : undefined,
    size_bytes: typeof sizeBytes === 'number' ? sizeBytes : undefined,
    status,
    content_type: contentType || undefined,
  };
};

app.get('/recordings/:id', requireAuth, async (req, res) => {
  const user = req.session.user;
  const recordingId = req.params.id;
  const apiUrl = `https://api.ghostai.ru/v1/recordings/${encodeURIComponent(recordingId)}?include_url=1`;
  const authHeader = `Bearer web-user-${user.id}`;
  const started = Date.now();

  try {
    const response = await fetch(apiUrl, {
      method: 'GET',
      headers: {
        Authorization: authHeader,
        Accept: 'application/json',
      },
    });

    const text = await response.text();
    console.log(
      '[recordings] show user=%s rec=%s status=%s in=%dms bodyLen=%d',
      user.id,
      recordingId,
      response.status,
      Date.now() - started,
      text.length,
    );

    if (response.status === 404) {
      return res.status(404).render('404', { title: 'Страница не найдена' });
    }

    if (!response.ok) {
      console.error(
        '[recordings][error] show user=%s rec=%s err=%s',
        user.id,
        recordingId,
        `Unexpected API status ${response.status}`,
      );
      return res.status(502).render('500', { title: 'Ошибка сервера' });
    }

    let payload;
    try {
      payload = text ? JSON.parse(text) : null;
    } catch (parseErr) {
      console.error('[recordings][error] show user=%s rec=%s err=%s', user.id, recordingId, parseErr);
      return res.status(502).render('500', { title: 'Ошибка сервера' });
    }

    const recording = normalizeRecordingFromApi(payload);
    if (!recording) {
      return res.status(404).render('404', { title: 'Страница не найдена' });
    }

    const playbackUrl =
      payload.download_url ||
      payload.playback_url ||
      payload.audio_url ||
      payload.url ||
      null;

    res.render('recordings/show', {
      title: formatRecordingTitle(recording),
      recording,
      playbackUrl,
      helpers: {
        formatDuration,
        formatFileSize,
        formatRecordingTitle,
      },
    });
  } catch (err) {
    console.error('[recordings][error] show user=%s rec=%s err=%s', user.id, recordingId, err);
    return res.status(502).render('500', { title: 'Ошибка сервера' });
  }
});

app.get('/oauth/authorize', async (req, res) => {
  const { response_type, client_id, redirect_uri, state, code_challenge, code_challenge_method } = req.query;

  if (response_type !== 'code') {
    return res.status(400).json({ error: 'unsupported_response_type' });
  }

  const client = oauth.getClient(client_id);
  if (!client || !oauth.validateRedirectUri(client, redirect_uri)) {
    return res.status(400).json({ error: 'invalid_client' });
  }

  if (!code_challenge || (code_challenge_method || 'S256') !== 'S256') {
    return res.status(400).json({ error: 'invalid_request', error_description: 'PKCE with S256 is required.' });
  }

  if (!req.session.user) {
    req.session.oauthRequest = {
      clientId: client_id,
      redirectUri: redirect_uri,
      state: state || null,
      codeChallenge: code_challenge,
      codeChallengeMethod: 'S256',
    };

    rememberAuthorizePath(req, req.originalUrl || null);

    const params = new URLSearchParams({
      client_id,
      redirect_uri,
      code_challenge,
      code_challenge_method: 'S256',
    });
    if (state) {
      params.append('state', state);
    }

    if (req.session.oauthReturnTo) {
      params.append('continue', req.session.oauthReturnTo);
    }

    return res.redirect(`/login?${params.toString()}`);
  }

  try {
    const { code } = await oauth.createAuthorizationCode({
      userId: req.session.user.id,
      clientId: client_id,
      redirectUri: redirect_uri,
      codeChallenge: code_challenge,
      codeChallengeMethod: 'S256',
      state: state || null,
    });

    req.session.oauthRequest = null;
    req.session.oauthReturnTo = null;

    const oauthSuccess = buildOAuthSuccessPayload({
      redirectUri: redirect_uri,
      code,
      state: state || null,
    });

    return res.render('oauth-success', {
      title: 'Авторизация завершена',
      redirectUrl: oauthSuccess.redirectUrl,
      statusMessage: 'Авторизация подтверждена. Переключаемся в приложение Ghost AI.',
      fallbackUrl: '/dashboard',
    });
  } catch (err) {
    console.error('Error issuing authorization code', err);
    return res.status(500).json({ error: 'server_error' });
  }
});

app.post('/oauth/token', async (req, res) => {
  const { grant_type, client_id } = req.body;
  const client = oauth.getClient(client_id);

  if (!client) {
    return res.status(400).json({ error: 'invalid_client' });
  }

  try {
    if (grant_type === 'authorization_code') {
      const { code, redirect_uri, code_verifier } = req.body;
      if (!code || !redirect_uri || !code_verifier) {
        return res.status(400).json({ error: 'invalid_request' });
      }

      const authCode = await oauth.consumeAuthorizationCode(code, client_id, redirect_uri);
      if (!authCode) {
        return res.status(400).json({ error: 'invalid_grant' });
      }

      if (authCode.code_challenge_method !== 'S256') {
        return res.status(400).json({ error: 'invalid_grant' });
      }

      const computedChallenge = crypto.createHash('sha256').update(code_verifier).digest('base64url');
      if (computedChallenge !== authCode.code_challenge) {
        return res.status(400).json({ error: 'invalid_grant', error_description: 'PKCE verification failed' });
      }

      const tokenPair = await oauth.createTokenPair({ userId: authCode.user_id, clientId: client_id });

      return res.json({
        access_token: tokenPair.accessToken,
        refresh_token: tokenPair.refreshToken,
        expires_in: oauth.ACCESS_TOKEN_TTL_SECONDS,
        token_type: 'bearer',
      });
    }

    if (grant_type === 'refresh_token') {
      const { refresh_token } = req.body;
      if (!refresh_token) {
        return res.status(400).json({ error: 'invalid_request' });
      }

      const tokenRow = await oauth.findTokenByRefreshToken(refresh_token, client_id);
      if (!tokenRow) {
        return res.status(400).json({ error: 'invalid_grant' });
      }

      await oauth.revokeByRefreshToken(refresh_token, client_id);
      const tokenPair = await oauth.createTokenPair({ userId: tokenRow.user_id, clientId: client_id });

      return res.json({
        access_token: tokenPair.accessToken,
        refresh_token: tokenPair.refreshToken,
        expires_in: oauth.ACCESS_TOKEN_TTL_SECONDS,
        token_type: 'bearer',
      });
    }

    return res.status(400).json({ error: 'unsupported_grant_type' });
  } catch (err) {
    console.error('OAuth token endpoint error', err);
    return res.status(500).json({ error: 'server_error' });
  }
});

app.post('/oauth/revoke', async (req, res) => {
  const { token, token_type_hint, client_id } = req.body;

  if (!token || !client_id) {
    return res.status(400).json({ error: 'invalid_request' });
  }

  const client = oauth.getClient(client_id);
  if (!client) {
    return res.status(400).json({ error: 'invalid_client' });
  }

  try {
    if (!token_type_hint || token_type_hint === 'refresh_token') {
      await oauth.revokeByRefreshToken(token, client_id);
    }
    return res.status(200).json({ revoked: true });
  } catch (err) {
    console.error('OAuth revoke endpoint error', err);
    return res.status(500).json({ error: 'server_error' });
  }
});

app.post('/internal/users/:id/tokens/debit', async (req, res) => {
  const providedSecret = req.get('X-Internal-Secret');
  if (!INTERNAL_API_SECRET || providedSecret !== INTERNAL_API_SECRET) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const userId = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(userId) || userId <= 0) {
    return res.status(400).json({ error: 'invalid_user_id' });
  }

  const { amount } = req.body || {};
  if (typeof amount === 'undefined') {
    return res.status(400).json({ error: 'invalid_amount', message: 'Amount is required' });
  }

  const amountNumber = Number(amount);
  if (!Number.isFinite(amountNumber) || amountNumber <= 0) {
    return res.status(400).json({ error: 'invalid_amount', message: 'Amount must be a positive number' });
  }

  const amountUnits = toTokenUnits(amountNumber);
  if (amountUnits <= 0) {
    return res.status(400).json({ error: 'invalid_amount', message: 'Amount is too small' });
  }

  const normalizedAmount = fromTokenUnits(amountUnits);

  try {
    const result = await debitUserTokens(userId, normalizedAmount);
    return res.status(200).json({ token_balance: result.token_balance });
  } catch (err) {
    if (err instanceof InsufficientTokensError) {
      return res.status(409).json({ error: 'insufficient_tokens', token_balance: err.tokenBalance });
    }
    if (err && err.message === 'User not found') {
      return res.status(404).json({ error: 'user_not_found' });
    }

    console.error('Failed to debit user tokens', {
      userId,
      amount: amountNumber,
      error: err,
    });

    return res.status(500).json({ error: 'internal_error' });
  }
});

// вверху файла не забудь:
// const db = require('./db');

app.get('/oauth/profile', async (req, res) => {
  const authHeader = req.headers.authorization || '';

  if (authHeader.startsWith('Bearer web-userid-')) {
    const rawUserId = authHeader.replace('Bearer web-userid-', '').trim();
    const userId = Number.parseInt(rawUserId, 10);

    if (!Number.isInteger(userId) || userId <= 0) {
      res.set('WWW-Authenticate', 'Bearer error="invalid_token"');
      return res.status(401).json({ error: 'invalid_token' });
    }

    try {
      const user = await loadUserById(userId);

      if (!user) {
        res.set('WWW-Authenticate', 'Bearer error="invalid_token"');
        return res.status(401).json({ error: 'invalid_token' });
      }

      const createdAt = formatAsIso8601(user.created_at);
      const tokenBalance = normalizeTokenValue(user.token_balance);

      return res.json({
        id: String(user.id),
        email: user.email,
        plan: user.plan,
        referral: user.referral,
        created_at: createdAt || null,
        token: user.token,
        token_balance: tokenBalance,
      });
    } catch (err) {
      console.error('Failed to load user for oauth profile', err);
      return res.status(500).json({ error: 'server_error' });
    }
  }

  // Ветка для внутренних web-user-* токенов
  if (authHeader.startsWith('Bearer web-user-')) {
    const userId = authHeader.replace('Bearer web-user-', '').trim();

    if (!userId) {
      return res.status(400).json({ error: 'invalid_token' });
    }

    return res.json({
      id: String(userId),
      email: null,
      plan: 'free',
      referral: null,
      created_at: new Date().toISOString(),
    });
  }

  // Дальше оставь как было у тебя:
  const tokenMatch = authHeader.match(/^Bearer\s+(\S+)$/i);

  if (!tokenMatch) {
    res.set('WWW-Authenticate', 'Bearer error="invalid_token"');
    return res.status(401).json({ error: 'invalid_token' });
  }

  try {
    const tokenRow = await oauth.getUserByAccessToken(tokenMatch[1]);
    if (!tokenRow) {
      res.set('WWW-Authenticate', 'Bearer error="invalid_token"');
      return res.status(401).json({ error: 'invalid_token' });
    }

    const createdAt = formatAsIso8601(tokenRow.created_at);

    return res.json({
      id: String(tokenRow.user_id),
      email: tokenRow.email,
      plan: tokenRow.plan,
      referral: tokenRow.referral,
      created_at: createdAt || null,
      token: tokenRow.user_token,
      token_balance: normalizeTokenValue(tokenRow.token_balance),
    });
  } catch (err) {
    console.error('OAuth profile endpoint error', err);
    return res.status(500).json({ error: 'server_error' });
  }
});



app.get('/api/recordings', async (req, res) => {
  const user = req.session.user;
  if (!user) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const cursor = typeof req.query.cursor === 'string' ? req.query.cursor : undefined;
  const url = new URL('https://api.ghostai.ru/v1/recordings');
  if (cursor) {
    url.searchParams.set('cursor', cursor);
  }

  const authHeader = `Bearer web-user-${user.id}`;
  const started = Date.now();

  try {
    const response = await fetch(url.toString(), {
      method: 'GET',
      headers: {
        Authorization: authHeader,
        Accept: 'application/json',
      },
    });

    const text = await response.text();
    console.log(
      '[recordings] list user=%s status=%s in=%dms bodyLen=%d',
      user.id,
      response.status,
      Date.now() - started,
      text.length,
    );

    if (!response.ok) {
      return res.status(502).json({ error: 'api_error', status: response.status });
    }

    return res.type('application/json').send(text);
  } catch (err) {
    console.error('[recordings][error] list user=%s err=%s', user.id, err);
    return res.status(502).json({ error: 'api_unavailable' });
  }
});

app.get('/api/recordings/:id', async (req, res) => {
  const user = req.session.user;
  if (!user) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const id = req.params.id;
  const apiUrl = `https://api.ghostai.ru/v1/recordings/${encodeURIComponent(id)}?include_url=1`;
  const authHeader = `Bearer web-user-${user.id}`;
  const started = Date.now();

  try {
    const response = await fetch(apiUrl, {
      method: 'GET',
      headers: {
        Authorization: authHeader,
        Accept: 'application/json',
      },
    });

    const text = await response.text();
    console.log(
      '[recordings] show user=%s rec=%s status=%s in=%dms bodyLen=%d',
      user.id,
      id,
      response.status,
      Date.now() - started,
      text.length,
    );

    if (!response.ok) {
      return res.status(502).json({ error: 'api_error', status: response.status });
    }

    return res.type('application/json').send(text);
  } catch (err) {
    console.error('[recordings][error] show user=%s rec=%s err=%s', user.id, id, err);
    return res.status(502).json({ error: 'api_unavailable' });
  }
});

app.get('/api/recordings/:id/transcript', requireAuth, async (req, res) => {
  const user = req.session.user;
  if (!user) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const recordingId = req.params.id;

  try {
    const result = await recordingsService.getTranscript(user.id, recordingId);
    return res.json(result);
  } catch (err) {
    if (err && err.message === 'Recording not found') {
      return res.status(404).json({ error: 'not_found' });
    }
    if (err && err.code === 'invalid_payload') {
      console.error('[recordings][error] transcript invalid-payload user=%s rec=%s', user.id, recordingId);
      return res.status(502).json({ error: 'invalid_transcript_payload' });
    }
    if (err && err.code === 'upstream_error') {
      console.error(
        '[recordings][error] transcript upstream user=%s rec=%s status=%s',
        user.id,
        recordingId,
        err.status,
      );
      return res.status(502).json({ error: 'api_error', status: err.status || null });
    }
    console.error('[recordings][error] transcript user=%s rec=%s err=%s', user.id, recordingId, err);
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.post('/api/recordings/:id/ask', async (req, res) => {
  const user = req.session.user;
  if (!user) {
    return respondUnauthorized(res);
  }

  const authHeader = buildGhostAiAuthHeader(user);
  if (!authHeader) {
    return respondUnauthorized(res);
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), ASK_TIMEOUT_MS);

  try {
    const upstream = await fetch(`${GHOSTAI_API_BASE}/v1/ask`, {
      method: 'POST',
      headers: {
        Authorization: authHeader,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        recording_id: req.params.id,
        question: req.body?.prompt,
        conversation_id: req.body?.conversation_id ?? null,
        mode: 'auto',
      }),
      signal: controller.signal,
    });

    if (upstream.status === 401) {
      res.set('WWW-Authenticate', 'Bearer error="invalid_token"');
    }

    res.status(upstream.status);

    const contentType = upstream.headers.get('content-type');
    if (contentType && !upstream.ok) {
      res.set('Content-Type', contentType);
    }

    if (!upstream.ok) {
      const body = await upstream.text();
      return res.send(body);
    }

    const payload = await upstream.json();
    return res.json(payload);
  } catch (err) {
    if (err && err.name === 'AbortError') {
      return res.status(504).json({ error: 'gateway_timeout' });
    }
    console.error('[recordings][ask][error] user=%s rec=%s err=%o', user?.id || 'unknown', req.params.id, err);
    return res.status(502).json({ error: 'bad_gateway' });
  } finally {
    clearTimeout(timeoutId);
  }
});

app.post('/api/recordings/:id/ask/stream', async (req, res) => {
  const user = req.session.user;
  if (!user) {
    return respondUnauthorized(res);
  }

  const authHeader = buildGhostAiAuthHeader(user);
  if (!authHeader) {
    return respondUnauthorized(res);
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), ASK_TIMEOUT_MS);

  const handleUnauthorized = (status) => {
    if (status === 401) {
      res.set('WWW-Authenticate', 'Bearer error="invalid_token"');
    }
  };

  try {
    const upstream = await fetch(`${GHOSTAI_API_BASE}/v1/ask/stream`, {
      method: 'POST',
      headers: {
        Authorization: authHeader,
        'Content-Type': 'application/json',
        Accept: 'text/event-stream',
      },
      body: JSON.stringify({
        recording_id: req.params.id,
        question: req.body?.prompt,
        conversation_id: req.body?.conversation_id ?? null,
        mode: 'auto',
      }),
      signal: controller.signal,
    });

    if (!upstream.ok || !upstream.body) {
      handleUnauthorized(upstream.status);
      res.status(upstream.status || 502);
      const contentType = upstream.headers.get('content-type');
      if (contentType) {
        res.set('Content-Type', contentType);
      }
      const text = await upstream.text();
      return res.send(text);
    }

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    if (typeof res.flushHeaders === 'function') {
      res.flushHeaders();
    }

    req.on('close', () => {
      controller.abort();
    });

    for await (const chunk of upstream.body) {
      res.write(chunk);
    }
    res.end();
  } catch (err) {
    if (err && err.name === 'AbortError') {
      if (!res.headersSent) {
        res.status(504).json({ error: 'gateway_timeout' });
      }
      return;
    }
    console.error('[recordings][ask_stream][error] user=%s rec=%s err=%o', user?.id || 'unknown', req.params.id, err);
    if (!res.headersSent) {
      res.status(502).json({ error: 'bad_gateway' });
    } else {
      res.end();
    }
  } finally {
    clearTimeout(timeoutId);
  }
});

app.use((req, res) => {
  res.status(404).render('404', { title: 'Страница не найдена' });
});

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).render('500', { title: 'Ошибка сервера' });
});

const server = app.listen(PORT, () => {
  console.log(`Ghost AI portal is running on http://localhost:${PORT}`);
});

const shutdownSignals = ['SIGTERM', 'SIGINT', 'SIGQUIT'];

const shutdown = async (signal) => {
  console.log(`Received ${signal}, shutting down gracefully...`);
  server.close(() => {
    console.log('HTTP server closed');
  });

  try {
    await shutdownSessionStore();
    console.log('Session store connection closed');
  } catch (err) {
    console.error('Error while closing session store', err);
  }
};

shutdownSignals.forEach((signal) => {
  process.on(signal, () => {
    shutdown(signal).catch((err) => {
      console.error('Unexpected error during shutdown', err);
      process.exitCode = 1;
    });
  });
});
