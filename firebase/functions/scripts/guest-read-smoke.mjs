import {initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

const projectId = process.env.GCLOUD_PROJECT ?? "demo-sidecar";
initializeApp({projectId});
const db = getFirestore();
const functionBase = `http://127.0.0.1:5001/${projectId}/us-central1`;
const publishedId = "guest-smoke-published";
const privateId = "guest-smoke-private";

async function call(name, data) {
  const response = await fetch(`${functionBase}/${name}`, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({data}),
  });
  const payload = await response.json();
  return {status: response.status, payload};
}

await Promise.all([
  db.collection("rides").doc(publishedId).set({
    driverId: "guest-smoke-driver",
    driverName: "QA Driver",
    driverInitials: "QD",
    driverPhotoUrl: "",
    origin: {name: "UCSB", address: "Santa Barbara, CA"},
    destination: {name: "San Mateo", address: "San Mateo, CA"},
    departureAt: Timestamp.fromDate(new Date(Date.now() + 3_600_000)),
    seatsTotal: 3,
    seatsAvailable: 3,
    bookedSeats: 0,
    pricePerSeatCents: 3000,
    luggageAllowance: "backpack",
    genderRestriction: "anyone",
    vehicle: "Honda Civic",
    status: "published",
  }),
  db.collection("rides").doc(privateId).set({
    driverId: "guest-smoke-driver",
    departureAt: Timestamp.fromDate(new Date(Date.now() + 3_600_000)),
    seatsTotal: 3,
    seatsAvailable: 3,
    status: "cancelled",
  }),
]);

try {
  const list = await call("listLeavingSoon", {});
  if (list.status !== 200) throw new Error(`listLeavingSoon returned ${list.status}`);
  const rides = list.payload?.result?.rides ?? list.payload?.data?.rides;
  if (!Array.isArray(rides) || !rides.some((ride) => ride.id === publishedId)) {
    throw new Error("Published ride was not returned to a guest.");
  }

  const published = await call("getRide", {rideId: publishedId});
  if (published.status !== 200) throw new Error(`getRide returned ${published.status}`);
  const publicRide = published.payload?.result?.ride ?? published.payload?.data?.ride;
  if (publicRide?.id !== publishedId) {
    throw new Error("Published ride details were not returned to a guest.");
  }

  const privateRide = await call("getRide", {rideId: privateId});
  if (privateRide.status === 200) {
    throw new Error("A non-published ride was exposed to a guest.");
  }

  console.log("Guest ride API smoke test passed.");
} finally {
  await Promise.all([
    db.collection("rides").doc(publishedId).delete(),
    db.collection("rides").doc(privateId).delete(),
  ]);
}
