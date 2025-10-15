"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import {
  ArrowRight,
  Check,
  CalendarCheck,
  LineChart,
  MessageCircle,
  PlayCircle,
  Shield,
  Sparkles,
  Wand2,
  Zap
} from "lucide-react";
import clsx from "clsx";

const navigation = [
  { label: "Возможности", href: "#features" },
  { label: "Платформа", href: "#platform" },
  { label: "Тарифы", href: "#pricing" },
  { label: "Ресурсы", href: "#faq" }
];

const heroHighlights = [
  "AI-конспекты за секунды",
  "Подсветка ключевых цитат",
  "Доступ к архиву с любого устройства"
];

const features = [
  {
    title: "История под контролем",
    description:
      "Соберите все звонки, лекции и демо в одном месте. Умные фильтры и теги помогут найти нужный эпизод за пару кликов.",
    icon: Sparkles,
    accent: "bg-primary-500/10 text-primary-200"
  },
  {
    title: "Инсайты без ручной рутины",
    description:
      "GhostDesk автоматически создаёт tl;dr, задачи и главы. Вам остаётся принять решение, а не конспектировать вручную.",
    icon: Wand2,
    accent: "bg-accent-500/10 text-accent-500"
  },
  {
    title: "Командный контекст",
    description:
      "Делитесь публичными ссылками с правами доступа, оставляйте заметки и отслеживайте, кто что посмотрел.",
    icon: MessageCircle,
    accent: "bg-emerald-500/10 text-emerald-400"
  },
  {
    title: "Безопасность и приватность",
    description:
      "Шифрование на уровне банка, токены с истечением срока и аудит действий. Доверяйте хранению самых чувствительных разговоров.",
    icon: Shield,
    accent: "bg-slate-500/10 text-slate-200"
  }
];

const workflow = [
  {
    title: "Запишите", 
    description:
      "Overlay-приложение для macOS фиксирует звонок, экран и заметки. К загрузке подключается всего одна кнопка.",
    icon: PlayCircle
  },
  {
    title: "Обработайте",
    description:
      "Алгоритмы преобразуют речь в текст, выделяют темы, action items и автоматически индексируют архив.",
    icon: Zap
  },
  {
    title: "Поделитесь",
    description:
      "Экспортируйте в Notion или Slack, отправьте ссылку гостю или пригласите коллег — всё управляется из одного окна.",
    icon: CalendarCheck
  }
];

const testimonials = [
  {
    name: "Анна Морозова",
    role: "Head of Operations, Nimbly",
    quote:
      "GhostDesk стал тем самым вторым мозгом для всей компании. Мы вдвое сократили время на онбординг и подготовку к встречам.",
    stat: "-47% времени на разбор звонков"
  },
  {
    name: "Вадим Сафронов",
    role: "Product Lead, Quantum",
    quote:
      "Мы перестали терять детали договорённостей. Теперь любой участник митинга может мгновенно найти нужный момент в транскрипте.",
    stat: "+32% закрытых задач в спринте"
  },
  {
    name: "Мария Крылова",
    role: "Founder, iTeach",
    quote:
      "Студенты получают резюме лекций через несколько минут. Это лучший маркетинговый актив: качество курсов стало очевидным.",
    stat: "NPS 73 вместо 41"
  }
];

const metrics = [
  { label: "команды доверяют GhostDesk", value: "120+" },
  { label: "экономия времени на конспектах", value: "6 ч/нед" },
  { label: "скорость генерации инсайтов", value: "< 90 сек" }
];

const pricing = [
  {
    name: "Starter",
    price: "$29",
    period: "в месяц",
    description: "Для индивидуальных специалистов и фрилансеров",
    highlights: [
      "Неограниченные записи и транскрипты",
      "Экспорт в Markdown и PDF",
      "Личные заметки и поиск по стенограммам",
      "Шеринг по защищённой ссылке"
    ],
    cta: "Начать бесплатно"
  },
  {
    name: "Team",
    price: "$79",
    period: "за рабочее место в месяц",
    description: "Для продуктовых и кросс-функциональных команд",
    highlights: [
      "Общие рабочие пространства и роли",
      "Интеграции Slack и Notion",
      "Action items с напоминаниями",
      "Аудит, контроль скачиваний и 2FA"
    ],
    cta: "Запросить демо",
    featured: true
  }
];

