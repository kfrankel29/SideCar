import {initializeApp} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js";
import {
  browserLocalPersistence,
  EmailAuthProvider,
  getAuth,
  onAuthStateChanged,
  reauthenticateWithCredential,
  setPersistence,
  signInWithEmailAndPassword,
  signOut,
  updatePassword,
} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js";
import {
  getFunctions,
  httpsCallable,
} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-functions.js";
import {changeInitialPassword} from "./password_flow.js";

const firebaseConfig = await fetch("/__/firebase/init.json", {cache: "no-store"}).then((response) => {
  if (response.ok) return response.json();
  if (["localhost", "127.0.0.1"].includes(location.hostname)) {
    return {
      apiKey: "local-dashboard-qa",
      authDomain: location.hostname,
      projectId: "sidecar-fb0e7",
      appId: "local-dashboard-qa",
    };
  }
  throw new Error("Firebase Hosting configuration is unavailable.");
});
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const functions = getFunctions(app, "us-central1");
await setPersistence(auth, browserLocalPersistence);

const calls = Object.fromEntries([
  "adminGetOverview", "adminListUsers", "adminListRecords", "adminGetConfig",
  "adminUpdateConfig", "adminSetUserStatus", "adminCompleteFirstLogin",
  "adminUpdateUserProfile", "adminDeleteUserAccount", "adminVerifyUserEmail",
].map((name) => [name, httpsCallable(functions, name)]));

const state = {
  currentView: "overview",
  currentAdminUid: "",
  users: [],
  userPageToken: "",
  records: [],
  recordCursor: "",
  temporaryPassword: "",
};
const localPreview = ["localhost", "127.0.0.1"].includes(location.hostname) &&
  new URLSearchParams(location.search).get("preview") === "1";
const recordViews = new Set(["rides", "bookings", "payments", "refunds", "disputes", "audit"]);
const titles = {
  overview: "Overview", users: "Users",
  config: "Configuration", rides: "Rides", bookings: "Bookings",
  payments: "Payments", refunds: "Refunds", disputes: "Disputed trips", audit: "Audit log",
};

const $ = (selector) => document.querySelector(selector);
const escapeHtml = (value) => String(value ?? "").replace(/[&<>'"]/g, (character) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", "\"": "&quot;",
})[character]);
const money = (cents) => new Intl.NumberFormat("en-US", {style: "currency", currency: "USD"})
  .format(Number(cents || 0) / 100);
const date = (value) => value ? new Intl.DateTimeFormat("en-US", {dateStyle: "medium", timeStyle: "short"})
  .format(new Date(value)) : "—";
const shortId = (value) => {
  const text = String(value ?? "");
  if (text.length <= 16) return escapeHtml(text || "—");
  return `<span title="${escapeHtml(text)}">${escapeHtml(`${text.slice(0, 8)}…${text.slice(-4)}`)}</span>`;
};

function humanLabel(value) {
  const raw = String(value || "notStarted");
  const known = {
    notStarted: "Not started",
    not_started: "Not started",
    requiresAction: "Needs attention",
    manual_review: "Manual review",
  };
  if (known[raw]) return known[raw];
  const spaced = raw
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/[_.]+/g, " ");
  return spaced.charAt(0).toUpperCase() + spaced.slice(1);
}

function setStatus(message = "", isError = false) {
  const element = $("#status");
  element.textContent = message;
  element.classList.toggle("is-error", isError);
}

function errorMessage(error) {
  const message = String(error?.message ?? "Something went wrong.")
    .replace(/^Firebase:\s*/i, "")
    .replace(/\s*\(functions\/[\w-]+\)\.?$/i, "");
  return message || "Something went wrong.";
}

async function run(label, work) {
  setStatus(label);
  try {
    const result = await work();
    setStatus("");
    return result;
  } catch (error) {
    setStatus(errorMessage(error), true);
    throw error;
  }
}

