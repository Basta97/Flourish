"""Builds the static website in site/ for GitHub Pages.

    python3 tool/build_site.py

- site/privacy/index.html is generated from docs/privacy-policy.md, so the
  published policy never drifts from the reviewed draft.
- site/assets/ gets the icon, web-sized screenshots and the bundled fonts.
  The site loads nothing from other servers.
site/index.html and site/styles.css are written by hand.
"""
import html
import os
import re
import shutil

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SITE = os.path.join(ROOT, "site")
ASSETS = os.path.join(SITE, "assets")


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\*([^*]+)\*", r"<em>\1</em>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    # Bare URLs become links (skip ones already inside an href).
    # Trailing sentence punctuation is not part of the URL.
    text = re.sub(
        r'(?<!href=")(?<!">)(https://[^\s<)]+?)(?=[.,;:]?(?:\s|<|$))',
        r'<a href="\1">\1</a>',
        text,
    )
    return text


def markdown(md):
    """Just enough Markdown for docs/privacy-policy.md."""
    out, lines, i = [], md.splitlines(), 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.startswith(">"):
            block = []
            while i < len(lines) and lines[i].startswith(">"):
                # Drop "> " only, so indented list continuations survive.
                block.append(re.sub(r"^> ?", "", lines[i]))
                i += 1
            out.append('<aside class="draft">' + markdown("\n".join(block)) + "</aside>")
            continue
        m = re.match(r"(#{1,4}) (.*)", line)
        if m:
            n = len(m.group(1))
            out.append(f"<h{n}>{inline(m.group(2))}</h{n}>")
            i += 1
            continue
        if line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            head, body = rows[0], rows[1:]
            out.append(
                "<table><thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in head)
                + "</tr></thead><tbody>"
                + "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in body)
                + "</tbody></table>"
            )
            continue
        if re.match(r"\s*(- |\d+\. )", line):
            ordered = bool(re.match(r"\s*\d+\. ", line))
            items = []
            while i < len(lines) and (re.match(r"\s*(- |\d+\. )", lines[i]) or (lines[i].startswith("  ") and items)):
                if re.match(r"\s*(- |\d+\. )", lines[i]):
                    items.append(re.sub(r"\s*(- |\d+\. )", "", lines[i], count=1))
                else:
                    items[-1] += " " + lines[i].strip()
                i += 1
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{inline(x)}</li>" for x in items) + f"</{tag}>")
            continue
        para = []
        while i < len(lines) and lines[i].strip() and not re.match(r"(#{1,4} |>|\||\s*- |\s*\d+\. )", lines[i]):
            # Two trailing spaces mark a hard line break.
            text = inline(lines[i].strip())
            para.append(text + ("<br>" if lines[i].endswith("  ") else " "))
            i += 1
        out.append(f"<p>{''.join(para).strip()}</p>")
    return "\n".join(out)


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Privacy policy · Flourish</title>
<meta name="description" content="How Flourish handles your information.">
<link rel="icon" href="../assets/icon-192.png">
<link rel="stylesheet" href="../styles.css">
</head>
<body class="doc">
<header class="bar"><a class="brand" href="../"><img src="../assets/icon-192.png" alt="" width="32" height="32">Flourish</a></header>
<main class="prose">
{body}
</main>
<footer class="foot"><a href="../">Home</a> · <a href="./">Privacy policy</a></footer>
</body>
</html>
"""


def build_privacy():
    md = open(os.path.join(ROOT, "docs", "privacy-policy.md"), encoding="utf-8").read()
    out = os.path.join(SITE, "privacy")
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "index.html"), "w", encoding="utf-8") as f:
        f.write(PAGE.replace("{body}", markdown(md)))
    print("wrote site/privacy/index.html")


def build_assets():
    os.makedirs(os.path.join(ASSETS, "fonts"), exist_ok=True)
    icon = Image.open(os.path.join(ROOT, "assets", "icon", "app_icon.png")).convert("RGB")
    for size in (192, 512):
        icon.resize((size, size), Image.LANCZOS).save(os.path.join(ASSETS, f"icon-{size}.png"), optimize=True)
    for name in ("01-home", "02-payment-alerts", "03-reports", "04-budgets", "05-privacy"):
        src = Image.open(os.path.join(ROOT, "store", "google-play", "marketing", f"{name}.png")).convert("RGB")
        src.resize((540, 960), Image.LANCZOS).save(os.path.join(ASSETS, f"{name}.jpg"), quality=86, optimize=True)
    for rel in ("space_grotesk/SpaceGrotesk-Bold.ttf", "manrope/Manrope-Medium.ttf", "manrope/Manrope-Bold.ttf"):
        shutil.copy(os.path.join(ROOT, "assets", "fonts", rel), os.path.join(ASSETS, "fonts", os.path.basename(rel)))
    shutil.copy(os.path.join(ROOT, "assets", "fonts", "manrope", "OFL.txt"), os.path.join(ASSETS, "fonts", "OFL.txt"))
    shutil.copy(os.path.join(ROOT, "store", "social", "facebook-cover-1640x856.png"), os.path.join(ASSETS, "share.png"))
    print("wrote site/assets/")


if __name__ == "__main__":
    build_assets()
    build_privacy()
