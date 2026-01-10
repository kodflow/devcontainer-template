# Search - Documentation Research (RLM-Enhanced)

$ARGUMENTS

---

## Description

Recherche d'informations sur les documentations officielles avec patterns RLM (Recursive Language Models).

**Patterns RLM appliqués :**
- **Peek** - Aperçu rapide avant analyse complète
- **Grep** - Filtrage par keywords avant fetch sémantique
- **Partition+Map** - Recherches parallèles multi-domaines
- **Summarize** - Résumé progressif des sources
- **Programmatic** - Génération structurée du context

**Principe** : Fiabilité > Quantité. Décomposer → Paralléliser → Synthétiser.

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<query>` | Nouvelle recherche sur le sujet |
| `--append` | Ajoute au contexte existant |
| `--status` | Affiche le contexte actuel |
| `--clear` | Supprime le fichier .context.md |
| `--help` | Affiche l'aide |

---

## --help

```
═══════════════════════════════════════════════
  /search - Documentation Research (RLM)
═══════════════════════════════════════════════

Usage: /search <query> [options]

Options:
  <query>           Sujet de recherche
  --append          Ajoute au contexte existant
  --status          Affiche le contexte actuel
  --clear           Supprime .context.md
  --help            Affiche cette aide

RLM Patterns (toujours appliqués):
  1. Peek    - Aperçu rapide des résultats
  2. Grep    - Filtrage par keywords
  3. Map     - 6 recherches parallèles
  4. Synth   - Synthèse multi-sources (3+ pour HIGH)

Exemples:
  /search OAuth2 avec JWT
  /search Kubernetes ingress --append
  /search --status

Workflow:
  /search <query> → itérer → EnterPlanMode
═══════════════════════════════════════════════
```

---

## Sources officielles (Whitelist)

**RÈGLE ABSOLUE** : UNIQUEMENT les domaines suivants.

### Langages
| Langage | Domaines |
|---------|----------|
| Node.js | nodejs.org, developer.mozilla.org |
| Python | docs.python.org, python.org |
| Go | go.dev, pkg.go.dev |
| Rust | rust-lang.org, doc.rust-lang.org |
| Java | docs.oracle.com, openjdk.org |
| C/C++ | cppreference.com, isocpp.org |

### Cloud & Infra
| Service | Domaines |
|---------|----------|
| AWS | docs.aws.amazon.com |
| GCP | cloud.google.com |
| Azure | learn.microsoft.com |
| Docker | docs.docker.com |
| Kubernetes | kubernetes.io |
| Terraform | developer.hashicorp.com |

### Frameworks
| Framework | Domaines |
|-----------|----------|
| React | react.dev |
| Vue | vuejs.org |
| Next.js | nextjs.org |
| FastAPI | fastapi.tiangolo.com |

### Standards
| Type | Domaines |
|------|----------|
| Web | developer.mozilla.org, w3.org |
| Security | owasp.org |
| RFCs | rfc-editor.org, tools.ietf.org |

### Blacklist
- ❌ Blogs, Medium, Dev.to
- ❌ Stack Overflow (sauf identification problème)
- ❌ Tutoriels tiers, cours en ligne

---

## Workflow RLM (6 phases)

### Phase 0 : Décomposition (RLM Pattern: Peek + Grep)

**Analyser la query AVANT toute recherche :**

1. **Peek** - Identifier la complexité
   - Query simple (1 concept) → Phase 1 directe
   - Query complexe (2+ concepts) → Décomposer

2. **Grep** - Extraire les keywords
   ```
   Query: "OAuth2 avec JWT pour API REST"
   Keywords: [OAuth2, JWT, API, REST]
   Technologies: [OAuth2 → rfc-editor.org, JWT → tools.ietf.org]
   ```

3. **Parallélisation systématique**
   - Toujours lancer jusqu'à 6 Task agents en parallèle
   - Couvrir tous les domaines pertinents

**Output Phase 0 :**
```
═══════════════════════════════════════════════
  /search - RLM Decomposition
═══════════════════════════════════════════════

  Query    : <query>
  Keywords : <k1>, <k2>, <k3>

  Decomposition:
    ├─ Sub-query 1: <concept1> → <domain1>
    ├─ Sub-query 2: <concept2> → <domain2>
    └─ Sub-query 3: <concept3> → <domain3>

  Strategy: PARALLEL (6 Task agents max)

