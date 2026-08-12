import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

test("exports the Labs landing page", async () => {
  const html = await readFile(new URL("out/index.html", root), "utf8");
  assert.match(html, /Hybrid Solutions Cloud Labs/i);
  assert.match(html, /Useful things/i);
  assert.match(html, /AzureScout/i);
  assert.match(html, /Homestead Foundry/i);
  assert.match(html, /Vault Prospector/i);
  assert.match(html, /Project Marvin/i);
  assert.match(html, /Hybrid Infrastructure Toolkit/i);
  assert.match(html, /Azure Monitor ITSM/i);
  assert.match(html, /Hybrid Health Monitoring/i);
  assert.match(html, /catalog\.public_projects.{0,80}>7</is);
  assert.doesNotMatch(html, /status-active/i);
  assert.equal((html.match(/status-preview/g) ?? []).length, 3);
  assert.equal((html.match(/status-in-the-lab/g) ?? []).length, 4);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape/i);
});

test("ships the static Pages marker", async () => {
  await access(new URL("out/.nojekyll", root));
});
