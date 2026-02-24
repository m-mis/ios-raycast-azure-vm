import { Cache, getPreferenceValues } from "@raycast/api";
import { TokenResponse } from "./types";
import { TOKEN_CACHE_KEY } from "./constants";

const cache = new Cache();

interface CachedToken {
  accessToken: string;
  expiresAt: number;
}

function getCredentials() {
  const { tenantId, clientId, clientSecret } = getPreferenceValues<Preferences>();
  if (!tenantId || !clientId || !clientSecret) {
    throw new Error(
      "Azure credentials are not configured. Please set Tenant ID, Client ID, and Client Secret in extension preferences.",
    );
  }
  return { tenantId, clientId, clientSecret };
}

async function fetchToken(tenantId: string, clientId: string, clientSecret: string): Promise<CachedToken> {
  const tokenUrl = `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`;

  const body = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: clientId,
    client_secret: clientSecret,
    scope: "https://management.azure.com/.default",
  });

  const response = await fetch(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Authentication failed (${response.status}): ${errorText}`);
  }

  const data = (await response.json()) as TokenResponse;

  return {
    accessToken: data.access_token,
    expiresAt: Date.now() + (data.expires_in - 60) * 1000, // refresh 60s before expiry
  };
}

export async function getAccessToken(): Promise<string> {
  const cached = cache.get(TOKEN_CACHE_KEY);
  if (cached) {
    try {
      const token: CachedToken = JSON.parse(cached);
      if (token.expiresAt > Date.now()) {
        return token.accessToken;
      }
    } catch {
      // corrupt cache entry, fall through to refresh
    }
  }

  const { tenantId, clientId, clientSecret } = getCredentials();
  const token = await fetchToken(tenantId, clientId, clientSecret);
  cache.set(TOKEN_CACHE_KEY, JSON.stringify(token));
  return token.accessToken;
}

export function clearTokenCache() {
  cache.remove(TOKEN_CACHE_KEY);
}
