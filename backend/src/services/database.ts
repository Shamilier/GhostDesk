import Database from "better-sqlite3";
import type { Database as DatabaseInstance } from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const DEFAULT_DB_NAME = "ghostdesk.sqlite";

function resolveDatabasePath(): string {
  const explicit = process.env.DATABASE_PATH;
  if (explicit && explicit.trim().length > 0) {
    return explicit.trim();
  }

  const backendRoot = path.resolve(fileURLToPath(new URL("../../", import.meta.url)));
  const dataDir = path.join(backendRoot, "data");
  fs.mkdirSync(dataDir, { recursive: true });
  return path.join(dataDir, DEFAULT_DB_NAME);
}

let databaseInstance: DatabaseInstance | null = null;

export function getDatabase(): DatabaseInstance {
  if (!databaseInstance) {
    const dbPath = resolveDatabasePath();
    fs.mkdirSync(path.dirname(dbPath), { recursive: true });
    databaseInstance = new Database(dbPath);
    databaseInstance.pragma("journal_mode = WAL");
    databaseInstance.pragma("foreign_keys = ON");
  }

  return databaseInstance;
}

export function closeDatabase(): void {
  if (databaseInstance) {
    databaseInstance.close();
    databaseInstance = null;
  }
}