═══════════════════════════════════════════════
```

---

### Phase 1 : Recherche parallèle (RLM Pattern: Partition + Map)

**Pour chaque sous-query, lancer un Task agent :**

```
Task({
  subagent_type: "Explore",
  prompt: "Rechercher <concept> sur <domain>. Extraire: définition, usage, exemples.",
  model: "haiku"  // Rapide pour recherche
})
```

**IMPORTANT** : Lancer TOUS les agents dans UN SEUL message (parallèle).

**Exemple multi-agent :**
```
// Message unique avec 3 Task calls
Task({ prompt: "OAuth2 sur rfc-editor.org", ... })
Task({ prompt: "JWT sur tools.ietf.org", ... })
Task({ prompt: "REST API sur developer.mozilla.org", ... })
```

---

### Phase 2 : Peek des résultats

**Avant analyse complète, peek sur chaque résultat :**

1. Lire les 500 premiers caractères de chaque réponse
2. Vérifier la pertinence (score 0-10)
3. Filtrer les résultats non-pertinents (< 5)

```
Résultats agents:
  ✓ OAuth2 (score: 9) - RFC 6749 trouvé
  ✓ JWT (score: 8) - RFC 7519 trouvé
  ✗ REST (score: 3) - Résultat trop générique
    → Relancer avec query affinée
```

---

### Phase 3 : Fetch approfondi (RLM Pattern: Summarization)

**Pour les résultats pertinents, WebFetch avec summarization :**

```
WebFetch({
  url: "<url trouvée>",
  prompt: "Résumer en 5 points clés: 1) Définition, 2) Cas d'usage, 3) Implémentation, 4) Sécurité, 5) Exemples"
})
```

**Summarization progressive :**
- Niveau 1: Résumé par source (5 points)
- Niveau 2: Fusion des résumés (synthèse)
- Niveau 3: Context final (actionable)

---

### Phase 4 : Croisement et validation

| Situation | Confidence | Action |
|-----------|------------|--------|
| 3+ sources confirment | HIGH | Inclure |
| 2 sources confirment | MEDIUM | Inclure |
| 1 source officielle | LOW | Inclure + warning |
| Sources contradictoires | VERIFY | Signaler |
| 0 source | NONE | Exclure |

**Détection contradictions :**
- Comparer versions (date docs)
- Identifier breaking changes
- Signaler à l'utilisateur

---

### Phase 5 : Questions (si nécessaire)

**UNIQUEMENT si ambiguïté détectée :**

```
AskUserQuestion({
  questions: [{
    question: "La query mentionne X et Y. Lequel prioriser ?",
    header: "Priorité",
    options: [
      { label: "X d'abord", description: "Focus sur X" },
      { label: "Y d'abord", description: "Focus sur Y" },
      { label: "Les deux", description: "Recherche complète" }
    ]
  }]
})
```

**NE PAS demander si :**
- Query claire et non-ambiguë
- Une seule technologie
- Contexte suffisant

---

### Phase 6 : Génération context.md (RLM Pattern: Programmatic)

**Générer le fichier de manière structurée :**

```markdown
# Context: <sujet>

Generated: <ISO8601>
Query: <query>
Iterations: <n>
RLM-Depth: <parallel_agents_count>

## Summary

<2-3 phrases résumant les findings>

## Key Information

### <Concept 1>

<Information validée>

**Sources:**
- [<Titre>](<url>) - "<extrait>"
- [<Titre2>](<url>) - "<confirmation>"

**Confidence:** HIGH

### <Concept 2>

<Information>

**Sources:**
- [<Titre>](<url>)

**Confidence:** MEDIUM

## Clarifications

| Question | Réponse |
|----------|---------|
| <Q1> | <R1> |

## Recommendations

1. <Recommandation actionable>
2. <Recommandation actionable>

## Warnings

- ⚠ <Point d'attention>

## Sources Summary

| Source | Domain | Confidence | Used In |
|--------|--------|------------|---------|
| RFC 6749 | rfc-editor.org | HIGH | §1 |
| RFC 7519 | tools.ietf.org | HIGH | §2 |

---
_Généré par /search (RLM-enhanced). Ne pas commiter._
```

---

## --append

Enrichir le contexte existant :

1. Lire `.context.md` existant
2. Identifier les gaps (sections manquantes)
3. Rechercher uniquement les gaps
4. Fusionner sans duplicata

---

## --status / --clear

Identique à la version précédente.

---

## GARDE-FOUS

| Action | Status |
|--------|--------|
| Source non-officielle | ❌ INTERDIT |
| Skip Phase 0 (décomposition) | ❌ INTERDIT |
| Agents séquentiels si parallélisable | ❌ INTERDIT |
| Info sans source | ❌ INTERDIT |

---

## Exemples d'exécution

### Query simple
```
/search "Go context package"

→ 1 concept, 1 domaine (go.dev)
→ WebSearch + WebFetch direct
→ Validation 3+ sources
```

### Query complexe
```
/search "OAuth2 JWT authentication pour API REST"

→ 4 concepts, 3 domaines
→ 6 Task agents parallèles
→ Fetch références croisées
→ Synthèse RLM (3+ sources pour HIGH)
```

### Query multi-domaines
```
/search "Kubernetes ingress controller comparison"

→ 6 Task agents parallèles
→ Couverture: kubernetes.io, docs.docker.com, cloud.google.com
→ Validation stricte 3+ sources
```
