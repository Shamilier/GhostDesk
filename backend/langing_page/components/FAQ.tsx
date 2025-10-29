"use client";

import { AnimatePresence, motion } from "framer-motion";
import { ChevronDown } from "lucide-react";
import { useState } from "react";

const FAQ_ITEMS = [
  {
    question: "Как Ghost AI работает поверх любых приложений?",
    answer:
      "Ghost AI — это лёгкий оверлей, который закрепляется поверх окон и вкладок. Он слушает системный звук, микрофон и считывает активное окно, не вмешиваясь в само приложение."
  },
  {
    question: "Какие данные обрабатываются локально, а какие — в облаке?",
    answer:
      "Вы контролируете источники. Часть фильтрации и распознавания проходит локально, а для глубокого анализа используется зашифрованная обработка в облаке. Чувствительные фрагменты можно исключать."
  },
  {
    question: "Поддерживается ли мой язык?",
    answer:
      "Ghost AI работает с десятками языков, включая русский и английский. Для редких языков доступны fallback-модели и возможность обучить словари."
  },
  {
    question: "Можно ли отключить экран/звук и оставить только микрофон?",
    answer:
      "Да. В настройках можно быстро выключить любой канал — Ghost AI продолжит слушать только выбранный источник."
  },
  {
    question: "Как экспортировать заметки и итоги встречи?",
    answer:
      "Итоги можно выгрузить в Markdown, PDF или напрямую отправить в Notion, Slack, CRM. Также доступен API для собственных интеграций."
  },
  {
    question: "Чем планы Pro и Team отличаются от Starter?",
    answer:
      "Starter рассчитан на личное использование. Pro добавляет пост-аналитику, шаблоны и расширенный архив. Team расширяет совместную работу: роли, коллекции, безопасность, приоритетную поддержку."
  }
];

export function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <section id="faq" className="relative mx-auto mt-32 w-full max-w-5xl px-4 sm:px-6">
      <div className="mx-auto max-w-3xl text-center">
        <motion.span
          className="text-xs font-semibold uppercase tracking-[0.32em] text-white/60"
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
        >
          FAQ
        </motion.span>
        <motion.h2
          className="mt-4 text-3xl font-semibold text-white sm:text-4xl"
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ delay: 0.1, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
        >
          Остались вопросы? Ответим заранее
        </motion.h2>
      </div>
      <div className="mt-12 space-y-4">
        {FAQ_ITEMS.map((item, index) => {
          const isOpen = openIndex === index;
          return (
            <div key={item.question} className="overflow-hidden rounded-3xl border border-white/12 bg-white/5">
              <button
                className="flex w-full items-center justify-between gap-4 px-6 py-5 text-left text-base text-white/80 transition hover:text-white"
                onClick={() => setOpenIndex(isOpen ? null : index)}
                aria-expanded={isOpen}
              >
                <span className="text-lg font-medium text-white">{item.question}</span>
                <motion.span animate={{ rotate: isOpen ? 180 : 0 }}>
                  <ChevronDown className="h-5 w-5 text-white/60" />
                </motion.span>
              </button>
              <AnimatePresence initial={false}>
                {isOpen && (
                  <motion.div
                    key="content"
                    initial="collapsed"
                    animate="open"
                    exit="collapsed"
                    variants={{
                      open: { height: "auto", opacity: 1 },
                      collapsed: { height: 0, opacity: 0 }
                    }}
                    transition={{ duration: 0.35, ease: [0.4, 0, 0.2, 1] }}
                  >
                    <div className="px-6 pb-6 text-sm text-white/70">{item.answer}</div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          );
        })}
      </div>
    </section>
  );
}
