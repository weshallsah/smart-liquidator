declare module "x402-express" {
  import { RequestHandler } from "express";

  export type Network = "base" | "base-sepolia";
  export type Price = string;

  export interface PaymentMiddlewareConfig {
    description?: string;
    mimeType?: string;
    maxTimeoutSeconds?: number;
    outputSchema?: Record<string, any>;
    customPaywallHtml?: string;
    resource?: string;
  }

  export interface RouteConfig {
    price: Price;
    network: Network;
    config?: PaymentMiddlewareConfig;
  }

  export type RoutesConfig = Record<string, Price | RouteConfig>;

  export type CreateHeaders = () => Promise<Record<string, string>>;

  export interface FacilitatorConfig {
    url: string;
    createAuthHeaders?: CreateHeaders;
  }

  export interface PaywallConfig {
    cdpClientKey?: string;
    appName?: string;
    appLogo?: string;
    sessionTokenEndpoint?: string;
  }

  export function paymentMiddleware(
    payTo: `0x${string}`,
    routes: RoutesConfig,
    facilitator?: FacilitatorConfig,
    paywall?: PaywallConfig
  ): RequestHandler;
}

declare module "x402-express/session-token" {
  import { RequestHandler } from "express";

  export const POST: RequestHandler;
}
