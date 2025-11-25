import { config } from "dotenv";
import { Network } from "x402-express";

// Load environment variables
config();

interface EnvironmentVariables {
  PORT: number;
  NODE_ENV: string;
  PAYMENT_ADDRESS: `0x${string}`;
  NETWORK: Network;
  FACILITATOR_URL: string;
  CDP_API_KEY_ID?: string;
  CDP_API_KEY_SECRET?: string;
  CDP_CLIENT_KEY?: string;
  APP_NAME: string;
  APP_LOGO?: string;
  SESSION_TOKEN_ENDPOINT: string;
}

function validateAddress(address: string): `0x${string}` {
  if (!address.startsWith("0x") || address.length !== 42) {
    throw new Error("Invalid Ethereum address format");
  }
  return address as `0x${string}`;
}

function validateNetwork(network: string): Network {
  if (network !== "base" && network !== "base-sepolia") {
    throw new Error('Network must be either "base" or "base-sepolia"');
  }
  return network as Network;
}

export const env: EnvironmentVariables = {
  PORT: parseInt(process.env.PORT || "3000", 10),
  NODE_ENV: process.env.NODE_ENV || "development",
  PAYMENT_ADDRESS: validateAddress(
    process.env.PAYMENT_ADDRESS || "0x0000000000000000000000000000000000000000"
  ),
  NETWORK: validateNetwork(process.env.NETWORK || "base-sepolia"),
  FACILITATOR_URL:
    process.env.FACILITATOR_URL || "https://facilitator.x402.com",
  CDP_API_KEY_ID: process.env.CDP_API_KEY_ID,
  CDP_API_KEY_SECRET: process.env.CDP_API_KEY_SECRET,
  CDP_CLIENT_KEY: process.env.CDP_CLIENT_KEY,
  APP_NAME: process.env.APP_NAME || "x402 API",
  APP_LOGO: process.env.APP_LOGO,
  SESSION_TOKEN_ENDPOINT:
    process.env.SESSION_TOKEN_ENDPOINT || "/api/x402/session-token",
};

// Validate CDP credentials if any are provided
export const hasCDPCredentials = Boolean(
  env.CDP_API_KEY_ID && env.CDP_API_KEY_SECRET
);

export const hasOnrampEnabled = Boolean(hasCDPCredentials && env.CDP_CLIENT_KEY);

// Log configuration on startup (without sensitive data)
export function logConfiguration(): void {
  console.log("🔧 Server Configuration:");
  console.log(`   Environment: ${env.NODE_ENV}`);
  console.log(`   Port: ${env.PORT}`);
  console.log(`   Payment Address: ${env.PAYMENT_ADDRESS}`);
  console.log(`   Network: ${env.NETWORK}`);
  console.log(`   Facilitator: ${env.FACILITATOR_URL}`);
  console.log(`   CDP Integration: ${hasCDPCredentials ? "✅ Enabled" : "❌ Disabled"}`);
  console.log(`   Onramp Feature: ${hasOnrampEnabled ? "✅ Enabled" : "❌ Disabled"}`);
  console.log(`   App Name: ${env.APP_NAME}`);
}
