import { randomBytes, createHash, timingSafeEqual } from "node:crypto";

/** 256 bits of randomness, base64url-encoded — the bearer token given to the client. */
export function generateOpaqueToken(): string {
  return randomBytes(32).toString("base64url");
}

/** Only this hash is ever stored — the raw token is returned once and never persisted. */
export function hashToken(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

/** A short, easy-to-type invite code shown to the parent to hand to the child. */
export function generateInviteCode(): string {
  // 8 chars from an unambiguous alphabet (no 0/O/1/I) — read out loud-friendly.
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = randomBytes(8);
  let code = "";
  for (const b of bytes) {
    code += alphabet[b % alphabet.length];
  }
  return code;
}

export function hashInviteCode(code: string): string {
  return createHash("sha256").update(code.toUpperCase(), "utf8").digest("hex");
}

export function safeEqualHex(a: string, b: string): boolean {
  const bufA = Buffer.from(a, "hex");
  const bufB = Buffer.from(b, "hex");
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}