function pill(value) {
  const normalized = String(value || "notStarted");
  const statusKey = normalized.replaceAll("_", "").toLowerCase();
  const className = ["verified", "active", "paid", "confirmed", "completed", "published"]
    .includes(statusKey) ? "good" : ["banned", "suspended", "rejected", "failed", "requiresaction", "disputed"]
      .includes(statusKey) ? "bad" : "pending";
  return `<span class="pill ${className}">${escapeHtml(humanLabel(normalized))}</span>`;
}

function table(headers, rows) {
  if (!rows.length) return '<p class="empty">No records found.</p>';
  return `<div class="table-wrap"><table><thead><tr>${headers.map((header) => `<th>${escapeHtml(header)}</th>`).join("")}</tr></thead><tbody>${rows.join("")}</tbody></table></div>`;
}

async function loadOverview() {
  const response = await run("Loading live totals…", () => calls.adminGetOverview({}));
  const labels = {
    users: "Users",
    rides: "Rides",
    bookings: "Bookings",
    disputes: "Open disputes",
  };
  $("#summary-cards").innerHTML = Object.entries(response.data.counts)
    .filter(([key]) => key !== "pendingInsurance")
    .map(([key, value]) => `<article class="summary-card"><span>${labels[key] ?? key}</span><strong>${escapeHtml(value)}</strong></article>`)
    .join("");
}

function userRows(users) {
  return users.map((user) => {
    const name = `${user.firstName || ""} ${user.lastName || ""}`.trim() || "Unnamed user";
    const verification = user.verification;
    const photo = user.photoUrl
      ? `<img class="user-photo" src="${escapeHtml(user.photoUrl)}" alt="${escapeHtml(name)} profile photo">`
      : `<span class="user-photo user-photo-fallback" aria-hidden="true">${escapeHtml(name.charAt(0).toUpperCase())}</span>`;
    const emailStatus = user.emailVerified
      ? pill("verified")
      : `<div class="stack">${pill("pending")}${user.isAdmin ? "" : `<button class="secondary" data-action="verify-email" data-uid="${escapeHtml(user.uid)}">Verify email</button>`}</div>`;
    const actions = user.isAdmin ? '<span class="pill pending">Administrator</span>' : (() => {
        const status = String(user.accountStatus || "active");
        const edit = `<button class="secondary" data-action="edit-user" data-uid="${escapeHtml(user.uid)}">Edit</button>`;
        const remove = `<button class="danger" data-action="delete-user" data-uid="${escapeHtml(user.uid)}">Delete</button>`;
        if (status === "banned") {
          return `<div class="row-actions">${edit}<button class="secondary" data-action="restore-user" data-uid="${escapeHtml(user.uid)}">Restore</button>${remove}</div>`;
        }
        if (status === "suspended") {
          return `<div class="row-actions">${edit}<button class="secondary" data-action="restore-user" data-uid="${escapeHtml(user.uid)}">Restore</button><button class="danger" data-action="ban-user" data-uid="${escapeHtml(user.uid)}">Ban</button>${remove}</div>`;
        }
        return `<div class="row-actions">${edit}<button class="warning" data-action="suspend-user" data-uid="${escapeHtml(user.uid)}">Suspend</button><button class="danger" data-action="ban-user" data-uid="${escapeHtml(user.uid)}">Ban</button>${remove}</div>`;
      })();
    return `<tr>
      <td><div class="user-identity">${photo}<div class="stack"><strong>${escapeHtml(name)}</strong><small>${escapeHtml(user.email)}</small><small>${shortId(user.uid)}</small></div></div></td>
      <td>${pill(user.accountStatus)}</td>
      <td>${emailStatus}</td>
      <td>${pill(verification.identityStatus)}</td>
      <td>${pill(verification.driverStatus)}</td>
      <td>${actions}</td>
    </tr>`;
  });
}

function renderUsers() {
  $("#users-count").textContent = `${state.users.length} on this page`;
  $("#users-table").innerHTML = table(
    ["User", "Account", "Email", "Identity", "Driver", "Actions"],
    userRows(state.users),
  );
  $("#users-next").hidden = !state.userPageToken;
}

