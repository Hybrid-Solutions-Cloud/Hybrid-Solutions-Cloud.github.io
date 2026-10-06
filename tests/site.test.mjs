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
  assert.match(html, /Hyper-V Surveyor/i);
  assert.match(html, /Stagecoach/i);
  assert.match(html, /Hyper-V Trailwright/i);
  assert.match(html, /Azure Local Trailwright/i);
  assert.match(html, /href=\"\/hyperv-trailwright\/\"/i);
  assert.match(html, /href=\"\/azurelocal-trailwright\/\"/i);
  assert.match(html, /href="\/hyperv-surveyor\/"/i);
  assert.match(html, /href="\/stagecoach\/"/i);
  assert.match(html, /hsc-labs-logo\.png/i);
  assert.match(html, /catalog\.public_projects.{0,80}>11</is);
  assert.doesNotMatch(html, /status-active/i);
  assert.equal((html.match(/status-preview/g) ?? []).length, 4);
  assert.equal((html.match(/status-in-the-lab/g) ?? []).length, 7);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape/i);
});

test("ships the static Pages marker", async () => {
  await access(new URL("out/.nojekyll", root));
});

 test("catalog order and maturity match the published products", async () => {
 const html = await readFile(new URL("out/index.html", root), "utf8");
 const cards = [...html.matchAll(/<article class="project-card[\s\S]*?<\/article>/g)].map(m => m[0]);
 const expected = ["AzureScout","Hyper-V Surveyor","Vault Prospector","Hyper-V Trailwright","Azure Local Trailwright","Homestead Foundry","Project Marvin","Hybrid Infrastructure Toolkit","Azure Monitor ITSM","Hybrid Health Monitoring","Stagecoach"];
 assert.deepEqual(cards.map(card => card.match(/<h3>([^<]+)<\/h3>/)[1]), expected);
 const previews = new Set(["AzureScout","Hyper-V Surveyor","Vault Prospector","Homestead Foundry"]);
 for (const card of cards) {
 const name = card.match(/<h3>([^<]+)<\/h3>/)[1];
 assert.ok(card.includes(previews.has(name) ? 'status-preview' : 'status-in-the-lab'), name);
 }
});
