import { Network } from "x402-express";
import type { RouteConfig } from "x402-express";
import { env } from "./environment.js";

/**
 * Route configurations for protected endpoints
 * Each route can have its own pricing and network configuration
 */
export const routeConfigs: Record<string, RouteConfig> = {
  // Basic tier - Low cost endpoints
  "/api/basic/hello": {
    price: "$0.01",
    network: env.NETWORK,
    config: {
      description: "Basic hello world endpoint",
      mimeType: "application/json",
      maxTimeoutSeconds: 30,
    },
  },

  "/api/basic/time": {
    price: "$0.01",
    network: env.NETWORK,
    config: {
      description: "Get current server time",
      mimeType: "application/json",
    },
  },

  // Standard tier - Medium cost endpoints
  "/api/standard/user-info": {
    price: "$0.05",
    network: env.NETWORK,
    config: {
      description: "Get detailed user information",
      mimeType: "application/json",
      maxTimeoutSeconds: 45,
    },
  },

  "/api/standard/data-analytics": {
    price: "$0.10",
    network: env.NETWORK,
    config: {
      description: "Access to data analytics",
      mimeType: "application/json",
    },
  },

  // Premium tier - High value endpoints
  "/api/premium/ai-insights": {
    price: "$0.25",
    network: env.NETWORK,
    config: {
      description: "AI-powered insights and analysis",
      mimeType: "application/json",
      maxTimeoutSeconds: 60,
    },
  },

  "/api/premium/market-data": {
    price: "$0.50",
    network: env.NETWORK,
    config: {
      description: "Real-time market data and predictions",
      mimeType: "application/json",
      maxTimeoutSeconds: 90,
    },
  },

  // Enterprise tier - High-value endpoints
  "/api/enterprise/custom-report": {
    price: "$1.00",
    network: env.NETWORK,
    config: {
      description: "Generate custom enterprise reports",
      mimeType: "application/json",
      maxTimeoutSeconds: 120,
    },
  },

  "/api/enterprise/bulk-data": {
    price: "$2.00",
    network: env.NETWORK,
    config: {
      description: "Bulk data export with full history",
      mimeType: "application/json",
      maxTimeoutSeconds: 180,
    },
  },
};

/**
 * Pricing tiers for easy reference
 */
export const pricingTiers = {
  basic: "$0.01",
  standard: "$0.10",
  premium: "$0.50",
  enterprise: "$1.00",
} as const;

/**
 * Helper function to create a route config with default settings
 */
export function createRouteConfig(
  price: string,
  description: string,
  network: Network = env.NETWORK,
  mimeType: string = "application/json"
): RouteConfig {
  return {
    price,
    network,
    config: {
      description,
      mimeType,
      maxTimeoutSeconds: 60,
    },
  };
}