async function loadUsers(append = false) {
  const response = await run("Loading users and verification status…", () => calls.adminListUsers({
    pageToken: append ? state.userPageToken : "",
  }));
  state.users = append ? [...state.users, ...response.data.users] : response.data.users;
  state.userPageToken = response.data.nextPageToken;
  renderUsers();
}

async function loadConfig() {
  const response = await run("Loading live configuration…", () => calls.adminGetConfig({}));
  const config = response.data.config;
  $("#service-fee-type").value = config.serviceFeeType;
  $("#service-fee-value").value = config.serviceFeeValue;
  $("#driver-fee-percentage").value = config.driverFeePercentage;
  $("#stripe-card-percentage").value = config.stripeCardPercentage;
  $("#irs-mileage-rate").value = config.irsMileageRate;
  $("#payment-expiration-hours").value = config.paymentExpirationHours;
  $("#trip-auto-complete-hours").value = config.tripAutoCompleteHours;
  $("#refund-rules").value = JSON.stringify(config.refundRules, null, 2);
  $("#config-version").textContent = config.version || `Template ${config.templateVersion}`;
}

function recordRows(kind, records) {
  const route = (record) => record.originName || record.destinationName ? `${escapeHtml(record.originName || "—")} → ${escapeHtml(record.destinationName || "—")}` : "—";
  if (kind === "rides") return records.map((record) => {
    const riders = Array.isArray(record.riders) && record.riders.length > 0
      ? record.riders.map((rider) => `${escapeHtml(rider.name || rider.id || "Unknown rider")} ${pill(rider.status || "unknown")}`).join("<br>")
      : "—";
    return `<tr><td>${shortId(record.id)}</td><td>${escapeHtml(record.driverName || record.driverId || "—")}</td><td>${riders}</td><td>${route(record)}</td><td>${date(record.departureAt)}</td><td>${pill(record.status)}</td><td>${money(record.pricePerSeatCents)}</td></tr>`;
  });
  if (kind === "audit") return records.map((record) => `<tr><td>${date(record.createdAt)}</td><td>${escapeHtml(record.adminEmail || record.adminUid)}</td><td>${escapeHtml(humanLabel(record.action))}</td><td>${escapeHtml(humanLabel(record.targetType))} / ${shortId(record.targetId)}</td><td>${escapeHtml(record.summary)}</td></tr>`);
  return records.map((record) => `<tr><td>${shortId(record.id)}</td><td>${escapeHtml(record.riderName || record.riderId || "—")}</td><td>${escapeHtml(record.driverName || record.driverId || "—")}</td><td>${route(record)}</td><td>${date(record.departureAt)}</td><td>${pill(record.status)} ${record.paymentStatus ? pill(record.paymentStatus) : ""}</td><td>${money(record.totalCents)}</td><td>${escapeHtml(record.disputeReason || record.refundReason || "")}</td></tr>`);
}

function recordHeaders(kind) {
  return kind === "rides" ? ["Ride", "Driver", "Riders", "Route", "Departure", "Status", "Seat price"] :
    kind === "audit" ? ["Time", "Admin", "Action", "Target", "Summary"] :
      ["Booking", "Rider", "Driver", "Route", "Departure", "Status", "Total", "Reason"];
}

async function loadRecords(kind, append = false) {
  const response = await run(`Loading ${titles[kind].toLowerCase()}…`, () => calls.adminListRecords({
    kind,
    cursor: append ? state.recordCursor : "",
  }));
  state.records = append ? [...state.records, ...response.data.records] : response.data.records;
  state.recordCursor = response.data.nextCursor;
  $("#records-title").textContent = titles[kind];
  $("#records-count").textContent = `${state.records.length} loaded`;
  $("#records-table").innerHTML = table(recordHeaders(kind), recordRows(kind, state.records));
  $("#records-next").hidden = !state.recordCursor;
}

