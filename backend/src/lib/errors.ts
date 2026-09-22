export class HttpError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    public details?: unknown,
  ) {
    super(code);
    this.name = "HttpError";
  }
}
