import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";

admin.initializeApp();
const db = admin.firestore();

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
