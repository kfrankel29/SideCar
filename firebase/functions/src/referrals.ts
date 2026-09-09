import {randomInt} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  normalizeReferralCode,
  referralCreditCents,
  validateReferralRedemption,
} from "./referral_policy.js";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const region = "us-central1";
function requireCode(value: unknown): string {
  try {
    return normalizeReferralCode(value);
  } catch {
    throw new HttpsError("invalid-argument", "Enter a valid 5-digit referral code.");
  }
}

async function codeForUser(uid: string): Promise<string> {
  const userReference = db.collection("users").doc(uid);
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const candidate = randomInt(10_000, 100_000).toString();
    const codeReference = db.collection("referral_codes").doc(candidate);
    const result = await db.runTransaction(async (transaction) => {
      const [userSnapshot, codeSnapshot] = await Promise.all([
        transaction.get(userReference),
        transaction.get(codeReference),
      ]);
      const existing = String(userSnapshot.data()?.referralCode ?? "");
      if (/^\d{5}$/.test(existing)) return existing;
      if (codeSnapshot.exists) return "";
      transaction.create(codeReference, {
        ownerUid: uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(userReference, {
        referralCode: candidate,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return candidate;
    });
    if (result) return result;
  }
  throw new HttpsError("resource-exhausted", "A referral code could not be created. Try again.");
}

export const getReferralCode = onCall(
  {region, enforceAppCheck: true, maxInstances: 40},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const code = await codeForUser(request.auth.uid);
    const user = (await db.collection("users").doc(request.auth.uid).get()).data();
    return {code, creditCents: Number(user?.creditCents ?? 0)};
  },
);

export const redeemReferralCode = onCall(
  {region, enforceAppCheck: true, maxInstances: 40},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in again.");
    const code = requireCode((request.data as {code?: unknown} | null)?.code);
    const codeReference = db.collection("referral_codes").doc(code);
    const redeemerReference = db.collection("users").doc(request.auth.uid);

    const ownerUid = await db.runTransaction(async (transaction) => {
      const [codeSnapshot, redeemerSnapshot] = await Promise.all([
        transaction.get(codeReference),
        transaction.get(redeemerReference),
      ]);
      if (!codeSnapshot.exists) {
        throw new HttpsError("not-found", "That referral code was not found.");
      }
      const owner = String(codeSnapshot.data()?.ownerUid ?? "");
      try {
        validateReferralRedemption(
          request.auth!.uid,
          owner,
          redeemerSnapshot.data()?.redeemedReferralCode,
        );
      } catch (error) {
        const reason = error instanceof Error ? error.message : "";
        if (reason === "own-referral-code") {
          throw new HttpsError("failed-precondition", "You cannot redeem your own referral code.");
        }
        if (reason === "referral-already-redeemed") {
          throw new HttpsError("already-exists", "You have already redeemed a referral code.");
        }
        throw new HttpsError("failed-precondition", "That referral code is unavailable.");
      }
      const ownerReference = db.collection("users").doc(owner);
      const ownerSnapshot = await transaction.get(ownerReference);
      if (!ownerSnapshot.exists) {
        throw new HttpsError("not-found", "That referral account is unavailable.");
      }
      transaction.set(redeemerReference, {
        creditCents: FieldValue.increment(referralCreditCents),
        redeemedReferralCode: code,
        referralRedeemedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.create(
        db.collection("referral_redemptions").doc(request.auth!.uid),
        {
          code,
          ownerUid: owner,
          redeemerUid: request.auth!.uid,
          creditCents: referralCreditCents,
          createdAt: FieldValue.serverTimestamp(),
        },
      );
      return owner;
    });
    return {redeemed: true, ownerUid, creditCents: referralCreditCents};
  },
);