async function showView(view) {
  state.currentView = view;
  document.querySelectorAll(".nav-item").forEach((button) => button.classList.toggle("active", button.dataset.view === view));
  document.querySelectorAll(".view").forEach((element) => {
    element.hidden = true;
    element.classList.remove("active-view");
  });
  const targetId = recordViews.has(view) ? "records-view" : `${view}-view`;
  const target = $(`#${targetId}`);
  target.hidden = false;
  target.classList.add("active-view");
  $("#section-title").textContent = titles[view];
  if (localPreview) {
    renderLocalPreview(view);
    return;
  }
  if (view === "overview") await loadOverview();
  else if (view === "users") await loadUsers();
  else if (view === "config") await loadConfig();
  else await loadRecords(view);
}

function renderLocalPreview(view) {
  const sampleUser = {
    uid: "preview-user", email: "driver@example.edu", firstName: "Jordan", lastName: "Lee", isAdmin: false,
    accountStatus: "active", emailVerified: true,
    verification: {
      identityStatus: "verified", driverStatus: "verified",
    },
  };
  if (view === "overview") {
    $("#summary-cards").innerHTML = [["Users", "128"], ["Rides", "46"], ["Bookings", "91"], ["Open disputes", "1"]]
      .map(([label, value]) => `<article class="summary-card"><span>${label}</span><strong>${value}</strong></article>`).join("");
  } else if (view === "users") {
    state.users = [sampleUser];
    state.userPageToken = "";
    renderUsers();
  } else if (view === "config") {
    $("#service-fee-type").value = "percentage";
    $("#service-fee-value").value = "8";
    $("#irs-mileage-rate").value = "0.76";
    $("#payment-expiration-hours").value = "24";
    $("#trip-auto-complete-hours").value = "48";
    $("#refund-rules").value = JSON.stringify([{minimumHoursBeforeTrip: 24, riderRefundPercentage: 50, platformPercentage: 8, driverPercentage: 42}], null, 2);
    $("#config-version").textContent = "m6-preview";
  } else {
    const sample = view === "rides" ? {
      id: "ride-preview", driverName: "Jordan Lee", originName: "Santa Barbara",
      destinationName: "San Francisco", departureAt: new Date().toISOString(), status: "published",
      pricePerSeatCents: 6000,
    } : view === "audit" ? {
      id: "audit-preview", createdAt: new Date().toISOString(), adminEmail: "admin@example.edu",
      action: "config.updated", targetType: "remote_config", targetId: "preview", summary: "Published business configuration",
    } : {
      id: "booking-preview", riderName: "Taylor Rivera", driverName: "Jordan Lee",
      originName: "Santa Barbara", destinationName: "San Francisco", departureAt: new Date().toISOString(),
      status: view === "disputes" ? "disputed" : "confirmed", paymentStatus: view === "refunds" ? "refunded" : "paid",
      totalCents: 6500, disputeReason: view === "disputes" ? "Trip did not occur" : "",
    };
    $("#records-title").textContent = titles[view];
    $("#records-count").textContent = "1 loaded";
    $("#records-table").innerHTML = table(recordHeaders(view), recordRows(view, [sample]));
    $("#records-next").hidden = true;
  }
}

function confirmAction({title, copy, reasonRequired = true, confirmLabel = "Confirm"}) {
  const dialog = $("#action-dialog");
  $("#dialog-title").textContent = title;
  $("#dialog-copy").textContent = copy;
  $("#dialog-reason").value = "";
  $("#dialog-reason").required = reasonRequired;
  $("#dialog-reason-label").hidden = !reasonRequired;
  $("#dialog-confirm").textContent = confirmLabel;
  dialog.showModal();
  return new Promise((resolve) => {
    dialog.addEventListener("close", () => resolve(dialog.returnValue === "default" ? $("#dialog-reason").value.trim() : null), {once: true});
  });
}

function openUserEditor(user) {
  $("#edit-user-uid").value = user.uid;
  $("#edit-first-name").value = user.firstName || "";
  $("#edit-last-name").value = user.lastName || "";
  $("#edit-email").value = user.email || "";
  $("#edit-age").value = Number(user.age || 18);
  $("#edit-gender").value = user.gender || "";
  $("#edit-school").value = user.school || "UC Santa Barbara";
  $("#edit-primary-role").value = user.primaryRole === "driver" ? "driver" : "rider";
  $("#user-editor-error").textContent = "";
  $("#user-editor-dialog").showModal();
}