const faqs = [
  {
    question: "Можно ли попробовать перед оплатой?",
    answer:
      "Да, мы предоставляем 14 дней бесплатного доступа ко всем возможностям GhostDesk. После этого вы сможете выбрать подходящий тариф или продолжить с ограниченным бесплатным планом."
  },
  {
    question: "Нужна ли установка на Windows?",
    answer:
      "Web-приложение работает в браузере на любой ОС. Overlay-клиент сейчас доступен для macOS, версия для Windows находится в разработке."
  },
  {
    question: "Как обеспечивается безопасность данных?",
    answer:
      "Все медиа шифруются в S3, доступ выдаётся только по pre-signed ссылкам, мы поддерживаем контроль доступа по ролям и ведём журнал действий для соответствия требованиям безопасности."
  }
];

const fadeIn = {
  hidden: { opacity: 0, y: 40 },
  show: { opacity: 1, y: 0 }
};

export default function LandingPage() {
  return (
    <div className="relative overflow-hidden">
      <div className="blur-spot blur-spot--blue w-[420px] h-[420px] top-[-120px] left-[-80px]" />
      <div className="blur-spot blur-spot--violet w-[400px] h-[400px] top-[20%] right-[-160px]" />
      <div className="blur-spot blur-spot--cyan w-[360px] h-[360px] bottom-[-120px] left-[25%]" />

      <header className="relative z-10 px-6 md:px-12 lg:px-24 pt-12 pb-32 radial-bg">
        <nav className="flex items-center justify-between text-sm text-slate-300">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-full border border-white/20 bg-white/10 backdrop-blur">
              <span className="text-lg font-semibold text-white">Gd</span>
            </div>
            <span className="text-white font-medium tracking-wide">GhostDesk</span>
          </div>
          <div className="hidden md:flex items-center gap-8">
            {navigation.map((item) => (
              <a key={item.label} href={item.href} className="hover:text-white">
                {item.label}
              </a>
            ))}
          </div>
          <div className="flex items-center gap-4">
            <Link href="#pricing" className="hidden md:inline-flex text-slate-200 hover:text-white">
              Войти
            </Link>
            <Link
              href="#cta"
              className="inline-flex items-center gap-2 rounded-full bg-white/10 px-5 py-2 text-sm font-medium text-white shadow-glow transition hover:bg-white/20"
            >
              Забронировать демо
              <ArrowRight className="h-4 w-4" />
            </Link>
          </div>
        </nav>

        <div className="mt-24 grid gap-16 lg:grid-cols-[1.1fr_0.9fr] lg:items-center">
          <div>
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              className="inline-flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-4 py-2 text-xs uppercase tracking-[0.4em] text-primary-200"
            >
              GhostDesk 2.0 • Beta доступ
            </motion.div>

            <motion.h1
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.1 }}
              className="mt-8 text-5xl font-display tracking-tight text-white md:text-7xl"
            >
              Ваш второй мозг для каждой важной встречи
            </motion.h1>

            <motion.p
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.2 }}
              className="mt-6 max-w-xl text-lg text-slate-300 md:text-xl"
            >
              GhostDesk записывает, транскрибирует и превращает разговоры в действия. Больше никаких потерянных решений и
              бесконечных повторов.
            </motion.p>

            <motion.div
              initial="hidden"
              animate="show"
              variants={{ hidden: { opacity: 0 }, show: { opacity: 1, transition: { delayChildren: 0.3, staggerChildren: 0.12 } } }}
              className="mt-10 flex flex-wrap gap-4"
            >
              <Link
                href="#cta"
                className="inline-flex items-center gap-3 rounded-full bg-primary-500 px-6 py-3 text-sm font-semibold text-white shadow-glow transition hover:bg-primary-400"
              >
                Попробовать с командой
                <ArrowRight className="h-4 w-4" />
              </Link>
              <Link
                href="#features"
                className="inline-flex items-center gap-3 rounded-full border border-white/15 bg-white/5 px-6 py-3 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/10"
              >
                Смотреть в действии
                <PlayCircle className="h-5 w-5" />
              </Link>
            </motion.div>

            <motion.ul
              initial="hidden"
              animate="show"
              variants={{ hidden: { opacity: 0 }, show: { opacity: 1, transition: { staggerChildren: 0.15, delayChildren: 0.6 } } }}
              className="mt-10 grid gap-4 md:grid-cols-3"
            >
              {heroHighlights.map((highlight) => (
                <motion.li key={highlight} variants={fadeIn} className="flex items-center gap-3 text-sm text-slate-300">
                  <span className="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-primary-200">
                    <Check className="h-4 w-4" />
                  </span>
                  {highlight}
                </motion.li>
              ))}
            </motion.ul>

            <motion.div
              initial="hidden"
              animate="show"
              variants={{ hidden: { opacity: 0 }, show: { opacity: 1, transition: { delayChildren: 0.8, staggerChildren: 0.15 } } }}
              className="mt-14 flex flex-wrap gap-10 text-sm text-slate-300"
            >
              {metrics.map((metric) => (
                <motion.div key={metric.label} variants={fadeIn}>
                  <div className="text-3xl font-display text-white">{metric.value}</div>
                  <div className="mt-1 max-w-[10rem] text-xs uppercase tracking-[0.3em] text-slate-400">
                    {metric.label}
                  </div>
                </motion.div>
              ))}
            </motion.div>
          </div>

          <motion.div
            initial={{ opacity: 0, y: 60 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.3 }}
            className="relative"
          >
            <div className="absolute inset-0 -translate-x-10 -translate-y-10 rounded-[3rem] bg-gradient-to-br from-primary-500/30 via-accent-500/20 to-transparent blur-3xl" />
            <div className="relative rounded-[28px] border border-white/10 bg-slate-900/40 shadow-2xl backdrop-blur-xl">
              <div className="flex items-center justify-between border-b border-white/10 px-8 py-5">
                <div>
                  <p className="text-sm text-slate-300">Запись</p>
                  <p className="text-lg font-semibold text-white">Weekly Product Review</p>
                </div>
                <span className="rounded-full bg-emerald-500/10 px-3 py-1 text-xs font-medium text-emerald-300">
                  Обработано
                </span>
              </div>
              <div className="space-y-6 px-8 py-10">
                <div className="glass-card gradient-border p-6">
                  <p className="text-sm uppercase tracking-[0.4em] text-primary-200">TL;DR</p>
                  <p className="mt-4 text-base text-slate-200">
                    Команда согласовала запуск новой онбординг-воронки. Нужно подготовить сценарий писем и обновить FAQ до пятницы.
                  </p>
                </div>
                <div className="glass-card gradient-border p-6">
                  <div className="flex items-start justify-between">
                    <div>
                      <p className="text-sm font-medium text-white">Глава 2 · Customer Success</p>
                      <p className="text-xs text-slate-400">12:47 — 18:05</p>
                    </div>
                    <span className="rounded-full bg-white/10 px-3 py-1 text-xs text-primary-200">5 цитат</span>
                  </div>
                  <ul className="mt-4 space-y-3 text-sm text-slate-300">
                    <li>— «Сделать рассылку в понедельник утром»</li>
                    <li>— «Добавить видео-гайд в help-центр»</li>
                    <li>— «Запланировать AMA для beta-клиентов»</li>
                  </ul>
                </div>
                <div className="glass-card gradient-border p-6">
                  <p className="text-sm font-medium text-white">Action items</p>
                  <ul className="mt-4 space-y-2 text-sm text-slate-200">
                    {[
                      "Настроить webhook для новых запросов",
                      "Подготовить deck по итогам демо",
                      "Синхронизировать backlog в Jira"
                    ].map((item) => (
                      <li key={item} className="flex items-center gap-3">
                        <span className="flex h-6 w-6 items-center justify-center rounded-full bg-primary-500/15 text-primary-200">
                          <Check className="h-3 w-3" />
                        </span>
                        {item}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>
          </motion.div>
        </div>
      </header>

      <main className="relative z-10 space-y-40 pb-32">
        <section id="features" className="px-6 md:px-12 lg:px-24">
          <div className="flex flex-col items-start gap-8 md:flex-row md:items-center md:justify-between">
            <div>
              <p className="section-eyebrow">ВОЗМОЖНОСТИ</p>
              <h2 className="section-title mt-6">Сфокусируйтесь на решениях, а не на расшифровке</h2>
            </div>
            <p className="section-paragraph">
              GhostDesk избавляет от ручного разбора встреч: автоматические теги, главы и заметки мгновенно показывают главное.
            </p>
          </div>
          <div className="mt-14 grid gap-8 md:grid-cols-2">
            {features.map((feature) => (
              <motion.div
                key={feature.title}
                initial="hidden"
                whileInView="show"
                viewport={{ once: true, margin: "-80px" }}
                variants={fadeIn}
                transition={{ duration: 0.6 }}
                className="glass-card gradient-border p-8"
              >
                <span className={`inline-flex h-12 w-12 items-center justify-center rounded-2xl ${feature.accent}`}>
                  <feature.icon className="h-6 w-6" />
                </span>
                <h3 className="mt-6 text-2xl font-display text-white">{feature.title}</h3>
                <p className="mt-4 text-base text-slate-300">{feature.description}</p>
              </motion.div>
            ))}
          </div>
        </section>

        <section id="platform" className="px-6 md:px-12 lg:px-24">
          <div className="glass-card gradient-border relative overflow-hidden px-10 py-16">
            <div className="absolute -top-24 right-16 h-64 w-64 rounded-full bg-primary-500/20 blur-3xl" />
            <div className="absolute -bottom-20 left-10 h-52 w-52 rounded-full bg-accent-500/10 blur-3xl" />
            <div className="relative grid gap-12 lg:grid-cols-[0.9fr_1.1fr] lg:items-center">
              <div>
                <p className="section-eyebrow">ПЛАТФОРМА</p>
                <h2 className="section-title mt-6">Один центр знаний для всей компании</h2>
                <p className="section-paragraph mt-6">
                  Просматривайте, ищите и делитесь контентом с любого устройства. GhostDesk адаптируется под ваш процесс — от ресёрч
                  команд до customer success.
                </p>
                <div className="mt-10 space-y-5 text-sm text-slate-200">
                  <div className="flex items-start gap-4">
                    <div className="rounded-full bg-primary-500/10 p-2 text-primary-200">
                      <LineChart className="h-5 w-5" />
                    </div>
                    <div>
                      <p className="font-semibold text-white">Аналитика внимания</p>
                      <p className="text-slate-300">
                        Отслеживайте, какие моменты записи привлекают наибольшее внимание и какие инсайты чаще всего цитируются.
                      </p>
                    </div>
                  </div>
                  <div className="flex items-start gap-4">
                    <div className="rounded-full bg-primary-500/10 p-2 text-primary-200">
                      <Shield className="h-5 w-5" />
                    </div>
                    <div>
                      <p className="font-semibold text-white">Гранулярные права доступа</p>
                      <p className="text-slate-300">
                        Управляйте видимостью каждой записи, задавайте сроки жизни ссылок и контролируйте скачивания.
                      </p>
                    </div>
                  </div>
                  <div className="flex items-start gap-4">
                    <div className="rounded-full bg-primary-500/10 p-2 text-primary-200">
                      <Sparkles className="h-5 w-5" />
                    </div>
                    <div>
                      <p className="font-semibold text-white">AI-автопилот</p>
                      <p className="text-slate-300">
                        Получайте мгновенные ответы на вопросы по стенограмме, задавайте уточнения и генерируйте follow-up письма.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <motion.div
                initial={{ opacity: 0, x: 80 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true, margin: "-100px" }}
                transition={{ duration: 0.7 }}
                className="relative"
              >
                <div className="glass-card gradient-border overflow-hidden rounded-[28px] border border-white/10 bg-slate-900/70">
                  <div className="flex items-center justify-between border-b border-white/5 px-6 py-5">
                    <div>
                      <p className="text-sm text-slate-300">Глобальный поиск</p>
                      <p className="text-lg font-semibold text-white">"tag:launch speaker:ivan"</p>
                    </div>
                    <span className="rounded-full bg-white/10 px-3 py-1 text-xs text-primary-200"><code>⌘K</code></span>
                  </div>
                  <div className="space-y-4 px-6 py-6">
                    {["Раздел \"Product discovery\"", "Цитата: " + "Пользователи хотят меньше шагов", "Action item: Провести A/B тест"]
                      .map((item, index) => (
                        <div key={item} className="rounded-2xl border border-white/10 bg-white/[0.03] px-5 py-4">
                          <p className="text-sm font-medium text-white">{item}</p>
                          <p className="mt-2 text-xs text-slate-400">Совпадение #{index + 1}</p>
                        </div>
                      ))}
                  </div>
                </div>
              </motion.div>
            </div>
          </div>
        </section>

        <section className="px-6 md:px-12 lg:px-24">
          <div className="flex flex-col gap-10 lg:flex-row lg:items-start lg:justify-between">
            <div className="max-w-xl">
              <p className="section-eyebrow">КАК ЭТО РАБОТАЕТ</p>
              <h2 className="section-title mt-6">Три шага от записи до инсайта</h2>
              <p className="section-paragraph mt-6">
                GhostDesk ведёт вас по всей воронке: захват контента, AI-обработка и моментальная дистрибуция в вашу экосистему.
              </p>
              <Link
                href="#cta"
                className="mt-10 inline-flex items-center gap-3 text-sm font-semibold text-primary-200 hover:text-primary-100"
              >
                Узнать о технической архитектуре
                <ArrowRight className="h-4 w-4" />
              </Link>
            </div>
            <div className="space-y-8">
              {workflow.map((step, index) => (
                <motion.div
                  key={step.title}
                  initial="hidden"
                  whileInView="show"
                  viewport={{ once: true, margin: "-60px" }}
                  variants={fadeIn}
                  transition={{ duration: 0.5, delay: index * 0.1 }}
                  className="relative flex gap-6 rounded-3xl border border-white/10 bg-white/[0.03] p-6"
                >
                  <div className="relative z-10 flex h-12 w-12 items-center justify-center rounded-2xl bg-primary-500/10 text-primary-200">
                    <step.icon className="h-6 w-6" />
                  </div>
                  <div>
                    <h3 className="text-xl font-semibold text-white">{step.title}</h3>
                    <p className="mt-3 text-sm text-slate-300">{step.description}</p>
                  </div>
                  <span className="absolute left-6 top-6 text-xs font-semibold uppercase tracking-[0.4em] text-white/30">
                    0{index + 1}
                  </span>
                </motion.div>
              ))}
            </div>
          </div>
        </section>

        <section id="testimonials" className="px-6 md:px-12 lg:px-24">
          <div className="flex flex-col items-start gap-6 md:flex-row md:items-end md:justify-between">
            <div>
              <p className="section-eyebrow">ОТЗЫВЫ</p>
              <h2 className="section-title mt-6">Команды замечают разницу спустя неделю</h2>
            </div>
            <p className="section-paragraph">
              GhostDesk помогает сфокусироваться на стратегии и клиентах. Мы спросили клиентов, что изменилось у них после запуска.
            </p>
          </div>
          <div className="mt-14 grid gap-8 lg:grid-cols-3">
            {testimonials.map((testimonial, index) => (
              <motion.div
                key={testimonial.name}
                initial="hidden"
                whileInView="show"
                viewport={{ once: true, margin: "-80px" }}
                variants={fadeIn}
                transition={{ duration: 0.6, delay: index * 0.1 }}
                className="glass-card gradient-border flex flex-col justify-between p-8"
              >
                <p className="text-lg text-slate-200">“{testimonial.quote}”</p>
                <div className="mt-8">
                  <p className="text-sm font-semibold text-white">{testimonial.name}</p>
                  <p className="text-xs text-slate-400">{testimonial.role}</p>
                  <p className="mt-4 inline-flex rounded-full bg-white/10 px-3 py-1 text-xs text-primary-200">
                    {testimonial.stat}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        </section>

        <section id="pricing" className="px-6 md:px-12 lg:px-24">
          <div className="glass-card gradient-border px-10 py-16">
            <div className="flex flex-col items-start gap-6 md:flex-row md:items-end md:justify-between">
              <div>
                <p className="section-eyebrow">ТАРИФЫ</p>
                <h2 className="section-title mt-6">Прозрачные планы роста</h2>
              </div>
              <p className="section-paragraph">
                Оплата только за активных участников команды. Гибкая настройка квот, выгрузок и хранения.
              </p>
            </div>
            <div className="mt-12 grid gap-6 lg:grid-cols-2">
              {pricing.map((plan) => (
                <motion.div
                  key={plan.name}
                  initial="hidden"
                  whileInView="show"
                  viewport={{ once: true, margin: "-80px" }}
                  variants={fadeIn}
                  transition={{ duration: 0.5 }}
                  className={clsx(
                    "relative flex flex-col rounded-3xl border border-white/15 p-8 transition-colors duration-300",
                    plan.featured ? "bg-white/[0.08] shadow-glow" : "bg-white/[0.03]"
                  )}
                >
                  {plan.featured ? (
                    <span className="absolute right-8 top-8 rounded-full bg-primary-500/15 px-3 py-1 text-xs font-medium text-primary-200">
                      Популярно
                    </span>
                  ) : null}
                  <div>
                    <p className="text-sm font-medium text-primary-200">{plan.name}</p>
                    <div className="mt-4 flex items-baseline gap-2">
                      <span className="text-4xl font-display text-white">{plan.price}</span>
                      <span className="text-sm text-slate-400">{plan.period}</span>
                    </div>
                    <p className="mt-4 text-sm text-slate-300">{plan.description}</p>
                  </div>
                  <ul className="mt-8 space-y-3 text-sm text-slate-200">
                    {plan.highlights.map((highlight) => (
                      <li key={highlight} className="flex items-start gap-3">
                        <span className="mt-1 flex h-5 w-5 items-center justify-center rounded-full bg-primary-500/15 text-primary-200">
                          <Check className="h-3 w-3" />
                        </span>
                        {highlight}
                      </li>
                    ))}
                  </ul>
                  <Link
                    href="#cta"
                    className={`mt-10 inline-flex items-center justify-center rounded-full px-6 py-3 text-sm font-semibold transition ${
                      plan.featured
                        ? "bg-primary-500 text-white shadow-glow hover:bg-primary-400"
                        : "border border-white/20 bg-white/5 text-white hover:border-white/30 hover:bg-white/10"
                    }`}
                  >
                    {plan.cta}
                  </Link>
                </motion.div>
              ))}
            </div>
          </div>
        </section>

        <section id="faq" className="px-6 md:px-12 lg:px-24">
          <div className="glass-card gradient-border grid gap-10 px-10 py-16 lg:grid-cols-[0.8fr_1.2fr]">
            <div>
              <p className="section-eyebrow">FAQ</p>
              <h2 className="section-title mt-6">Ответы на частые вопросы</h2>
              <p className="section-paragraph mt-6">
                Не нашли ответ? Напишите нам на <a href="mailto:hello@ghostdesk.app">hello@ghostdesk.app</a> — мы ответим в течение
                суток.
              </p>
            </div>
            <div className="space-y-8">
              {faqs.map((faq, index) => (
                <motion.div
                  key={faq.question}
                  initial="hidden"
                  whileInView="show"
                  viewport={{ once: true, margin: "-80px" }}
                  variants={fadeIn}
                  transition={{ duration: 0.5, delay: index * 0.05 }}
                  className="rounded-3xl border border-white/10 bg-white/[0.03] p-6"
                >
                  <p className="text-lg font-semibold text-white">{faq.question}</p>
                  <p className="mt-3 text-sm text-slate-300">{faq.answer}</p>
                </motion.div>
              ))}
            </div>
          </div>
        </section>

        <section id="cta" className="px-6 md:px-12 lg:px-24">
          <motion.div
            initial="hidden"
            whileInView="show"
            viewport={{ once: true, margin: "-100px" }}
            variants={fadeIn}
            transition={{ duration: 0.6 }}
            className="glass-card gradient-border overflow-hidden px-10 py-16 text-center"
          >
            <div className="mx-auto max-w-2xl">
              <p className="section-eyebrow">ГОТОВЫ</p>
              <h2 className="section-title mt-6">Запустите GhostDesk за 10 минут</h2>
              <p className="section-paragraph mx-auto mt-6 text-center">
                Подключите overlay-клиент, импортируйте первую запись и получите готовый обзор встречи всего через пару минут.
              </p>
            </div>
            <div className="mt-10 flex flex-wrap justify-center gap-4">
              <Link
                href="mailto:hello@ghostdesk.app"
                className="inline-flex items-center gap-3 rounded-full bg-primary-500 px-6 py-3 text-sm font-semibold text-white shadow-glow transition hover:bg-primary-400"
              >
                Забронировать личное демо
                <ArrowRight className="h-4 w-4" />
              </Link>
              <Link
                href="#"
                className="inline-flex items-center gap-3 rounded-full border border-white/15 bg-white/5 px-6 py-3 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/10"
              >
                Скачать overlay для macOS
              </Link>
            </div>
          </motion.div>
        </section>
      </main>

      <footer className="relative z-10 border-t border-white/10 px-6 py-10 text-sm text-slate-400 md:px-12 lg:px-24">
        <div className="flex flex-col justify-between gap-6 md:flex-row md:items-center">
          <p>© {new Date().getFullYear()} GhostDesk. Все права защищены.</p>
          <div className="flex flex-wrap gap-6">
            <Link href="#privacy" className="hover:text-white">
              Политика конфиденциальности
            </Link>
            <Link href="#terms" className="hover:text-white">
              Условия использования
            </Link>
            <a href="mailto:hello@ghostdesk.app" className="hover:text-white">
              Связаться
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
