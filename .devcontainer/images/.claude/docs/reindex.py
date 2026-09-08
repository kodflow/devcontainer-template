#!/usr/bin/env python3
"""Rebuild the ~/.claude/docs knowledge-base index.

Two outputs:
  INDEX.json  machine lookup for /search Phase 1 (one read, no directory walk)
  INDEX.md    the same, human-readable, with a staleness column

Every document gets YAML frontmatter carrying a `verified` date. That date is
what makes local-first honest: a pattern doc verified two years ago is a
hypothesis to confirm against the web, not a validated source. /search --refresh
restamps a doc after re-checking it; nothing else may touch the date.
"""
import json, os, re, subprocess, sys, datetime, pathlib

# The docs root: an explicit argument first (so the template repo can index its
# own source tree), then $CLAUDE_DOCS_DIR, then the deployed location. Hardcoding
# the deployed path made this reindex the wrong tree when run from a checkout.
_args = [a for a in sys.argv[1:] if not a.startswith("--")]
ROOT = pathlib.Path(_args[0]).expanduser() if _args else pathlib.Path(
    os.environ.get("CLAUDE_DOCS_DIR", os.path.expanduser("~/.claude/docs"))
).expanduser()
if not ROOT.is_dir():
    sys.exit(f"docs root not found: {ROOT}")
SKIP_NAMES = {"README.md", "CLAUDE.md", "TEMPLATE-PATTERN.md", "TEMPLATE-README.md",
              "INDEX.md"}
TODAY = datetime.date.today()
# A pattern's *shape* is stable; its code examples and tool advice are not.
TTL_DAYS = {"architectural": 730, "behavioral": 1095, "creational": 1095,
            "structural": 1095, "functional": 1095, "principles": 1095,
            "ddd": 730, "enterprise": 730, "messaging": 730, "integration": 545,
            "concurrency": 545, "performance": 545, "resilience": 545,
            "testing": 365, "security": 180, "cloud": 365, "devops": 180,
            "conventions": 365, "refactoring": 730}
DEFAULT_TTL = 365

def split_fm(text):
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            return text[4:end + 1], text[end + 5:]
    return None, text

def mtime_date(p):
    try:
        out = subprocess.run(["git", "log", "-1", "--format=%cs", "--", str(p)],
                             cwd=ROOT, capture_output=True, text=True, timeout=5)
        if out.returncode == 0 and out.stdout.strip():
            return out.stdout.strip()
    except Exception:
        pass
    return datetime.date.fromtimestamp(p.stat().st_mtime).isoformat()

def summary_of(body):
    m = re.search(r"^>\s*(.+)$", body, re.M)          # the "> one-liner" convention
    if m:
        return m.group(1).strip()
    for line in body.split("\n"):
        line = line.strip()
        if line and not line.startswith(("#", "```", "|", ">", "-", "*")):
            return line[:200]
    return ""

# Section headings that every document shares carry no discriminating power,
# so they would match every query and make the index useless for ranking.
STOP_TAGS = {
    "structure", "sources", "related-patterns", "when-to-use", "when-not-to-use",
    "best-practices", "common-mistakes", "principle", "overview", "summary",
    "example", "examples", "usage", "implementation", "trade-offs", "tradeoffs",
    "pros-and-cons", "anti-patterns", "references", "see-also", "checklist",
    "go-implementation", "python-implementation", "rust-implementation",
    "testing", "variants", "definition", "context", "problem", "solution",
    "consequences", "applicability", "participants", "collaborations",
}