document.addEventListener("click", async (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) return;
  const uid = button.dataset.uid;
  const action = button.dataset.action;
  try {
    const user = state.users.find((value) => value.uid === uid);
    if (action === "edit-user") {
      if (user) openUserEditor(user);
      return;
    }
    if (action === "delete-user") {
      $("#delete-user-uid").value = uid;
      $("#delete-user-reason").value = "";
      $("#delete-user-confirmation").value = "";
      $("#delete-user-error").textContent = "";
      $("#delete-user-dialog").showModal();
      return;
    }
    if (action === "verify-email") {
      const confirmed = window.confirm(`Manually verify ${user?.email || "this user's email"}?`);
      if (!confirmed) return;
      await run("Verifying student email…", () => calls.adminVerifyUserEmail({uid}));
      await loadUsers();
      setStatus("Student email verified.");
      return;
    }
    const status = action === "restore-user" ? "active" : action === "ban-user" ? "banned" : "suspended";
    const reason = await confirmAction({
      title: `${status === "active" ? "Restore" : status === "banned" ? "Ban" : "Suspend"} user`,
      copy: status === "active" ? "This account will be able to sign in and use SideCar again." : "Existing sessions will be revoked and app actions will stop.",
      reasonRequired: status !== "active",
      confirmLabel: status === "active" ? "Restore" : status === "banned" ? "Ban" : "Suspend",
    });
    if (reason === null) return;
    await run("Updating account status…", () => calls.adminSetUserStatus({uid, status, reason}));
    await loadUsers();
  } catch {
    // run() already displays a concise error.
  }
});

document.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-close-dialog]");
  if (button) $("#" + button.dataset.closeDialog).close();
});

$("#user-editor-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  $("#user-editor-error").textContent = "";
  const profile = {
    firstName: $("#edit-first-name").value.trim(),
    lastName: $("#edit-last-name").value.trim(),
    email: $("#edit-email").value.trim(),
    age: Number($("#edit-age").value),
    gender: $("#edit-gender").value.trim(),
    school: $("#edit-school").value.trim(),
    primaryRole: $("#edit-primary-role").value,
  };
  try {
    await run("Updating user account…", () => calls.adminUpdateUserProfile({uid: $("#edit-user-uid").value, profile}));
    $("#user-editor-dialog").close();
    await loadUsers();
    setStatus("User account updated.");
  } catch (error) {
    $("#user-editor-error").textContent = errorMessage(error);
  }
});

$("#delete-user-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  $("#delete-user-error").textContent = "";
  const confirmation = $("#delete-user-confirmation").value.trim();
  if (confirmation !== "DELETE") {
    $("#delete-user-error").textContent = "Type DELETE exactly to confirm.";
    return;
  }
  try {
    await run("Deleting user account…", () => calls.adminDeleteUserAccount({
      uid: $("#delete-user-uid").value,
      reason: $("#delete-user-reason").value.trim(),
      confirmation,
    }));
    $("#delete-user-dialog").close();
    await loadUsers();
    setStatus("User account deleted.");
  } catch (error) {
    $("#delete-user-error").textContent = errorMessage(error);
  }
});

$("#navigation").addEventListener("click", (event) => {
  const button = event.target.closest("button[data-view]");
  if (button) showView(button.dataset.view).catch(() => undefined);
});
$("#refresh").addEventListener("click", () => showView(state.currentView).catch(() => undefined));
$("#users-next").addEventListener("click", () => loadUsers(true).catch(() => undefined));
$("#records-next").addEventListener("click", () => loadRecords(state.currentView, true).catch(() => undefined));
$("#sign-out").addEventListener("click", () => signOut(auth));

