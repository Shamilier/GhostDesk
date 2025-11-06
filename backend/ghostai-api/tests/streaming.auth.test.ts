import request from "supertest";
import { afterEach, beforeEach, describe, it, expect } from "vitest";
import { createTestApp, createTestConfig, createTestDatabase } from "./helpers";
import { createS3Client } from "../src/lib/s3";
import type { AppConfig } from "../src/config";
import type { Database } from "../src/db";

describe("streaming endpoints auth", () => {
  let config: AppConfig;
  let dbCtx: { db: Database; destroy: () => Promise<void> };
  let app: ReturnType<typeof createTestApp>;

  beforeEach(async () => {
    const baseConfig = createTestConfig();
    config = {
      ...baseConfig,
      openAiApiKey: "",
      auth: {
        ...baseConfig.auth,
        allowedApiKeys: ["test-key"],
      },
    };

    dbCtx = await createTestDatabase();
    const s3Client = createS3Client(config.s3);
    app = createTestApp(config, dbCtx.db, s3Client);
  });

  afterEach(async () => {
    await dbCtx.destroy();
  });

  it("rejects /hint without authorization", async () => {
    await request(app)
      .post("/hint")
      .send({ context: "hello" })
      .expect(401)
      .expect({ error: "Unauthorized" });
  });

  it("rejects /ask with missing token before parsing body", async () => {
    await request(app)
      .post("/ask")
      .field("question", "test")
      .expect(401)
      .expect({ error: "Unauthorized" });
  });

  it("rejects /ask_without_query with invalid token", async () => {
    await request(app)
      .post("/ask_without_query")
      .set("Authorization", "Bearer nope")
      .field("transcript", "hello")
      .expect(401)
      .expect({ error: "Unauthorized" });
  });
});
