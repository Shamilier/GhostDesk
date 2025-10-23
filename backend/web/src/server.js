const path = require('path');
const express = require('express');
const session = require('express-session');
const helmet = require('helmet');
const bcrypt = require('bcrypt');
const { customAlphabet } = require('nanoid');

const db = require('./db');

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

const requireAuth = (req, res, next) => {
  if (!req.session.user) {
    req.session.flash = { type: 'error', message: 'Пожалуйста, войдите в аккаунт.' };
    return res.redirect('/login');
  }
  return next();
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

app.get('/register', (req, res) => {
  res.render('register', { title: 'Регистрация' });
});

app.post('/register', async (req, res) => {
  const { email, password, confirmPassword, referral } = req.body;

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
          return res.redirect('/dashboard');
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
  res.render('login', { title: 'Вход' });
});

app.post('/login', (req, res) => {
  const { email, password } = req.body;

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
    return res.redirect('/dashboard');
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
