import assert from "node:assert/strict";
import test from "node:test";

import {changeInitialPassword} from "../hosting/admin/password_flow.js";

test("reauthenticates immediately before changing a first-login password", async () => {
  const calls = [];
  const user = {
    email: "admin@example.com",
    async getIdToken(force) {
      calls.push(["refresh", force]);
    },
  };

  await changeInitialPassword({
    user,
    currentPassword: "temporary-password",
    newPassword: "permanent-password",
    credentialFactory(email, password) {
      calls.push(["credential", email, password]);
      return {email, password};
    },
    async reauthenticate(receivedUser) {
      assert.equal(receivedUser, user);
      calls.push(["reauthenticate"]);
    },
    async update(receivedUser, password) {
      assert.equal(receivedUser, user);
      calls.push(["update", password]);
    },
    async complete() {
      calls.push(["complete"]);
    },
    onPasswordUpdated() {
      calls.push(["clear-temporary-password"]);
    },
  });

  assert.deepEqual(calls, [
    ["credential", "admin@example.com", "temporary-password"],
    ["reauthenticate"],
    ["update", "permanent-password"],
    ["clear-temporary-password"],
    ["complete"],
    ["refresh", true],
  ]);
});

test("marks a completion failure as occurring after the password update", async () => {
  const expected = new Error("completion failed");

  await assert.rejects(
    changeInitialPassword({
      user: {email: "admin@example.com", async getIdToken() {}},
      currentPassword: "",
      newPassword: "permanent-password",
      credentialFactory() {},
      async reauthenticate() {},
      async update() {},
      async complete() {
        throw expected;
      },
    }),
    (error) => error === expected && error.passwordUpdated === true,
  );
});
