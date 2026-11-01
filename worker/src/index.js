// PitFit: wysyłanie powiadomień o nowych wiadomościach (Cloudflare Worker).
// Sekret SERVICE_ACCOUNT_JSON zawiera klucz konta usługi pitfit-notifier.

const JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const SCOPES =
  "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging";

// Limity dostosowane do 50 zapytań na jedno wywołanie w darmowym planie.
const MAX_RECIPIENTS = 12;
const MAX_INSTALLATIONS_PER_USER = 3;
const MAX_FIDS = 20;
const MAX_STALE_DELETES = 5;

const ID_PATTERN = /^[A-Za-z0-9_-]{1,200}$/;

let jwksCache = {keys: null, expires: 0};
let tokenCache = {token: null, expires: 0};

// ---------- pomocnicze ----------

function b64urlToBytes(value) {
  let s = value.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function b64urlFromBytes(bytes) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlFromString(text) {
  return b64urlFromBytes(new TextEncoder().encode(text));
}

function decodeJson(part) {
  return JSON.parse(new TextDecoder().decode(b64urlToBytes(part)));
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {"Content-Type": "application/json"},
  });
}

// ---------- weryfikacja tokenu logowania Firebase ----------

async function getJwks() {
  const now = Date.now();
  if (jwksCache.keys && now < jwksCache.expires) return jwksCache.keys;

  const response = await fetch(JWKS_URL);
  if (!response.ok) throw new Error("Nie udało się pobrać kluczy Google");
  const data = await response.json();
  jwksCache = {keys: data.keys || [], expires: now + 60 * 60 * 1000};
  return jwksCache.keys;
}

async function verifyIdToken(token, projectId) {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Zły format tokenu");

  const header = decodeJson(parts[0]);
  const payload = decodeJson(parts[1]);
  if (header.alg !== "RS256" || !header.kid) throw new Error("Zły nagłówek");

  const keys = await getJwks();
  const jwk = keys.find((key) => key.kid === header.kid);
  if (!jwk) throw new Error("Nieznany klucz podpisu");

  const publicKey = await crypto.subtle.importKey(
      "jwk",
      jwk,
      {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"},
      false,
      ["verify"],
  );

  const valid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      publicKey,
      b64urlToBytes(parts[2]),
      new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new Error("Zły podpis");

  const now = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== "number" || payload.exp <= now) {
    throw new Error("Token wygasł");
  }
  if (typeof payload.iat !== "number" || payload.iat > now + 300) {
    throw new Error("Zły czas wystawienia");
  }
  if (payload.aud !== projectId) throw new Error("Zły odbiorca tokenu");
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error("Zły wystawca tokenu");
  }
  if (typeof payload.sub !== "string" || !payload.sub) {
    throw new Error("Brak identyfikatora użytkownika");
  }

  return payload.sub;
}

// ---------- token dostępu konta usługi ----------

async function getAccessToken(serviceAccount) {
  const now = Date.now();
  if (tokenCache.token && now < tokenCache.expires) return tokenCache.token;

  const iat = Math.floor(now / 1000);
  const tokenUri = serviceAccount.token_uri || "https://oauth2.googleapis.com/token";

  const unsigned =
    `${b64urlFromString(JSON.stringify({alg: "RS256", typ: "JWT"}))}.` +
    b64urlFromString(JSON.stringify({
      iss: serviceAccount.client_email,
      scope: SCOPES,
      aud: tokenUri,
      iat,
      exp: iat + 3600,
    }));

  const pem = serviceAccount.private_key
      .replace(/-----[^-]+-----/g, "")
      .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const privateKey = await crypto.subtle.importKey(
      "pkcs8",
      der,
      {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"},
      false,
      ["sign"],
  );

  const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      privateKey,
      new TextEncoder().encode(unsigned),
  );

  const response = await fetch(tokenUri, {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${b64urlFromBytes(new Uint8Array(signature))}`,
    }),
  });

  if (!response.ok) {
    throw new Error(`Token konta usługi: ${response.status} ${await response.text()}`);
  }

  const data = await response.json();
  tokenCache = {
    token: data.access_token,
    expires: now + (data.expires_in - 120) * 1000,
  };
  return tokenCache.token;
}

// ---------- Firestore (REST) ----------

function makeFirestore(projectId, accessToken) {
  const root = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  const headers = {Authorization: `Bearer ${accessToken}`};

  return {
    async get(path) {
      const response = await fetch(`${root}/${path}`, {headers});
      if (response.status === 404) return null;
      if (!response.ok) {
        throw new Error(`Firestore GET ${path}: ${response.status} ${await response.text()}`);
      }
      return response.json();
    },
    async list(path, pageSize) {
      const response = await fetch(`${root}/${path}?pageSize=${pageSize}`, {headers});
      if (!response.ok) {
        throw new Error(`Firestore LIST ${path}: ${response.status} ${await response.text()}`);
      }
      const data = await response.json();
      return data.documents || [];
    },
    async markNotified(path) {
      const url =
        `${root}/${path}?updateMask.fieldPaths=notifiedAt&currentDocument.exists=true`;
      const response = await fetch(url, {
        method: "PATCH",
        headers: {...headers, "Content-Type": "application/json"},
        body: JSON.stringify({
          fields: {notifiedAt: {timestampValue: new Date().toISOString()}},
        }),
      });
      if (!response.ok) {
        throw new Error(`Firestore PATCH ${path}: ${response.status} ${await response.text()}`);
      }
    },
    async remove(documentName) {
      await fetch(`https://firestore.googleapis.com/v1/${documentName}`, {
        method: "DELETE",
        headers,
      });
    },
  };
}

