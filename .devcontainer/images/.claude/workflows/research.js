export const meta = {
  name: "research",
  description:
    "Local-first documentation research: fan-out web search on the gaps the local docs do not cover, fetch + extract, adversarially verify, synthesize a cited report. Returns data only — the /search skill is the sole writer of .claude/contexts/<slug>.md.",
  phases: [
    {
      title: "Scope",
      detail: "Decompose the query (and the local gaps) into 3-5 search angles",
    },
    {
      title: "Search",
      detail:
        "One WebSearch agent per angle, official-domain whitelist enforced",
    },
    {
      title: "Fetch",
      detail:
        "URL-dedup, fetch top sources, extract falsifiable claims + citation",
    },
    {
      title: "Verify",
      detail: "3-vote adversarial verification per claim (2/3 refute = killed)",
    },
    {
      title: "Synthesize",
      detail: "Merge local + web, rank by confidence, cite sources",
    },
  ],
};

// args: { query, gaps?, whitelist?, slug? } passed by the /search skill after the
// local-first gate decides external complement is needed. The workflow NEVER writes
// to disk (GI7) — it returns { context_md, sources, confidence_map } and the skill
// writes .claude/contexts/<slug>.md.
const A =
  args && typeof args === "object" ? args : { query: String(args || "") };
const QUERY = (A.query || "").trim();
const GAPS = Array.isArray(A.gaps) ? A.gaps : [];
const WHITELIST = Array.isArray(A.whitelist) ? A.whitelist : [];
const VOTES = 3,
  REFUTE_TO_KILL = 2,
  MAX_FETCH = 15,
  MAX_VERIFY = 20;

if (!QUERY) {
  return {
    error:
      "No query. Pass it as args: Workflow({name:'research', args:{query:'<q>', gaps:[…], whitelist:[…]}}).",
  };
}

const ANGLE_SCHEMA = {
  type: "object",
  required: ["angles"],
  properties: {
    angles: {
      type: "array",
      minItems: 3,
      maxItems: 5,
      items: {
        type: "object",
        required: ["label", "query"],
        properties: { label: { type: "string" }, query: { type: "string" } },
      },
    },
  },
};
const SEARCH_SCHEMA = {
  type: "object",
  required: ["results"],
  properties: {
    results: {
      type: "array",
      maxItems: 6,
      items: {
        type: "object",
        required: ["url", "title", "relevance"],
        properties: {
          url: { type: "string" },
          title: { type: "string" },
          snippet: { type: "string" },
          relevance: { enum: ["high", "medium", "low"] },
        },
      },
    },
  },
};
const EXTRACT_SCHEMA = {
  type: "object",
  required: ["claims", "sourceQuality"],
  properties: {
    sourceQuality: {
      enum: ["primary", "secondary", "blog", "forum", "unreliable"],
    },
    claims: {
      type: "array",
      maxItems: 5,
      items: {
        type: "object",
        required: ["claim", "quote"],
        properties: { claim: { type: "string" }, quote: { type: "string" } },
      },
    },
  },
};
const VERDICT_SCHEMA = {
  type: "object",
  required: ["refuted", "confidence"],
  properties: {
    refuted: { type: "boolean" },
    evidence: { type: "string" },
    confidence: { enum: ["high", "medium", "low"] },
  },
};

const wl = WHITELIST.length
  ? `Restrict to official domains ONLY: ${WHITELIST.join(", ")}. Reject blogs, Medium, Stack Overflow.`
  : "Prefer official documentation domains; reject blogs/forums.";

// Phase 0 — Scope
phase("Scope");
const scope = await agent(
  `Decompose this research query into 3-5 search angles. Query: "${QUERY}". ` +
    (GAPS.length
      ? `The local docs already cover most of it; focus the angles on these GAPS: ${JSON.stringify(GAPS)}. `
      : "") +
    `Each angle = a label + a concrete web search query.`,
  { label: "scope:angles", phase: "Scope", schema: ANGLE_SCHEMA },
);
const angles = scope && scope.angles ? scope.angles : [];

// Phases Search → Fetch+Extract (pipeline, no barrier)
const perAngle = await pipeline(
  angles,
  (a) =>
    agent(
      `WebSearch for: ${a.query}. ${wl} Return the most relevant official results.`,
      { label: `search:${a.label}`, phase: "Search", schema: SEARCH_SCHEMA },
    ),
  (res, a) => {
    const urls = ((res && res.results) || [])
      .slice(0, MAX_FETCH)
      .map((r) => r.url);
    return { angle: a.label, urls, results: (res && res.results) || [] };
  },
);

// URL-dedup across angles
const seen = new Set(),
  fetchList = [];
for (const pa of perAngle.filter(Boolean)) {
  for (const r of pa.results) {
    if (!r.url || seen.has(r.url)) continue;
    seen.add(r.url);
    fetchList.push(r);
  }
}
const toFetch = fetchList.slice(0, MAX_FETCH);
log(`${angles.length} angles → ${toFetch.length} unique sources to fetch`);

// Fetch + extract claims (parallel)
phase("Fetch");
const extracted = await parallel(
  toFetch.map(
    (r) => () =>
      agent(
        `Fetch ${r.url} (WebFetch) and extract up to 5 FALSIFIABLE claims answering "${QUERY}". ` +
          `Each claim needs a verbatim quote. Rate the source quality. ${wl}`,
        {
          label: `fetch:${r.url.slice(0, 40)}`,
          phase: "Fetch",
          schema: EXTRACT_SCHEMA,
        },
      ).then((x) => ({ url: r.url, title: r.title, ...(x || {}) })),
  ),
);
const claims = [];
for (const e of extracted.filter(Boolean)) {
  for (const c of e.claims || [])
    claims.push({ ...c, url: e.url, sourceQuality: e.sourceQuality });
}
const toVerify = claims.slice(0, MAX_VERIFY);

// Verify — 3-vote adversarial
phase("Verify");
const verified = await parallel(
  toVerify.map(
    (c) => () =>
      parallel(
        Array.from(
          { length: VOTES },
          (_, i) => () =>
            agent(
              `Try to REFUTE this claim with independent reasoning/sources: "${c.claim}" (quote: "${c.quote}"). ` +
                `Refute if unsupported, contradicted, or you cannot confirm it. ${wl}`,
              {
                label: `verify:${(c.claim || "").slice(0, 30)}#${i + 1}`,
                phase: "Verify",
                schema: VERDICT_SCHEMA,
              },
            ),
        ),
      ).then((votes) => {
        const v = votes.filter(Boolean);
        const refutes = v.filter((x) => x.refuted).length;
        return {
          ...c,
          survived: refutes < REFUTE_TO_KILL,
          confidence: refutes === 0 ? "high" : "medium",
        };
      }),
  ),
);
const confirmed = verified.filter(Boolean).filter((c) => c.survived);

// Synthesize — cited report (returned, NOT written; the skill writes the context file)
phase("Synthesize");
const report = await agent(
  `Synthesize a concise, cited research report answering "${QUERY}" from these VERIFIED claims: ` +
    `${JSON.stringify(confirmed)}. Group by theme, cite each claim's source URL inline, ` +
    `and end with a "Sources:" list. Mark confidence per finding. Markdown.`,
  { label: "synthesize:report", phase: "Synthesize" },
);

return {
  context_md: report,
  sources: [...new Set(confirmed.map((c) => c.url))],
  confidence_map: confirmed.map((c) => ({
    claim: c.claim,
    confidence: c.confidence,
    url: c.url,
  })),
  stats: {
    angles: angles.length,
    fetched: toFetch.length,
    claims: claims.length,
    confirmed: confirmed.length,
  },
};
