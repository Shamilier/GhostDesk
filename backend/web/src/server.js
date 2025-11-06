require('ts-node/register/transpile-only');

const path = require('path');
const express = require('express');
const session = require('express-session');
const helmet = require('helmet');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { customAlphabet } = require('nanoid');

const recordingsService = require('./services/recordings');

const db = require('./db');
const oauth = require('./oauth');

const app = express();
const GHOSTAI_API_BASE = 'https://api.ghostai.ru';
const ASK_TIMEOUT_MS = 60_000;
const PORT = process.env.PORT || 3000;
const SESSION_SECRET = process.env.SESSION_SECRET || 'ghostai_super_secret';
const nanoid = customAlphabet('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz', 32);

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '..', 'views'));

app.use(
  helmet({
    contentSecurityPolicy: {
      useDefaults: true,
      directives: {
        "img-src": ["'self'", 'data:', 'https://images.unsplash.com'],
        "script-src": ["'self'"],
        "style-src": ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        "font-src": ["'self'", 'https://fonts.gstatic.com', 'data:'],
        "form-action": ["'self'", 'https://disciplaner.online', 'https://app.disciplaner.online'],
        "navigate-to": ["'self'", 'ghostai:'],
      },
    },
    crossOriginEmbedderPolicy: false,
  })
);

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.use(
  session({
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      maxAge: 1000 * 60 * 60 * 24, // 1 day
    },
  })
);

app.use(express.static(path.join(__dirname, '..', 'public')));

app.use((req, res, next) => {
  res.locals.currentUser = req.session.user || null;
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
    title: 'Ghost AI Portal',
    features: [
      'Мгновенное подключение к встречам и звонкам',
      'AI-подсказки и сценарии разговоров в реальном времени',
      'Автоматическая транскрибация и последующая аналитика',
    ],
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
      db.run(
        'INSERT INTO users (email, password_hash, token, plan, referral) VALUES (?, ?, ?, ?, ?)',
        [email.toLowerCase(), passwordHash, token, 'free', referral || null],
        function (insertErr) {
          if (insertErr) {
            console.error('Error inserting user', insertErr);
            req.session.flash = { type: 'error', message: 'Не удалось создать аккаунт. Попробуйте позже.' };
            return res.redirect('/register');
          }

          req.session.user = { id: this.lastID, email: email.toLowerCase(), token, plan: 'free', referral: referral || null };
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
    };
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

app.get('/dashboard', requireAuth, (req, res) => {
  res.render('dashboard', {
    title: 'Личный кабинет',
    user: req.session.user,
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

app.get('/oauth/profile', async (req, res) => {
  const auth = req.headers.authorization;
  if (auth && auth.startsWith('Bearer web-user-')) {
    const userId = auth.replace('Bearer web-user-', '').trim();
    if (!userId) {
      return res.status(400).json({ error: 'invalid_token' });
    }
    return res.json({
      id: userId,
      email: null,
      plan: 'free',
      referral: null,
      created_at: new Date().toISOString(),
    });
  }

  const authHeader = req.headers.authorization || '';
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

app.listen(PORT, () => {
  console.log(`Ghost AI portal is running on http://localhost:${PORT}`);
});
