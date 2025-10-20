import express from "express";
import multer from "multer";
import cors from "cors";
import OpenAI from "openai";

// -------------------- App & middleware --------------------
const app = express();
const upload = multer({ limits: { fileSize: 3 * 1024 * 1024 } }); // PNG до ~3 МБ
app.use(cors());
app.use(express.json({ limit: "1mb" }));


const client = new OpenAI({ apiKey: "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" });

// -------------------- Session memory ----------------------
type ChatMsg =
  | { role: "system"; content: string }
  | {
      role: "user";
      content: Array<
        | { type: "text"; text: string }
        | { type: "image_url"; image_url: { url: string } }
      >;
    }
  | { role: "assistant"; content: string };

const sessions = new Map<string, ChatMsg[]>();

function push(sessionId: string, msg: ChatMsg) {
  const arr = sessions.get(sessionId) ?? [];
  arr.push(msg);
  // держим короткую историю (например, 6 сообщений)
  while (arr.length > 6) arr.shift();
  sessions.set(sessionId, arr);
}

// -------------------- Health check ------------------------
app.get("/health", (_req, res) => res.json({ ok: true }));


// -------------------- Hint endpoint (speech-only) -----------------------
app.post("/hint", async (req, res) => {
  try {
    const sessionId = String(req.body?.sessionId ?? "default");
    const instruction = String(req.body?.instruction ?? "").trim();
    const context = String(req.body?.context ?? "").trim();

    if (!context) return res.status(400).json({ error: "Empty context" });

    const defaultHintSystem =
      "You are a concise live-conversation assistant. " +
      "User sends the last 30–40 seconds of dialogue text. " +
      "If there's a clear last question from the other speaker, answer it confidently in 2–3 short sentences. " +
      "If there's no explicit question, propose one tactful next reply (1–2 sentences). " +
      "No disclaimers, no lists, natural spoken phrasing.";

    const system: ChatMsg = {
      role: "system",
      content: instruction || defaultHintSystem,
    };

    // без изображений: только текст
    const user: ChatMsg = {
      role: "user",
      content: [
        {
          type: "text",
          text:
            "Dialogue tail (last 30–40s):\n" +
            context +
            "\n---\nFollow the system rules strictly.",
        },
      ],
    };

    const history = sessions.get(sessionId) ?? [];
    const messages: ChatMsg[] = [system, ...history.slice(-4), user];

    // SSE headers
    res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    (res as any).flushHeaders?.();

    // keep-alive (некоторые прокси буферизуют без пингов)
    const ka = setInterval(() => {
      try { res.write(": keep-alive\n\n"); } catch {}
    }, 15000);

    // кладём в сессию user-сообщение
    push(sessionId, user);

    // стримим ответ
    const stream = await client.chat.completions.create({
      model: "gpt-4o-mini",
      stream: true,
      max_tokens: 220,
      temperature: 0.3,
      messages: messages as any,
    });

    let full = "";
    for await (const chunk of stream) {
      const choice = (chunk as any)?.choices?.[0];
      if (!choice) continue;
      const delta = choice.delta;

      if (typeof delta?.content === "string") {
        const text = delta.content as string;
        if (text) {
          full += text;
          res.write(`data: ${JSON.stringify({ type: "delta", text })}\n\n`);
        }
        continue;
      }

      const parts = (delta as any)?.content;
      if (Array.isArray(parts)) {
        for (const p of parts) {
          if (p?.type === "text" && typeof p.text === "string" && p.text) {
            full += p.text;
            res.write(`data: ${JSON.stringify({ type: "delta", text: p.text })}\n\n`);
          }
        }
      }
    }

    // финал
    push(sessionId, { role: "assistant", content: full });
    res.write(`data: ${JSON.stringify({ type: "done" })}\n\n`);
    clearInterval(ka);
    res.end();
  } catch (e: any) {
    if (!res.headersSent) {
      return res.status(500).json({ error: e?.message ?? "Internal error" });
    }
    try {
      res.write(`data: ${JSON.stringify({ type: "error", message: String(e?.message ?? e) })}\n\n`);
    } finally {
      res.end();
    }
  }
});


