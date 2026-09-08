import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const firebaseToolsRoot = process.env.SIDECAR_FIREBASE_TOOLS_ROOT;
const [appId, debugToken, displayName] = process.argv.slice(2);

if (!firebaseToolsRoot || !appId || !debugToken || !displayName) {
  throw new Error(
    "SIDECAR_FIREBASE_TOOLS_ROOT, app id, debug token, and display name are required.",
  );
}

const cliAuth = require(`${firebaseToolsRoot}/lib/auth.js`);
const cliApi = require(`${firebaseToolsRoot}/lib/api.js`);
const account = cliAuth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) {
  throw new Error("Run firebase login before registering App Check QA tokens.");
}

const access = await cliAuth.getAccessToken(
  account.tokens.refresh_token,
  cliApi.getScopes(),
);
const response = await fetch(
  `https://firebaseappcheck.googleapis.com/v1/projects/sidecar-fb0e7/apps/${appId}/debugTokens`,
  {
    method: "POST",
    headers: {
      authorization: `Bearer ${access.access_token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({displayName, token: debugToken}),
  },
);

if (!response.ok && response.status !== 409) {
  const payload = await response.json().catch(() => ({}));
  throw new Error(
    `App Check registration failed (${response.status}): ${
      payload?.error?.message ?? "unknown error"
    }`,
  );
}

process.stdout.write(
  response.status === 409
    ? `App Check token already registered for ${displayName}.\n`
    : `Registered App Check token for ${displayName}.\n`,
);
