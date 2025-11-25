import { Request, Response, NextFunction } from "express";

/**
 * Error handling middleware
 */
export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  console.error("❌ Error:", err.message);
  console.error(err.stack);

  res.status(500).json({
    success: false,
    error: {
      message: err.message || "Internal server error",
      ...(process.env.NODE_ENV === "development" && { stack: err.stack }),
    },
  });
}

/**
 * 404 handler
 */
export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({
    success: false,
    error: {
      message: "Endpoint not found",
      path: req.path,
    },
  });
}

/**
 * Request logger middleware
 */
export function requestLogger(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const start = Date.now();

  res.on("finish", () => {
    const duration = Date.now() - start;
    const statusColor =
      res.statusCode >= 500
        ? "\x1b[31m"
        : res.statusCode >= 400
        ? "\x1b[33m"
        : res.statusCode >= 300
        ? "\x1b[36m"
        : "\x1b[32m";

    console.log(
      `${req.method} ${req.path} ${statusColor}${res.statusCode}\x1b[0m ${duration}ms`
    );
  });

  next();
}

/**
 * CORS configuration
 */
export const corsOptions = {
  origin:
    process.env.NODE_ENV === "development"
      ? "*"
      : process.env.ALLOWED_ORIGINS?.split(",") || "*",
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "x402-payment"],
  credentials: true,
};

/**
 * Response helper utilities
 */
export class ResponseHelper {
  static success(res: Response, data: any, message?: string): void {
    res.json({
      success: true,
      ...(message && { message }),
      data,
      timestamp: new Date().toISOString(),
    });
  }

  static error(res: Response, message: string, statusCode: number = 400): void {
    res.status(statusCode).json({
      success: false,
      error: {
        message,
      },
      timestamp: new Date().toISOString(),
    });
  }

  static created(res: Response, data: any, message?: string): void {
    res.status(201).json({
      success: true,
      message: message || "Resource created successfully",
      data,
      timestamp: new Date().toISOString(),
    });
  }

  static noContent(res: Response): void {
    res.status(204).send();
  }
}

/**
 * Async handler wrapper to catch errors in async route handlers
 */
export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<any>
) {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
