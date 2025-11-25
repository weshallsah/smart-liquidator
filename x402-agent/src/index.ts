import express, { Express, Request, Response } from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import compression from "compression";
import { paymentMiddleware } from "x402-express";
import { POST as sessionTokenHandler } from "x402-express/session-token";

import { env, logConfiguration, hasOnrampEnabled } from "./config/environment.js";
import { routeConfigs } from "./config/routes.js";
import {
  errorHandler,
  notFoundHandler,
  requestLogger,
  corsOptions,
  ResponseHelper,
  asyncHandler,
} from "./middleware/helpers.js";

const app: Express = express();

// ============================================================================
// Middleware Setup
// ============================================================================

// Security middleware
app.use(helmet());

// CORS configuration
app.use(cors(corsOptions));

// Body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Compression
app.use(compression());

// Logging
if (env.NODE_ENV === "development") {
  app.use(morgan("dev"));
}
app.use(requestLogger);

// ============================================================================
// x402 Payment Middleware Configuration
// ============================================================================

// Session token endpoint for Coinbase Onramp (if enabled)
if (hasOnrampEnabled) {
  app.post(env.SESSION_TOKEN_ENDPOINT, sessionTokenHandler);
  console.log(`✅ Onramp session token endpoint: ${env.SESSION_TOKEN_ENDPOINT}`);
}

// Configure x402 payment middleware
app.use(
  paymentMiddleware(
    env.PAYMENT_ADDRESS,
    routeConfigs,
    {
      url: env.FACILITATOR_URL,
    },
    hasOnrampEnabled
      ? {
          cdpClientKey: env.CDP_CLIENT_KEY,
          appName: env.APP_NAME,
          appLogo: env.APP_LOGO,
          sessionTokenEndpoint: env.SESSION_TOKEN_ENDPOINT,
        }
      : undefined
  )
);

// ============================================================================
// Public Routes (No Payment Required)
// ============================================================================

app.get("/", (_req: Request, res: Response) => {
  ResponseHelper.success(res, {
    name: env.APP_NAME,
    version: "1.0.0",
    description: "x402 Payment Protocol API",
    documentation: "/api/docs",
    status: "operational",
  });
});

app.get("/api/health", (_req: Request, res: Response) => {
  ResponseHelper.success(res, {
    status: "healthy",
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    environment: env.NODE_ENV,
    payment: {
      network: env.NETWORK,
      address: env.PAYMENT_ADDRESS,
      onrampEnabled: hasOnrampEnabled,
    },
  });
});

app.get("/api/docs", (_req: Request, res: Response) => {
  const routes = Object.keys(routeConfigs).map((path) => {
    const config = routeConfigs[path];
    return {
      path,
      price: config.price,
      network: config.network,
      description: config.config?.description,
    };
  });

  ResponseHelper.success(res, {
    endpoints: routes,
    totalEndpoints: routes.length,
    paymentRequired: true,
    instructions:
      "All API endpoints require payment via the x402 protocol. Visit any endpoint to see the payment modal.",
  });
});

// ============================================================================
// Protected Routes - Basic Tier ($0.01)
// ============================================================================

app.get(
  "/api/basic/hello",
  asyncHandler(async (_req: Request, res: Response) => {
    ResponseHelper.success(res, {
      message: "Hello from x402 protected API!",
      tier: "basic",
      paid: true,
    });
  })
);

app.get(
  "/api/basic/time",
  asyncHandler(async (_req: Request, res: Response) => {
    ResponseHelper.success(res, {
      serverTime: new Date().toISOString(),
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      timestamp: Date.now(),
      tier: "basic",
    });
  })
);

// ============================================================================
// Protected Routes - Standard Tier ($0.05 - $0.10)
// ============================================================================

app.get(
  "/api/standard/user-info",
  asyncHandler(async (_req: Request, res: Response) => {
    ResponseHelper.success(res, {
      user: {
        id: "user_" + Math.random().toString(36).substr(2, 9),
        tier: "standard",
        accessGranted: new Date().toISOString(),
        features: ["analytics", "reports", "api-access"],
      },
      tier: "standard",
    });
  })
);

app.get(
  "/api/standard/data-analytics",
  asyncHandler(async (_req: Request, res: Response) => {
    // Simulate some data processing
    const analytics = {
      pageViews: Math.floor(Math.random() * 10000),
      uniqueVisitors: Math.floor(Math.random() * 5000),
      bounceRate: (Math.random() * 100).toFixed(2) + "%",
      avgSessionDuration: Math.floor(Math.random() * 300) + " seconds",
      topPages: [
        { page: "/home", views: Math.floor(Math.random() * 1000) },
        { page: "/about", views: Math.floor(Math.random() * 500) },
        { page: "/contact", views: Math.floor(Math.random() * 300) },
      ],
    };

    ResponseHelper.success(res, {
      analytics,
      period: "last_30_days",
      tier: "standard",
    });
  })
);

