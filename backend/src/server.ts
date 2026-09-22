import { fileURLToPath } from "node:url";
import path from "node:path";
import dotenv from "dotenv";

// Load the repo-root .env (single source of truth shared with db/scripts/migrate.sh)
// so APP_DATABASE_URL doesn't need to be duplicated into backend/.env.
dotenv.config({ path: path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../.env") });

const { buildApp } = await import("./app.js");

const port = Number(process.env["PORT"] ?? 3000);
// 0.0.0.0 by default: a loopback-only bind would refuse connections coming
// in via the Android emulator's 10.0.2.2 host-forwarding route (and from a
// physical device on the same LAN) even though they originate on this same
// machine — they don't arrive on the literal loopback interface. Local dev
// convenience only; set HOST explicitly for any non-local deployment.
const host = process.env["HOST"] ?? "0.0.0.0";

const app = await buildApp();

try {
  await app.listen({ port, host });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
