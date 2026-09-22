import { fileURLToPath } from "node:url";
import path from "node:path";
import dotenv from "dotenv";

// Load the repo-root .env (single source of truth shared with db/scripts/migrate.sh)
// so APP_DATABASE_URL doesn't need to be duplicated into backend/.env.
dotenv.config({ path: path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../.env") });

const { buildApp } = await import("./app.js");

const port = Number(process.env["PORT"] ?? 3000);
const host = process.env["HOST"] ?? "127.0.0.1";

const app = await buildApp();

try {
  await app.listen({ port, host });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