function stringField(doc, name) {
  const value = doc && doc.fields && doc.fields[name];
  return value && typeof value.stringValue === "string" ? value.stringValue : "";
}

// ---------- FCM ----------

async function sendToFid(projectId, accessToken, fid, notification, data) {
  const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            fid,
            notification,
            data,
            android: {
              priority: "HIGH",
              notification: {channel_id: "pitfit_general"},
            },
          },
        }),
      },
  );

  if (response.ok) return {ok: true};

  const text = await response.text();
  return {ok: false, stale: text.includes("UNREGISTERED"), status: response.status, text};
}

// ---------- główna obsługa ----------

export default {
  async fetch(request, env) {
    if (request.method !== "POST") return json({error: "Użyj POST"}, 405);

    const projectId = env.FIREBASE_PROJECT_ID;

    // 1. Kto wywołuje?
    const authHeader = request.headers.get("Authorization") || "";
    const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
    if (!idToken) return json({error: "Brak tokenu"}, 401);

    let callerUid;
    try {
      callerUid = await verifyIdToken(idToken, projectId);
    } catch (e) {
      return json({error: "Nieprawidłowy token"}, 401);
    }

    // 2. Dane wejściowe
    let body;
    try {
      body = await request.json();
    } catch (e) {
      return json({error: "Zły JSON"}, 400);
    }
    const {chatId, messageId} = body || {};
    if (!ID_PATTERN.test(chatId || "") || !ID_PATTERN.test(messageId || "")) {
      return json({error: "Zły identyfikator"}, 400);
    }

    try {
            const rawKey = String(env.SERVICE_ACCOUNT_JSON)
          .replace(/\u0000/g, "")
          .replace(/^[^{]*/, "")
          .trim();
      const serviceAccount = JSON.parse(rawKey);
      const accessToken = await getAccessToken(serviceAccount);
      const db = makeFirestore(projectId, accessToken);

      // 3. Wiadomość musi istnieć i należeć do wywołującego.
      const messagePath = `chats/${chatId}/messages/${messageId}`;
      const message = await db.get(messagePath);
      if (!message) return json({error: "Brak wiadomości"}, 404);
      if (stringField(message, "senderId") !== callerUid) {
        return json({error: "To nie Twoja wiadomość"}, 403);
      }
      if (message.fields && message.fields.notifiedAt) {
        return json({skipped: "już wysłano"});
      }

      // 4. Czat i uczestnicy.
      const chat = await db.get(`chats/${chatId}`);
      if (!chat) return json({error: "Brak czatu"}, 404);

      const values =
        (chat.fields.participants && chat.fields.participants.arrayValue.values) || [];
      const participants = values.map((v) => v.stringValue).filter(Boolean);
      if (!participants.includes(callerUid)) {
        return json({error: "Nie jesteś uczestnikiem"}, 403);
      }

      const recipients = participants
          .filter((uid) => uid !== callerUid)
          .slice(0, MAX_RECIPIENTS);
      if (recipients.length === 0) return json({sent: 0});

      // Oznacz zanim wyślesz, żeby powtórne wywołanie nie dublowało powiadomień.
      await db.markNotified(messagePath);

      // 5. Nazwa nadawcy i treść powiadomienia.
      const senderDoc = await db.get(`users/${callerUid}`);
      const senderName = stringField(senderDoc, "displayName") || "PitFit";
      const text = stringField(message, "text");
      const preview = text.length > 120 ? `${text.slice(0, 117)}...` : text;
      const isGroup = stringField(chat, "type") === "group";
      const title = isGroup && stringField(chat, "title") ?
        stringField(chat, "title") : senderName;
      const bodyText = isGroup ? `${senderName}: ${preview}` : preview;

      // 6. Urządzenia odbiorców.
      const installations = [];
      const lists = await Promise.all(recipients.map((uid) =>
        db.list(`users/${uid}/fcmInstallations`, MAX_INSTALLATIONS_PER_USER)
            .catch(() => [])));
      for (const docs of lists) {
        for (const doc of docs) {
          const fid = stringField(doc, "fid") || doc.name.split("/").pop();
          installations.push({fid, name: doc.name});
        }
      }
      const targets = installations.slice(0, MAX_FIDS);
      if (targets.length === 0) return json({sent: 0, note: "brak urządzeń"});

      // 7. Wysyłka.
      const results = await Promise.all(targets.map((t) =>
        sendToFid(
            projectId,
            accessToken,
            t.fid,
            {title, body: bodyText},
            {chatId, type: "chat_message"},
        ).then((r) => ({...r, target: t}))));

      let sent = 0;
      let stale = 0;
      const errors = [];
      for (const r of results) {
        if (r.ok) {
          sent++;
        } else {
          errors.push({fid: r.target.fid, status: r.status, text: (r.text || "").slice(0, 300)});
          if (r.stale && stale < MAX_STALE_DELETES) {
            stale++;
            await db.remove(r.target.name);
          }
        }
      }

      return json({sent, failed: results.length - sent, removed: stale, errors});
    } catch (e) {
      console.error("Błąd powiadomień:", e && e.message);
      return json({error: "Błąd serwera"}, 500);
    }
  },
};