def tags_of(body, name, category):
    t = {name, category}
    for m in re.finditer(r"^#{2,3}\s+(.+)$", body, re.M):
        h = m.group(1).strip().lower()
        if 3 <= len(h) <= 40 and not h.startswith(("level", "phase", "step")):
            slug = re.sub(r"[^a-z0-9]+", "-", h).strip("-")
            if slug and slug not in STOP_TAGS:
                t.add(slug)
    langs = {"go": r"```go", "python": r"```py", "rust": r"```rust",
             "typescript": r"```ts", "java": r"```java", "c": r"```c\b",
             "cpp": r"```cpp", "sql": r"```sql", "yaml": r"```ya?ml",
             "hcl": r"```hcl", "bash": r"```(bash|sh)\b"}
    for lang, pat in langs.items():
        if re.search(pat, body, re.I):
            t.add(f"lang:{lang}")
    return sorted(x for x in t if x)

write = "--check" not in sys.argv
entries = []
for path in sorted(ROOT.rglob("*.md")):
    if path.name in SKIP_NAMES or path.parent == ROOT:
        continue
    category = path.parent.name
    name = path.stem
    raw = path.read_text()
    fm_txt, body = split_fm(raw)

    verified = None
    if fm_txt:
        m = re.search(r"^verified:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})", fm_txt, re.M)
        if m:
            verified = m.group(1)
    if verified is None:
        verified = mtime_date(path)

    ttl = TTL_DAYS.get(category, DEFAULT_TTL)
    age = (TODAY - datetime.date.fromisoformat(verified)).days
    status = "fresh" if age <= ttl else ("stale" if age <= ttl * 2 else "expired")

    fm = {
        "title": re.search(r"^#\s+(.+)$", body, re.M).group(1).strip()
                 if re.search(r"^#\s+(.+)$", body, re.M) else name,
        "category": category,
        "verified": verified,
        "ttl_days": ttl,
        "tags": tags_of(body, name, category),
    }

    if write:
        lines = [f"title: {json.dumps(fm['title'])}",
                 f"category: {category}",
                 f"verified: {verified}   # /search --refresh restamps this",
                 f"ttl_days: {ttl}",
                 "tags: [" + ", ".join(fm["tags"]) + "]"]
        path.write_text("---\n" + "\n".join(lines) + "\n---\n\n" + body.lstrip("\n"))

    entries.append({"path": str(path.relative_to(ROOT)), "name": name,
                    "category": category, "title": fm["title"],
                    "summary": summary_of(body), "tags": fm["tags"],
                    "verified": verified, "age_days": age,
                    "ttl_days": ttl, "status": status,
                    "lines": body.count("\n") + 1})

index = {"generated": TODAY.isoformat(), "root": str(ROOT), "count": len(entries),
         "by_status": {s: sum(1 for e in entries if e["status"] == s)
                       for s in ("fresh", "stale", "expired")},
         "categories": sorted({e["category"] for e in entries}),
         "documents": entries}

if write:
    (ROOT / "INDEX.json").write_text(json.dumps(index, indent=1, ensure_ascii=False))
    md = ["# Knowledge base index", "",
          f"Generated {TODAY.isoformat()} · {len(entries)} documents · "
          f"{index['by_status']['fresh']} fresh, {index['by_status']['stale']} stale, "
          f"{index['by_status']['expired']} expired.", "",
          "`status` is `verified` age against the category TTL. **stale** and "
          "**expired** documents are hypotheses, not validated sources: "
          "`/search` must confirm them against the web before citing them, and "
          "`/search --refresh <topic>` restamps them.", ""]
    for cat in index["categories"]:
        docs = [e for e in entries if e["category"] == cat]
        md += [f"## {cat} ({len(docs)})", "",
               "| Doc | Summary | Verified | Status |", "|---|---|---|---|"]
        for e in sorted(docs, key=lambda x: x["name"]):
            mark = {"fresh": "fresh", "stale": "**stale**", "expired": "**EXPIRED**"}[e["status"]]
            md.append(f"| [`{e['name']}`]({e['path']}) | {e['summary'][:90]} | {e['verified']} | {mark} |")
        md.append("")
    (ROOT / "INDEX.md").write_text("\n".join(md))

print(json.dumps({k: index[k] for k in ("generated", "count", "by_status", "categories")}, indent=1))
