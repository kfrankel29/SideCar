import assert from "node:assert/strict";
import test from "node:test";

import {dueTripReminderMinutes} from "./reminder_schedule.js";

test("returns every configured reminder window", () => {
  assert.deepEqual(dueTripReminderMinutes(24 * 60), [24 * 60]);
  assert.deepEqual(dueTripReminderMinutes(30), [30]);
  assert.deepEqual(dueTripReminderMinutes(10), [10]);
});

test("does not return reminders outside their windows", () => {
  assert.deepEqual(dueTripReminderMinutes(20), []);
  assert.deepEqual(dueTripReminderMinutes(4), []);
  assert.deepEqual(dueTripReminderMinutes(-1), []);
});