$("#config-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  let refundRules;
  try {
    refundRules = JSON.parse($("#refund-rules").value);
  } catch {
    setStatus("Refund rules must be valid JSON.", true);
    return;
  }
  const config = {
    serviceFeeType: $("#service-fee-type").value,
    serviceFeeValue: Number($("#service-fee-value").value),
    driverFeePercentage: Number($("#driver-fee-percentage").value),
    stripeCardPercentage: Number($("#stripe-card-percentage").value),
    irsMileageRate: Number($("#irs-mileage-rate").value),
    paymentExpirationHours: Number($("#payment-expiration-hours").value),
    tripAutoCompleteHours: Number($("#trip-auto-complete-hours").value),
    refundRules,
  };
  const reason = await confirmAction({
    title: "Publish configuration",
    copy: "These values will become live in the app without a new build.",
    reasonRequired: false,
    confirmLabel: "Publish",
  });
  if (reason === null) return;
  try {
    await run("Publishing configuration…", () => calls.adminUpdateConfig({config}));
    await loadConfig();
    setStatus("Configuration published.");
  } catch {
    // run() already displays a concise error.
  }
});

$("#sign-in-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  $("#auth-error").textContent = "";
  const password = $("#password").value;
  try {
    await signInWithEmailAndPassword(auth, $("#email").value.trim(), password);
    state.temporaryPassword = password;
    $("#password").value = "";
  } catch (error) {
    state.temporaryPassword = "";
    $("#auth-error").textContent = errorMessage(error);
  }
});

$("#password-change-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const password = $("#new-password").value;
  const confirmation = $("#confirm-password").value;
  $("#password-change-error").textContent = "";
  if (password !== confirmation) {
    $("#password-change-error").textContent = "The passwords do not match.";
    return;
  }
  if (password.length < 12) {
    $("#password-change-error").textContent = "Use at least 12 characters.";
    return;
  }
  const user = auth.currentUser;
  if (!user?.email) {
    $("#password-change-error").textContent = "Sign in again with the temporary password.";
    return;
  }
  try {
    await changeInitialPassword({
      user,
      currentPassword: state.temporaryPassword,
      newPassword: password,
      credentialFactory: EmailAuthProvider.credential,
      reauthenticate: reauthenticateWithCredential,
      update: updatePassword,
      complete: () => calls.adminCompleteFirstLogin({}),
      onPasswordUpdated: () => {
        state.temporaryPassword = "";
      },
    });
    $("#new-password").value = "";
    $("#confirm-password").value = "";
    $("#password-change-view").hidden = true;
    $("#dashboard").hidden = false;
    $("#admin-email").textContent = user.email || "Administrator";
    await showView("overview");
  } catch (error) {
    if (error?.code === "auth/requires-recent-login") {
      state.temporaryPassword = "";
      await signOut(auth);
      $("#auth-error").textContent = "Your session expired. Sign in again with the temporary password.";
      return;
    }
    if (error?.passwordUpdated === true) {
      await signOut(auth);
      $("#auth-error").textContent = "Your password was saved. Sign in again with the new password to finish setup.";
      return;
    }
    $("#password-change-error").textContent = errorMessage(error);
  }
});

if (localPreview) {
  $("#sign-in-view").hidden = true;
  $("#dashboard").hidden = false;
  $("#admin-email").textContent = "preview@example.edu";
  await showView("overview");
} else onAuthStateChanged(auth, async (user) => {
  if (!user) {
    state.temporaryPassword = "";
    $("#dashboard").hidden = true;
    $("#password-change-view").hidden = true;
    $("#sign-in-view").hidden = false;
    return;
  }
  const token = await user.getIdTokenResult(true);
  if (token.claims.admin !== true) {
    $("#auth-error").textContent = "This account does not have administrator access.";
    await signOut(auth);
    return;
  }
  $("#sign-in-view").hidden = true;
  if (token.claims.mustChangePassword === true) {
    $("#dashboard").hidden = true;
    $("#password-change-view").hidden = false;
    return;
  }
  $("#password-change-view").hidden = true;
  $("#dashboard").hidden = false;
  state.currentAdminUid = user.uid;
  $("#admin-email").textContent = user.email || "Administrator";
  await showView("overview").catch(() => undefined);
});
