/**
 * Plain JSON Schema fragments for Fastify's built-in Ajv validation (no new
 * dependency — Fastify validates `schema.body`/`params`/`querystring`
 * automatically and rejects non-conforming requests with 400 before the
 * handler runs). Compose these into each route's `schema` option.
 */

export const uuidSchema = {
  type: "string",
  format: "uuid",
} as const;

export const shortIdSchema = {
  type: "string",
  minLength: 1,
  maxLength: 50,
  pattern: "^[A-Za-z0-9_]+$",
} as const;

export const nonEmptyStringSchema = (maxLength: number) =>
  ({
    type: "string",
    minLength: 1,
    maxLength,
  }) as const;

export const positiveIntSchema = {
  type: "integer",
  minimum: 1,
} as const;

export const nonNegativeIntSchema = {
  type: "integer",
  minimum: 0,
} as const;

/** Every mutating endpoint that posts a wallet transaction requires this. */
export const idempotencyKeySchema = {
  type: "string",
  minLength: 8,
  maxLength: 120,
} as const;

export function bodySchema(properties: Record<string, unknown>, required: string[] = []) {
  return {
    body: {
      type: "object",
      additionalProperties: false,
      properties,
      required,
    },
  } as const;
}

export function paramsSchema(properties: Record<string, unknown>, required: string[]) {
  return {
    params: {
      type: "object",
      additionalProperties: false,
      properties,
      required,
    },
  } as const;
}
