import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

admin.initializeApp();
const db = admin.firestore();

/**
 * Normalize user-provided text to a safe, short, single-line string.
 *
 * @param {string} input Raw user input.
 * @param {number} maxLen Maximum length (after normalization).
 * @return {string} Normalized, clamped string.
 */
function clampText(input: string, maxLen: number): string {
  const normalized = input
    .replace(/[\r\n\t]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (normalized.length <= maxLen) return normalized;
  return normalized.slice(0, Math.max(0, maxLen - 1)).trimEnd() + "…";
}

/**
 * Escape text for safe HTML/SVG injection.
 *
 * @param {string} input Raw text.
 * @return {string} HTML-escaped text.
 */
function escapeHtml(input: string): string {
  return input
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/**
 * Determine the public origin behind Firebase Hosting proxy.
 *
 * @param {{get: function(string): (string|undefined)}} req Request-like object.
 * @return {string} Public origin, e.g. "https://<host>".
 */
function getOrigin(req: {get: (name: string) => string | undefined}): string {
  const proto = (req.get("x-forwarded-proto") || "https")
    .split(",")[0]
    .trim();
  const host = (req.get("x-forwarded-host") || req.get("host") || "")
    .split(",")[0]
    .trim();
  return `${proto}://${host}`;
}

/**
 * Share landing page with OG/Twitter tags for rich previews.
 */
export const sharePage = onRequest({region: "europe-west1"}, (req, res) => {
  const rawName =
    (typeof req.query.name === "string" ? req.query.name : undefined) ?? "";
  const name = clampText(rawName || "En vane", 60);

  const origin = getOrigin(req);
  const url = `${origin}${req.originalUrl}`;
  const imageUrl = `${origin}/og.svg?name=${encodeURIComponent(name)}`;

  const title = `${name} – Vaner`;
  const description = `Jeg bygger vanen “${name}” i Vaner.`;

  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.setHeader("Cache-Control", "public, max-age=300, s-maxage=300");

  res.status(200).send(`<!doctype html>
<html lang="no">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${escapeHtml(title)}</title>
    <meta name="description" content="${escapeHtml(description)}" />

    <meta property="og:type" content="website" />
    <meta property="og:title" content="${escapeHtml(title)}" />
    <meta property="og:description" content="${escapeHtml(description)}" />
    <meta property="og:url" content="${escapeHtml(url)}" />
    <meta property="og:image" content="${escapeHtml(imageUrl)}" />
    <meta property="og:image:type" content="image/svg+xml" />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />

    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="${escapeHtml(title)}" />
    <meta name="twitter:description" content="${escapeHtml(description)}" />
    <meta name="twitter:image" content="${escapeHtml(imageUrl)}" />
  </head>
  <body style="
    font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif;
    margin: 40px;
    color: #0f172a;
  ">
    <h1 style="margin: 0 0 8px;">${escapeHtml(name)}</h1>
    <p style="margin: 0 0 20px; color: #334155;">
      Åpne Vaner for å se mer – eller last ned appen.
    </p>
    <p style="margin: 0;">
      <a href="${escapeHtml(origin)}" style="
        display: inline-block;
        padding: 10px 14px;
        border-radius: 10px;
        background: #0f766e;
        color: white;
        text-decoration: none;
      ">Gå til Vaner</a>
    </p>
  </body>
</html>`);
});

/**
 * Dynamic Open Graph image (SVG) for share previews.
 */
export const shareOgImage = onRequest({region: "europe-west1"}, (req, res) => {
  const rawName =
    (typeof req.query.name === "string" ? req.query.name : undefined) ?? "";
  const name = clampText(rawName || "Vaner", 40);

  const safe = escapeHtml(name);

  // Simple OG image as SVG (1200x630)
  const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0f766e"/>
      <stop offset="100%" stop-color="#0b3b3a"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow
        dx="0"
        dy="12"
        stdDeviation="18"
        flood-color="#000000"
        flood-opacity="0.28"
      />
    </filter>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)"/>
  <rect
    x="70"
    y="80"
    width="1060"
    height="470"
    rx="28"
    fill="#0b1220"
    fill-opacity="0.25"
    filter="url(#shadow)"
  />
  <text
    x="120"
    y="180"
    font-size="44"
    font-family="system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif"
    fill="#cbd5e1"
  >Vaner</text>
  <text
    x="120"
    y="290"
    font-size="72"
    font-weight="700"
    font-family="system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif"
    fill="#ffffff"
  >${safe}</text>
  <text
    x="120"
    y="360"
    font-size="30"
    font-family="system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif"
    fill="#e2e8f0"
  >Små vaner. Stor effekt.</text>
  <text
    x="120"
    y="470"
    font-size="26"
    font-family="system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif"
    fill="#a7f3d0"
  >Åpne lenken for å få appen</text>
</svg>`;

  res.setHeader("Content-Type", "image/svg+xml; charset=utf-8");
  res.setHeader("Cache-Control", "public, max-age=3600, s-maxage=3600");
  res.status(200).send(svg);
});

/**
 * Runs every 5 minutes in Europe/Oslo time.
 * Finds users whose notification.enabled = true and whose minuteOfDay
 * is close to the current time, and sends a push via FCM.
 */
export const sendDailyHabitReminders = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Europe/Oslo",
  },
  async () => {
    const now = new Date();
    const minuteOfDay = now.getHours() * 60 + now.getMinutes();
    const window = 5; // +/- 5 minutes

    const lower = minuteOfDay - window;
    const upper = minuteOfDay + window;

    logger.info(`Running reminder job at minute=${minuteOfDay}`);

    // 1) Find users who want notifications around now
    const usersSnap = await db
      .collection("users")
      .where("notification.enabled", "==", true)
      .where("notification.minuteOfDay", ">=", lower)
      .where("notification.minuteOfDay", "<=", upper)
      .get();

    logger.info(`Found ${usersSnap.size} users to notify`);

    for (const userDoc of usersSnap.docs) {
      const userId = userDoc.id;

      // 2) Get device tokens
      const devicesSnap = await db
        .collection("users")
        .doc(userId)
        .collection("devices")
        .where("enabled", "==", true)
        .get();

      const tokens = devicesSnap.docs
        .map((d) => d.get("token") as string | undefined)
        .filter((t): t is string => Boolean(t));

      if (!tokens.length) {
        logger.info(`No tokens for user ${userId}, skipping.`);
        continue;
      }

      // 3) Send FCM push
      const title = "Vaner";
      const body = "Husk dagens vaner ✨";

      const message: admin.messaging.MulticastMessage = {
        notification: {title, body},
        data: {
          userId,
        },
        tokens,
      };

      try {
        const res = await admin.messaging().sendEachForMulticast(message);
        logger.info(
          `Sent to ${userId}. ` +
            `success=${res.successCount}, failure=${res.failureCount}`,
        );
      } catch (err) {
        logger.error(`Error sending to ${userId}`, err);
      }
    }
  },
);
