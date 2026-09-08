import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const root = new URL("../hosting/", import.meta.url);

test("legal pages are public HTML with final publication dates and cross-links", async () => {
  const [privacy, terms, deletion] = await Promise.all([
    readFile(new URL("privacy/index.html", root), "utf8"),
    readFile(new URL("terms/index.html", root), "utf8"),
    readFile(new URL("delete-account/index.html", root), "utf8"),
  ]);
  for (const page of [privacy, terms, deletion]) {
    assert.match(page, /AMKAI INC/);
    assert.doesNotMatch(page, /\[DATE YOU PUBLISH\]/);
  }
  assert.match(privacy, /September 3, 2026/);
  assert.match(privacy, /\/delete-account\//);
  assert.match(terms, /at least 18/);
  assert.match(terms, /10 minutes/);
  assert.match(deletion, /Profile/);
  assert.match(deletion, /type <strong>DELETE<\/strong>/i);
});

test("admin dashboard exposes guarded edit and deletion controls", async () => {
  const [html, script] = await Promise.all([
    readFile(new URL("admin/index.html", root), "utf8"),
    readFile(new URL("admin/app.js", root), "utf8"),
  ]);
  assert.match(html, /id="user-editor-dialog"/);
  assert.match(html, /id="delete-user-confirmation"/);
  assert.match(script, /adminUpdateUserProfile/);
  assert.match(script, /adminDeleteUserAccount/);
  assert.match(script, /adminVerifyUserEmail/);
  assert.match(script, /data-action="verify-email"/);
  assert.match(script, /Student email verified\./);
  assert.match(script, /class="user-photo"/);
  assert.match(script, />Verify email</);
  assert.match(html, /id="driver-fee-percentage"/);
  assert.match(script, /confirmation !== "DELETE"/);
});