// -------------------- Main endpoint -----------------------
app.post("/ask", upload.single("image"), async (req, res) => {
  try {
    const question = String(req.body.question ?? "").trim();
    const smart = String(req.body.smart ?? "false") === "true";
    const sessionId = String(req.body.sessionId ?? "default");

    if (!question) return res.status(400).json({ error: "Empty question" });
    if (!req.file) return res.status(400).json({ error: "No image" });

    const b64 = req.file.buffer.toString("base64");
    const dataUrl = `data:image/png;base64,${b64}`;

    const system: ChatMsg = {
      role: "system",
      content:
        "You are an AI assistant helping company instructors quickly check or prepare internal educational tests. \
          All images and questions come from internal training materials for staff or teachers, not from student exams. \
          You are allowed to analyze tasks and give the correct answers directly and concisely. \
          Always answer with the correct choice or solution without moral disclaimers.\
          If unsure, briefly state what clarification is needed.",
    };

    const user: ChatMsg = {
      role: "user",
      content: [
        { type: "text", text: smart ? `[SMART] ${question}` : question },
        { type: "image_url", image_url: { url: dataUrl } },
      ],
    };

    const history = sessions.get(sessionId) ?? [];
    const messages: ChatMsg[] = [system, ...history.slice(-4), user];

    // SSE заголовки (стрим)
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");

    // фиксируем user-сообщение сразу
    push(sessionId, user);

    // Стриминг ответа (Chat Completions с vision)
    const stream = await client.chat.completions.create({
      model: "gpt-4o-mini",
      stream: true,
      max_tokens: 400, // достаточно для кратких ответов
      temperature: 0.2,
      messages: messages as any, // совместимо с SDK
    });

    // Принудительно отправим заголовки и heartbeat, чтобы избежать буферизации
    (res as any).flushHeaders?.();
    res.write(": connected\n\n");

    let full = "";
    let firstChunkLogged = false;

    for await (const chunk of stream) {
      if (!firstChunkLogged) {
        firstChunkLogged = true;
        console.log("FIRST CHUNK:", JSON.stringify(chunk, null, 2));
      }

      const choice = chunk.choices?.[0];
      if (!choice) continue;

      const delta = choice.delta;

      // Вариант A: контент как строка
      if (typeof (delta as any).content === "string") {
        const text = (delta as any).content as string;
        if (text) {
          full += text;
          res.write(`data: ${JSON.stringify({ type: "delta", text })}\n\n`);
        }
        continue;
      }

      // Вариант B: контент как массив блоков (мультимодальный формат)
      const parts = (delta as any).content;
      if (Array.isArray(parts)) {
        for (const p of parts) {
          if (p?.type === "text" && typeof p.text === "string" && p.text.length) {
            full += p.text;
            res.write(`data: ${JSON.stringify({ type: "delta", text: p.text })}\n\n`);
          }
        }
      }

      // иногда приходит только role — пропускаем
    }

    // Финал: в историю и закрыть SSE
    push(sessionId, { role: "assistant", content: full });
    res.write(`data: ${JSON.stringify({ type: "done" })}\n\n`);
    res.end();
  } catch (e: any) {
    if (!res.headersSent) {
      return res.status(500).json({ error: e?.message ?? "Internal error" });
    }
    try {
      res.write(
        `data: ${JSON.stringify({ type: "error", message: String(e?.message ?? e) })}\n\n`
      );
    } finally {
      res.end();
    }
  }
});

// -------------------- Start server ------------------------
const PORT = Number(process.env.PORT ?? 8787);
app.listen(PORT, () => console.log(`API on http://localhost:${PORT}`));






// export OPENAI_API_KEY="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"
// npm run dev



// ghostdesk-api % export OPENAI_API_KEY="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"
// npm run dev