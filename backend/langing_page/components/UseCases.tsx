"use client";

import { motion } from "framer-motion";
import {
  BriefcaseBusiness,
  FileText,
  GraduationCap,
  Handshake,
  LifeBuoy,
  UsersRound
} from "lucide-react";
import { useState } from "react";
import { GlassCard } from "./GlassCard";
import { SectionHeading } from "./SectionHeading";

const USE_CASES = [
  {
    title: "Собеседования",
    description: "Вопросы, проверочные сценарии, оценка ответов.",
    icon: Handshake,
    headline: "Нанимайте уверенно",
    summary:
      "Фиксируйте ключевые ответы кандидатов, подстраивайте вопросы под диалог и получайте готовый отчёт для Hiring Manager.",
    bullets: [
      "Сценарии для HR, технических и культурных интервью",
      "Автоматическое выделение сильных и слабых сторон",
      "Отправка отчёта в ATS или командный чат"
    ],
    cta: "Собрать интервью"
  },
  {
    title: "Продажи/CS",
    description: "Обработка возражений, next steps, CRM-конспект.",
    icon: BriefcaseBusiness,
    headline: "Закрывайте сделки быстрее",
    summary:
      "GhostDesk фиксирует боли клиента, помнит договорённости и подсказывает, что предложить дальше — без переключения вкладок.",
    bullets: [
      "Темплейты ответов на возражения и FAQ",
      "Подбор action items и сроков по каждой встрече",
      "Экспорт заметок в CRM за секунду"
    ],
    cta: "Усилить продажи"
  },
  {
    title: "Исследования/UX",
    description: "Маркировка инсайтов, темы и цитаты.",
    icon: FileText,
    headline: "Глубокие инсайты без ручной расшифровки",
    summary:
      "Помечайте инсайты во время интервью, сортируйте по темам и делитесь выдержками с дизайнерами и разработчиками.",
    bullets: [
      "Метки сегментов, гипотез и неожиданных находок",
      "Цитаты участников с тайм-кодами",
      "Экспорт в Miro, Notion или презентацию"
    ],
    cta: "Систематизировать инсайты"
  },
  {
    title: "Лекции/курсы",
    description: "Шпаргалки, термины, конспекты, тайм-коды.",
    icon: GraduationCap,
    headline: "Учите и обучайтесь осознанно",
    summary:
      "Создавайте структурированные конспекты, выделяйте ключевые определения и делитесь материалами со студентами.",
    bullets: [
      "Автономные заметки для каждого занятия",
      "Быстрые шпаргалки и карточки терминов",
      "Подготовка к экзаменам и контрольным"
    ],
    cta: "Оцифровать лекцию"
  },
  {
    title: "Командные созвоны",
    description: "Роли, action items, follow-ups.",
    icon: UsersRound,
    headline: "Синхронизируйте команду",
    summary:
      "Собирайте решение, ответственных и дедлайны в одном документе. Команда получает follow-up сразу после звонка.",
    bullets: [
      "Назначение ответственных по каждому решению",
      "Трекер задач с дедлайнами",
      "Автоматическое напоминание в Slack или почте"
    ],
    cta: "Систематизировать созвон"
  },
  {
    title: "Техподдержка",
    description: "Пошаговые инструкции и автосаммари.",
    icon: LifeBuoy,
    headline: "Помогайте клиентам без задержек",
    summary:
      "Подсказки с готовыми ответами и ссылки на базы знаний позволяют закрывать тикеты быстрее.",
    bullets: [
      "Шаблоны ответов для разных каналов",
      "История обращений и контекст клиента",
      "Экспорт отчёта по тикету"
    ],
    cta: "Ускорить поддержку"
  }
];

export function UseCases() {
  const [activeIndex, setActiveIndex] = useState(0);
  const activeCase = USE_CASES[activeIndex];

  return (
    <section id="use-cases" className="relative mx-auto mt-32 w-full max-w-6xl px-4 sm:px-6">
      <SectionHeading
        eyebrow="Сценарии"
        title="GhostDesk усиливает каждую встречу"
        description="Выбирайте сценарий, и вы увидите, как GhostDesk структурирует разговор. Карточки можно пролистывать без перезагрузки страницы — каждый кейс раскрывается в отдельном блоке."
      />
      <div className="mt-16 grid gap-12 lg:grid-cols-[1.2fr,0.9fr]">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          {USE_CASES.map((useCase, index) => {
            const Icon = useCase.icon;
            const isActive = index === activeIndex;
            return (
              <motion.button
                key={useCase.title}
                type="button"
                onClick={() => setActiveIndex(index)}
                className={`glass relative overflow-hidden rounded-3xl p-6 text-left transition duration-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70 sm:p-7 ${
                  isActive ? "border-white/30 bg-white/10" : "border border-white/10 bg-white/5 hover:border-white/20"
                }`}
                whileHover={{ scale: isActive ? 1.02 : 1.03 }}
                whileTap={{ scale: 0.98 }}
                aria-pressed={isActive}
              >
                <span className="inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-white/10 text-white">
                  <Icon className="h-5 w-5" />
                </span>
                <h3 className="mt-4 text-lg font-semibold text-white">{useCase.title}</h3>
                <p className="mt-2 text-sm text-white/70">{useCase.description}</p>
                {isActive && (
                  <span className="mt-4 inline-flex items-center rounded-full bg-white/15 px-3 py-1 text-xs font-medium uppercase tracking-[0.25em] text-white/80">
                    Активно
                  </span>
                )}
              </motion.button>
            );
          })}
        </div>
        <GlassCard className="h-full">
          <motion.div
            key={activeCase.title}
            className="flex h-full flex-col gap-6"
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.45, ease: [0.4, 0, 0.2, 1] }}
          >
            <div className="space-y-2">
              <span className="text-xs uppercase tracking-[0.3em] text-white/40">Выбранный сценарий</span>
              <h3 className="text-2xl font-semibold text-white">{activeCase.headline}</h3>
              <p className="text-sm leading-relaxed text-white/70 sm:text-base">{activeCase.summary}</p>
            </div>
            <motion.ul
              className="space-y-3 text-sm text-white/70 sm:text-base"
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1, duration: 0.4, ease: [0.4, 0, 0.2, 1] }}
            >
              {activeCase.bullets.map(point => (
                <li key={point} className="flex items-start gap-3">
                  <span className="mt-1 inline-flex h-2 w-2 flex-none rounded-full bg-white/60" />
                  <span>{point}</span>
                </li>
              ))}
            </motion.ul>
            <motion.a
              href="#cta"
              className="self-start rounded-full border border-white/20 bg-white/5 px-5 py-2 text-xs font-semibold uppercase tracking-[0.25em] text-white transition hover:border-white/40"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.96 }}
            >
              {activeCase.cta}
            </motion.a>
          </motion.div>
        </GlassCard>
      </div>
    </section>
  );
}
