import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "jose";

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_JWKS_URL = new URL("https://appleid.apple.com/auth/keys");
const jwks = createRemoteJWKSet(APPLE_JWKS_URL);

export type AppleTokenPayload = {
  sub: string;
  iss: string;
  aud: string;
  email?: string;
  email_verified?: string;
};

export type AppleOAuthConfig = {
  clientId: string;
  teamId: string;
  keyId: string;
  privateKey: string;
  redirectUri?: string;
};

export type AppleTokenResponse = {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token?: string;
  id_token?: string;
};

export async function verifyAppleIdentityToken(identityToken: string, audience: string): Promise<AppleTokenPayload> {
  const { payload } = await jwtVerify(identityToken, jwks, {
    issuer: APPLE_ISSUER,
    audience,
    clockTolerance: 5
  });

  if (typeof payload.sub !== "string") {
    throw new Error("Invalid token subject");
  }
  if (typeof payload.iss !== "string" || payload.iss !== APPLE_ISSUER) {
    throw new Error("Invalid token issuer");
  }
  if (typeof payload.aud !== "string" || payload.aud !== audience) {
    throw new Error("Invalid token audience");
  }

  return payload as AppleTokenPayload;
}

export async function exchangeAuthorizationCode(code: string, config: AppleOAuthConfig): Promise<AppleTokenResponse> {
  const now = Math.floor(Date.now() / 1000);
  const privateKey = config.privateKey.replace(/\\n/g, "\n");
  const key = await importPKCS8(privateKey, "ES256");
  const clientSecret = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: config.keyId })
    .setIssuer(config.teamId)
    .setSubject(config.clientId)
    .setAudience(APPLE_ISSUER)
    .setIssuedAt(now)
    .setExpirationTime(now + 600)
    .sign(key);

  const body = new URLSearchParams({
    client_id: config.clientId,
    client_secret: clientSecret,
    code,
    grant_type: "authorization_code"
  });
  if (config.redirectUri) {
    body.append("redirect_uri", config.redirectUri);
  }

  const response = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Apple token exchange failed: ${text}`);
  }

  return (await response.json()) as AppleTokenResponse;
}
