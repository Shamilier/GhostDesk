const path = require('path');
const express = require('express');
const session = require('express-session');
const helmet = require('helmet');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { customAlphabet } = require('nanoid');

const db = require('./db');
const oauth = require('./oauth');

const app = express();
const PORT = process.env.PORT || 3000;
const SESSION_SECRET = process.env.SESSION_SECRET || 'ghostdesk_super_secret';
const nanoid = customAlphabet('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz', 32);

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '..', 'views'));

app.use(helmet({
  contentSecurityPolicy: {
    useDefaults: true,
    directives: {
      "img-src": ["'self'", 'data:', 'https://images.unsplash.com'],
      "script-src": ["'self'"],
      "style-src": ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
      "font-src": ["'self'", 'https://fonts.gstatic.com', 'data:'],
    },
  },
  crossOriginEmbedderPolicy: false,
}));

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

const DEFAULT_CLIENT_ID = 'ghostdesk-desktop';

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

const isSafeAuthorizePath = (value) => {
  if (typeof value !== 'string') {
    return false;
  }

  const trimmed = value.trim();
  if (!trimmed.startsWith('/oauth/authorize')) {
    return false;
  }

  if (trimmed.includes('://')) {
    return false;
  }

  return true;
};

const rememberAuthorizePath = (req, authorizePath) => {
  if (isSafeAuthorizePath(authorizePath)) {
    req.session.oauthReturnTo = authorizePath;
  } else {
    req.session.oauthReturnTo = null;
  }
};

const pickAuthorizePath = (candidateFromQuery, candidateFromSession) => {
  if (isSafeAuthorizePath(candidateFromQuery)) {
    return candidateFromQuery;
  }

  if (isSafeAuthorizePath(candidateFromSession)) {
    return candidateFromSession;
  }

  return null;
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

    const separator = pending.redirectUri.includes('?') ? '&' : '?';
    const redirectUrl = `${pending.redirectUri}${separator}code=${encodeURIComponent(
      code
    )}${pending.state ? `&state=${encodeURIComponent(pending.state)}` : ''}`;

    return redirectUrl;
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

app.get('/', (req, res) => {
  res.render('index', {
    title: 'GhostDesk Portal',
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
          req.session.flash = { type: 'success', message: 'Добро пожаловать в GhostDesk!' };

          if (oauthContinue) {
            req.session.oauthReturnTo = null;
            return res.redirect(oauthContinue);
          }

          return finalizeOAuthIfNeeded(req, req.session.user)
            .then((redirectUrl) => {
              if (redirectUrl) {
                return res.redirect(redirectUrl);
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
      .then((redirectUrl) => {
        if (redirectUrl) {
          return res.redirect(redirectUrl);
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

    const separator = redirect_uri.includes('?') ? '&' : '?';
    const redirectLocation = `${redirect_uri}${separator}code=${encodeURIComponent(code)}${
      state ? `&state=${encodeURIComponent(state)}` : ''
    }`;
    return res.redirect(redirectLocation);
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

app.use((req, res) => {
  res.status(404).render('404', { title: 'Страница не найдена' });
});

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).render('500', { title: 'Ошибка сервера' });
});

app.listen(PORT, () => {
  console.log(`GhostDesk portal is running on http://localhost:${PORT}`);
});
