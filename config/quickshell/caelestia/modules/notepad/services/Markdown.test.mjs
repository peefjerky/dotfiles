// node Markdown.test.mjs -- checks the note renderer without starting the shell.
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const src = readFileSync(new URL("./Markdown.js", import.meta.url), "utf8").replace(".pragma library", "");
const Md = new Function(`${src}; return { render, hasTable };`)();
const s = { size: 12, family: "Sans", mono: "Mono", icon: "Icons", fg: "#fff", muted: "#888", accent: "#f80", code: "#222", rule: "#444" };
const r = t => Md.render(t, s);

// Headings use the 1.2 ladder, not Qt's ~2x, and the first one gets no top gap.
assert.match(r("# Title"), /margin-top:0;.*font-size:17\.3pt/);
assert.match(r("para\n\n## Sub"), /margin-top:18px.*font-size:14\.4pt/s);

// Paragraph lines join; a blank line splits.
assert.equal((r("a\nb\n\nc").match(/<p /g) || []).length, 2);

// Inline marks, and markup inside code spans stays literal.
assert.match(r("**b** *i* _j_ ~~s~~"), /<b>b<\/b> <i>i<\/i> <i>j<\/i> <s>s<\/s>/);
assert.match(r("`a*b*<c>`"), /&nbsp;a\*b\*&lt;c&gt;&nbsp;/);
assert.doesNotMatch(r("snake_case_name and 2*3*4"), /<i>/);

// Links, bare URLs, and HTML in the note is escaped, never interpreted.
assert.match(r("[x](https://a.b)"), /<a href="https:\/\/a\.b"[^>]*>x<\/a>/);
assert.match(r("see https://a.b/c?d=1&e=2"), /href="https:\/\/a\.b\/c\?d=1&amp;e=2"/);
assert.match(r("<script>"), /&lt;script&gt;/);

// Nested lists open and close in order; tasks link back to their source line.
const list = r("- a\n  - b\n- c");
assert.deepEqual(list.match(/<\/?ul|<li/g), ["<ul", "<li", "<ul", "<li", "</ul", "<li", "</ul"]);
assert.match(r("x\n\n- [ ] todo"), /href="tg:2".*check_box_outline_blank/);
assert.match(r("- [x] done"), /check_box<.*<s>done<\/s>/);
assert.match(r("1. one\n2. two"), /<ol/);

// Fences are verbatim, quotes and rules render.
assert.match(r("```\n# not a heading\n```"), /<pre[^>]*># not a heading<\/pre>/);
assert.match(r("> q"), /margin-left:19px;.*>q<\/p>/);
assert.match(r("---"), /<hr /);

// Tables are left to Qt's importer.
assert.equal(Md.hasTable("| a | b |\n|---|---|\n| 1 | 2 |"), true);
assert.equal(Md.hasTable("a | b"), false);

console.log("ok");
