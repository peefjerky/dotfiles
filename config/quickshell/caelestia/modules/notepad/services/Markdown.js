.pragma library

// Markdown -> Qt rich text, for the rendered note.
//
// Qt's own MarkdownText import cannot be styled: headings get its fixed size
// ladder (an H1 lands at roughly twice the body), paragraphs get a flat 8px gap
// and there is no line-height at all. Its HTML export bakes those into inline
// styles on every span, so re-styling its output means regexing Qt internals.
// This renders the subset notes actually use with the shell's own type scale:
// headings, paragraphs, nested and task lists, quotes, fences, rules and the
// inline marks. Anything with a table falls back to Qt's importer (`hasTable`),
// which is the one construct this deliberately does not reimplement.
//
// `s` is the style: { size, family, mono, icon, fg, muted, accent, code, rule }.

function esc(t) {
    return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function inline(t, s) {
    // Code spans first, stashed so nothing inside them is treated as markup.
    const codes = [];
    t = t.replace(/`([^`]+)`/g, (m, c) => {
        codes.push(c);
        return `\u0000${codes.length - 1}\u0000`;
    });
    t = esc(t)
        .replace(/\*\*(.+?)\*\*|__(.+?)__/g, (m, a, b) => `<b>${a || b}</b>`)
        .replace(/(^|[^*\w])\*(?!\s)(.+?)\*(?!\w)|(^|\W)_(?!\s)(.+?)_(?!\w)/g, (m, p1, a, p2, b) => `${p1 ?? p2}<i>${a ?? b}</i>`)
        .replace(/~~(.+?)~~/g, "<s>$1</s>")
        .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, `<a href="$2" style="color:${s.accent}; text-decoration:none;">$1</a>`)
        .replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g, `$1<a href="$2" style="color:${s.accent}; text-decoration:none;">$2</a>`);
    return t.replace(/\u0000(\d+)\u0000/g, (m, i) => `<span style="font-family:'${s.mono}'; background-color:${s.code};">&nbsp;${esc(codes[i])}&nbsp;</span>`);
}

function hasTable(src) {
    return /^\s*\|.*\|\s*$/m.test(src) && /^\s*\|?\s*:?-{3,}:?\s*\|/m.test(src);
}

function render(src, s) {
    const lines = src.split("\n");
    const out = [];
    // Qt multiplies this onto the font's own line spacing (~1.2x), so 118% lands
    // near 1.4 effective -- a 145% here read as double-spaced.
    const lh = "line-height:118%;";
    // Font sizes in pt (what Tokens fonts carry); spacing in px, which is the
    // only length unit Qt's rich-text margins reliably honour.
    const pt = n => `${(s.size * n).toFixed(1)}pt`;
    const px = n => `${Math.round(s.size * n * 4 / 3)}px`;
    let para = [];
    let lists = []; // open <ul>/<ol> indents, innermost last

    function flushPara() {
        if (!para.length)
            return;
        out.push(`<p style="margin-top:0; margin-bottom:${px(0.75)}; ${lh}">${inline(para.join(" "), s)}</p>`);
        para = [];
    }

    function closeLists(toDepth) {
        while (lists.length > toDepth)
            out.push(`</${lists.pop().tag}>`);
    }

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];

        // Fenced code: verbatim until the closing fence.
        const fence = line.match(/^\s*(```|~~~)/);
        if (fence) {
            flushPara();
            closeLists(0);
            const body = [];
            while (++i < lines.length && !lines[i].trim().startsWith(fence[1]))
                body.push(esc(lines[i]) || "&nbsp;");
            out.push(`<pre style="font-family:'${s.mono}'; background-color:${s.code}; margin-top:0; margin-bottom:${px(0.75)};">${body.join("<br/>")}</pre>`);
            continue;
        }

        if (!line.trim()) {
            flushPara();
            closeLists(0);
            continue;
        }

        const h = line.match(/^(#{1,6})\s+(.*?)\s*#*\s*$/);
        if (h) {
            flushPara();
            closeLists(0);
            // A 1.2 ratio, not Qt's ~2x: in a tool, a heading is a label for the
            // block under it, not a poster. More space above than below, so it
            // binds to what follows.
            const scale = [1.44, 1.2, 1.05, 1, 1, 1][h[1].length - 1];
            const top = out.length ? px(1.1) : "0";
            out.push(`<p style="margin-top:${top}; margin-bottom:${px(0.4)}; ${lh}"><span style="font-size:${pt(scale)}; font-weight:${h[1].length < 3 ? 700 : 600};">${inline(h[2], s)}</span></p>`);
            continue;
        }

        if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) {
            flushPara();
            closeLists(0);
            out.push(`<hr style="background-color:${s.rule}; margin-top:${px(0.5)}; margin-bottom:${px(1)};"/>`);
            continue;
        }

        const q = line.match(/^\s*>\s?(.*)$/);
        if (q) {
            flushPara();
            closeLists(0);
            out.push(`<p style="margin-top:0; margin-bottom:${px(0.75)}; margin-left:${px(1.2)}; color:${s.muted}; ${lh}">${inline(q[1], s)}</p>`);
            continue;
        }

        const li = line.match(/^(\s*)([-*+]|\d+[.)])\s+(.*)$/);
        if (li) {
            flushPara();
            const indent = li[1].replace(/\t/g, "    ").length;
            const tag = /\d/.test(li[2]) ? "ol" : "ul";
            while (lists.length && indent < lists[lists.length - 1].indent)
                out.push(`</${lists.pop().tag}>`);
            if (!lists.length || indent > lists[lists.length - 1].indent) {
                lists.push({ indent, tag });
                out.push(`<${tag} style="margin-top:0; margin-bottom:${px(0.5)}; -qt-list-indent:${lists.length};">`);
            }

            let body = li[3];
            const task = body.match(/^\[([ xX])\]\s+(.*)$/);
            if (task) {
                // Material Symbols ligatures, so the box is drawn in the same icon
                // set as the rest of the shell. The link is how a click maps back
                // to source line i.
                const done = task[1] !== " ";
                const box = `<a href="tg:${i}" style="text-decoration:none; color:${done ? s.accent : s.muted};"><span style="font-family:'${s.icon}';">${done ? "check_box" : "check_box_outline_blank"}</span></a>`;
                body = `${box}&nbsp;&nbsp;${done ? `<span style="color:${s.muted};"><s>${inline(task[2], s)}</s></span>` : inline(task[2], s)}`;
            } else {
                body = inline(body, s);
            }
            out.push(`<li style="margin-bottom:${px(0.25)}; ${lh}">${body}</li>`);
            continue;
        }

        // A continuation line inside a list item stays in that item.
        if (lists.length && /^\s+\S/.test(line) && !para.length) {
            out[out.length - 1] = out[out.length - 1].replace(/<\/li>$/, ` ${inline(line.trim(), s)}</li>`);
            continue;
        }

        closeLists(0);
        para.push(line.trim());
    }
    flushPara();
    closeLists(0);

    return `<div style="font-family:'${s.family}'; font-size:${pt(1)}; color:${s.fg};">${out.join("\n")}</div>`;
}
