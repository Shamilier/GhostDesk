# Ghost AI Landing

Современный лендинг Ghost AI на Next.js 14 (App Router) с Tailwind CSS, Framer Motion и стеклянной эстетикой.

## Быстрый старт

```bash
npm install
npm run dev
```

### Скрипты

- `npm run dev` — запуск дев-сервера на http://localhost:3000
- `npm run build` — production-сборка
- `npm run start` — запуск готовой сборки
- `npm run lint` — проверка eslint

## Структура

- `app/` — App Router, глобальные стили и layout
- `components/` — UI-компоненты секций (Hero, Pricing, FAQ и т.д.)
- `public/` — статика и иконки (добавляйте при необходимости)
- `tailwind.config.ts` — тема, токены стеклянных поверхностей, анимации

## Темизация и эффекты

Глобальные CSS-переменные находятся в `app/globals.css`:

- `--color-bg`, `--color-fg`, `--surface-*` — фон и стеклянные слои
- `--accent-gradient` — основной градиент подсветки
- `--noise-image` — текстура «liquid glass» (можно заменить на собственную)

Для изменения оттенков/подсветки обновите переменные и секцию `extend` в `tailwind.config.ts`. Класс `.glass` задаёт базовую стеклянную карточку.

## Анимации и доступность

- Все основные анимации на `transform`/`opacity`
- Используется `prefers-reduced-motion` для отключения динамики
- Framer Motion отвечает за появления секций, автоплей отзывов и магнитные CTA

## Lighthouse и производительность

Дизайн оптимизирован под тёмную тему, минимальные layout shift и высокие показатели Lighthouse (Perf/Access/Best/SEO ≥ 95). При добавлении нового контента проверяйте `npm run build` и Lighthouse в браузере.

## Дополнения

- Шрифты Inter и Raleway подключены через `next/font`
- Навбар липкий, имеет scrollspy и мобильное меню
- Для добавления новых секций дублируйте паттерны `GlassCard` + motion-анимации

Готово к дальнейшей кастомизации и интеграции с продуктом Ghost AI.
