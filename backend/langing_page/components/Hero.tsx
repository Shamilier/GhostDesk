"use client";

import { motion } from "framer-motion";
import { AppWindowMac, Mic, Sparkles } from "lucide-react";

const HIGHLIGHTS = [
  {
    icon: Mic,
    title: "Подсказывает по ходу разговора",
    description: "Ghost AI слушает системный звук и ваш микрофон, чтобы мгновенно предложить формулировки и факты."
  },
  {
    icon: AppWindowMac,
    title: "Работает поверх любого окна",
    description: "Лёгкий оверлей закрепляется поверх звонков, презентаций и лекций без лишних меню."
  },
  {
    icon: Sparkles,
    title: "Отвечает по хоткеям",
    description: "Спросите про то, что на экране, или попросите идею ответа — AI отвечает тут же, не выходя из звонка."
  }
];

export function Hero() {
  return (
    <section id="hero" className="relative isolate overflow-hidden pt-32 pb-20 sm:pt-40">
      <div className="pointer-events-none absolute inset-x-0 top-0 -z-10 mx-auto h-[480px] w-[900px] max-w-[95vw] rounded-[180px] bg-gradient-to-br from-[#5b8cff1c] via-[#5be5ff14] to-[#a06aff26] blur-3xl" />
      <div className="mx-auto flex w-full max-w-5xl flex-col gap-14 px-4 sm:px-6">
        <motion.div
          className="inline-flex items-center gap-2 self-start rounded-full border border-white/10 bg-white/5 px-4 py-2 text-[0.65rem] font-semibold uppercase tracking-[0.32em] text-white/70"
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
        >
          Невидимый помощник для живых разговоров
        </motion.div>
        <div className="grid gap-12 lg:grid-cols-[1.05fr,0.95fr] lg:items-center">
          <div className="space-y-8">
            <motion.h1
              className="text-4xl font-semibold leading-tight text-white sm:text-5xl md:text-[3.5rem]"
              initial={{ opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.05, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
            >
              Ghost AI — невидимый AI-ассистент на macOS для звонков, лекций и живых созвонов
            </motion.h1>
            <motion.p
              className="text-base text-white/70 sm:text-lg"
              initial={{ opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.12, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
            >
              Сфокусируйтесь на собеседнике. Ghost AI слушает систему, подсказывает ответы, запоминает договорённости и готовится к пост-анализу записей. Всё происходит локально на вашем рабочем столе.
            </motion.p>
            <motion.div
              className="flex flex-col gap-3 sm:flex-row"
              initial={{ opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.18, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
            >
              <a
                href="#cta"
                className="btn-primary inline-flex justify-center px-8 py-4 text-sm uppercase tracking-[0.2em]"
              >
                Скачать для macOS
              </a>
              <a
                href="#workflow"
                className="btn-secondary inline-flex justify-center px-8 py-4 text-sm uppercase tracking-[0.2em]"
              >
                Посмотреть как работает
              </a>
            </motion.div>
            <motion.div
              className="grid gap-4 rounded-3xl border border-white/8 bg-white/[0.04] p-6 sm:grid-cols-3 sm:p-7"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.26, duration: 0.55, ease: [0.4, 0, 0.2, 1] }}
            >
              {HIGHLIGHTS.map(item => {
                const Icon = item.icon;
                return (
                  <div key={item.title} className="space-y-3 text-left">
                    <span className="inline-flex h-10 w-10 items-center justify-center rounded-2xl bg-white/10 text-white">
                      <Icon className="h-4 w-4" />
                    </span>
                    <h3 className="text-sm font-semibold text-white sm:text-base">{item.title}</h3>
                    <p className="text-sm text-white/60">{item.description}</p>
                  </div>
                );
              })}
            </motion.div>
          </div>
          <motion.div
            className="relative flex flex-col gap-6 rounded-[32px] border border-white/10 bg-white/[0.03] p-7"
            initial={{ opacity: 0, y: 26 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
          >
            <div className="flex items-center justify-between text-xs uppercase tracking-[0.28em] text-white/50">
              <span className="inline-flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-white/70" />Live режим
              </span>
              Ghost AI
            </div>
            <div className="rounded-2xl border border-white/12 bg-black/40 p-6 text-left">
              <p className="text-sm font-medium uppercase tracking-[0.32em] text-white/40">Звонок с клиентом</p>
              <p className="mt-4 text-xl font-semibold text-white">«Давайте сверим ожидания по внедрению»</p>
              <div className="mt-5 space-y-3 text-sm text-white/65">
                <div className="flex items-start gap-3">
                  <span className="mt-1 inline-flex h-2 w-2 flex-none rounded-full bg-[#5b8cff]" />
                  Ghost AI: «Спросите про доступы и дедлайн запуска. Предложите шаблон письма после встречи».
                </div>
                <div className="flex items-start gap-3">
                  <span className="mt-1 inline-flex h-2 w-2 flex-none rounded-full bg-[#5be5ff]" />
                  Ответ по хоткею: «Каков статус платежа?» — Ghost AI показывает подсказку с последними цифрами.
                </div>
              </div>
            </div>
            <div className="rounded-2xl border border-white/10 bg-white/6 p-6 text-left text-sm text-white/70">
              <p className="text-xs uppercase tracking-[0.3em] text-white/40">Скоро</p>
              <p className="mt-3 text-base font-semibold text-white">Пост-анализ записей</p>
              <p className="mt-2">Получайте расшифровку, цитаты и задачи автоматически. Функция в активной разработке.</p>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