// ============================================================================
// Protected Routes - Premium Tier ($0.25 - $0.50)
// ============================================================================

app.get(
  "/api/premium/ai-insights",
  asyncHandler(async (_req: Request, res: Response) => {
    // Simulate AI processing
    const insights = {
      predictions: [
        {
          category: "User Growth",
          prediction: "+23% in next quarter",
          confidence: 0.87,
        },
        {
          category: "Revenue",
          prediction: "$150K increase",
          confidence: 0.92,
        },
        {
          category: "Churn Rate",
          prediction: "-5% improvement",
          confidence: 0.78,
        },
      ],
      recommendations: [
        "Focus on user retention programs",
        "Expand premium tier offerings",
        "Optimize pricing strategy",
      ],
      generatedAt: new Date().toISOString(),
      tier: "premium",
    };

    ResponseHelper.success(res, insights);
  })
);

app.get(
  "/api/premium/market-data",
  asyncHandler(async (_req: Request, res: Response) => {
    const marketData = {
      markets: [
        {
          symbol: "BTC/USD",
          price: 45000 + Math.random() * 1000,
          change24h: (Math.random() * 10 - 5).toFixed(2) + "%",
          volume: Math.floor(Math.random() * 1000000000),
        },
        {
          symbol: "ETH/USD",
          price: 3000 + Math.random() * 100,
          change24h: (Math.random() * 10 - 5).toFixed(2) + "%",
          volume: Math.floor(Math.random() * 500000000),
        },
        {
          symbol: "USDC/USD",
          price: 1.0,
          change24h: "0.00%",
          volume: Math.floor(Math.random() * 100000000),
        },
      ],
      timestamp: new Date().toISOString(),
      tier: "premium",
    };

    ResponseHelper.success(res, marketData);
  })
);

// ============================================================================
// Protected Routes - Enterprise Tier ($1.00 - $2.00)
// ============================================================================

app.get(
  "/api/enterprise/custom-report",
  asyncHandler(async (_req: Request, res: Response) => {
    const report = {
      reportId: "RPT_" + Date.now(),
      title: "Enterprise Analytics Report",
      sections: [
        {
          name: "Executive Summary",
          data: "Comprehensive overview of business metrics...",
        },
        {
          name: "Financial Analysis",
          data: "Detailed financial breakdown and projections...",
        },
        {
          name: "Market Position",
          data: "Competitive analysis and market share data...",
        },
        {
          name: "Growth Opportunities",
          data: "Strategic recommendations for expansion...",
        },
      ],
      generatedAt: new Date().toISOString(),
      tier: "enterprise",
    };

    ResponseHelper.success(res, report);
  })
);

app.get(
  "/api/enterprise/bulk-data",
  asyncHandler(async (_req: Request, res: Response) => {
    // Simulate bulk data export
    const bulkData = {
      exportId: "EXP_" + Date.now(),
      totalRecords: 50000,
      format: "JSON",
      dataPoints: Array.from({ length: 100 }, (_, i) => ({
        id: i + 1,
        timestamp: new Date(Date.now() - i * 86400000).toISOString(),
        value: Math.random() * 1000,
        category: ["A", "B", "C", "D"][Math.floor(Math.random() * 4)],
      })),
      downloadUrl: "/api/enterprise/bulk-data/download/" + Date.now(),
      expiresAt: new Date(Date.now() + 3600000).toISOString(),
      tier: "enterprise",
    };

    ResponseHelper.success(res, bulkData);
  })
);

// ============================================================================
// Error Handling
// ============================================================================

app.use(notFoundHandler);
app.use(errorHandler);

// ============================================================================
// Server Startup
// ============================================================================

app.listen(env.PORT, () => {
  console.clear();
  console.log("╔════════════════════════════════════════════════════════════╗");
  console.log("║           x402 Payment Protocol API Server                ║");
  console.log("╚════════════════════════════════════════════════════════════╝");
  console.log("");
  logConfiguration();
  console.log("");
  console.log(`🚀 Server running at http://localhost:${env.PORT}`);
  console.log(`📚 API Documentation: http://localhost:${env.PORT}/api/docs`);
  console.log(`💚 Health Check: http://localhost:${env.PORT}/api/health`);
  console.log("");
  console.log("Press Ctrl+C to stop the server");
  console.log("════════════════════════════════════════════════════════════");
});

export default app;
