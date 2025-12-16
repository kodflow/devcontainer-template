# CLAUDE.md Best Practices

## Executive Summary

CLAUDE.md is a special configuration file that Claude Code automatically reads at the start of every conversation. Research shows optimizing these files can improve coding performance by **5-10%**, with the best results coming from concise, focused instructions.

## Key Metrics

| Metric | Recommendation |
|--------|----------------|
| Target length | 100-200 lines |
| Maximum length | 300 lines |
| Instruction limit | <150 instructions |
| Performance gain | 5-10% with optimization |

## Top 10 Resources

### Official Sources

1. **[Anthropic Engineering: Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)** - Official guidance
2. **[Claude Blog: Using CLAUDE.md Files](https://claude.com/blog/using-claude-md-files)** - Comprehensive documentation

### Research & Analysis

3. **[Arize AI: CLAUDE.md Best Practices](https://arize.com/blog/claude-md-best-practices-learned-from-optimizing-claude-code-with-prompt-learning/)** - Data-driven research (5-10% gains)
4. **[HumanLayer: Writing a Good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md)** - Progressive disclosure strategy

### Templates

5. **[GitHub Gist: Claude Rules Template](https://gist.github.com/tsdevau/673876d17d344f97ba3473bc081bd1e5)** - Comprehensive template
6. **[Claude Flow Wiki: Templates](https://github.com/ruvnet/claude-flow/wiki/CLAUDE-MD-Templates)** - Collection by project type

### Practical Guides

7. **[Apidog: 5 Best Practices](https://apidog.com/blog/claude-md/)** - Lean, intentional content
8. **[Maxitect Blog: Effective CLAUDE.md](https://www.maxitect.blog/posts/maximising-claude-code-building-an-effective-claudemd)** - Real-world dos and don'ts
9. **[Deeplearning.fr: Ultimate Configuration](https://deeplearning.fr/the-ultimate-claude-md-configuration-transform-your-ai-development-workflow/)** - Advanced patterns
10. **[eesel AI: 7 Essential Practices](https://www.eesel.ai/blog/claude-code-best-practices)** - Production focus

---

## Recommended Structure

```markdown
# Project Name

Brief one-sentence description.

## Tech Stack
- Framework: [Name] v[X.X]
- Language: [Name] v[X.X]
- Testing: [Framework]

## Critical Rules
- [Most important constraint #1]
- [Most important constraint #2]
- [Most important constraint #3]

## Commands
- `npm run dev`: Start development server
- `npm run build`: Build for production
- `npm test`: Run test suite

## Project Structure
/src
  /components  - Reusable UI components
  /pages       - Route pages
  /utils       - Helper functions
/tests         - Test files

## Code Style
- Use ES modules (import/export)
- Components: PascalCase
- Files: kebab-case

## Testing
- Jest for unit tests
- Tests colocated with components
- >80% coverage target

## Do Not Modify
- /node_modules/
- /.git/
- /dist/
```

---

## Core Sections (90%+ of examples)

| Section | Purpose |
|---------|---------|
| Project Overview | Brief description + tech stack |
| Commands | Build, test, dev, deploy commands |
| Code Style | Naming, formatting, patterns |
| Project Structure | Directory tree, organization |
| Testing | Framework, conventions, coverage |

## Optional Sections (50-70%)

| Section | Purpose |
|---------|---------|
| Development Workflow | Branch naming, commits, PR process |
| Environment Setup | Required env vars (names only!) |
| Repository Etiquette | Protected files, legacy boundaries |

## Advanced Sections (20-40%)

| Section | Purpose |
|---------|---------|
| Validation Checkpoints | Pre/post action validation |
| Integration Details | DB schemas, API patterns |
| Custom Commands | MCP servers, slash commands |

---

## Best Practices

### Content Strategy

1. **Progressive Disclosure**
   - Don't embed all documentation
   - Create separate files for details
   - Reference with: `[More: ./docs/building.md]`

2. **Instruction Limit**
   - LLMs follow ~150-200 instructions reliably
   - Claude Code system prompt uses ~50
   - Your CLAUDE.md: <150 instructions

3. **Universal Applicability**
   - Only include instructions for ALL tasks
   - Non-universal instructions get ignored

4. **Conciseness Over Completeness**
   - Write for Claude, not junior devs
   - Bullet points, not paragraphs
   - Directive, not explanatory

### Development Workflow

5. **Start with `/init`, Then Iterate**
   - Use `/init` as starting point
   - Test with real tasks
   - Refine based on results

6. **Use `#` Key**
   - Press `#` during sessions to add instructions
   - Claude auto-incorporates into CLAUDE.md
   - Commit changes with code

7. **Version Control**
   - Commit `CLAUDE.md` for team
   - Use `CLAUDE.local.md` for personal (gitignore)
   - Review in PRs

### File Placement Hierarchy

```
~/.claude/CLAUDE.md          # Global rules
/workspace/CLAUDE.md         # Monorepo shared
/workspace/app1/CLAUDE.md    # App-specific
/workspace/app1/CLAUDE.local.md  # Personal
```

---

## Anti-Patterns

### Content

| Bad | Good |
|-----|------|
| Copy entire style guides | Brief summaries + links |
| Make LLM do linting | Use ESLint, Prettier |
| "The /components folder contains components" | Only explain non-obvious |
| "Write clean code" | "Use async/await, not .then()" |
| Code snippets as examples | `file:line` pointers |

### Process

| Bad | Good |
|-----|------|
| Set and forget | Living documentation |
| Assume auto-reference | Explicitly prompt when critical |
| Accept `/init` without review | Review, refine, test |
| Add without testing | Test each addition |

### Technical

| Bad | Good |
|-----|------|
| "In a full implementation..." | "DIRECT IMPLEMENTATION ONLY" |
| "You're absolutely right!" | Direct, action-oriented |
| Document every edge case | Cover 80%, handle rest as needed |
| 500+ line files | Under 300, ideally 100-200 |

---

## Security

**Never include:**
- API keys, tokens, credentials
- Database connection strings
- Security vulnerability details (public repos)

**Do include:**
- Environment variable names: `STRIPE_API_KEY`
- Required variables list (no values)

---

## Performance Data

| Optimization | Improvement |
|--------------|-------------|
| General coding optimization | +5.19% accuracy |
| Repository-specific optimization | +10.87% accuracy |

*Source: Arize AI research using SWE Bench Lite (300 GitHub issues)*

**Key finding:** Substantial improvements require only refined instructions - no fine-tuning needed.

---

## Platform Examples

### JavaScript/Node.js
```markdown
## Commands
- `npm run dev`: Start dev server
- `npm test`: Run Jest tests

## Code Style
- ES modules (import/export)
- Prefer const over let
- async/await over promises
```

### Python
```markdown
## Commands
- `python manage.py runserver`: Dev server
- `python manage.py test`: Run tests

## Code Style
- Follow PEP 8
- Type hints for functions
- pytest, not unittest
```

### React/Next.js
```markdown
## Tech Stack
- Next.js 14 (App Router)
- TypeScript 5.3
- Tailwind CSS

## Code Style
- Components: PascalCase
- 'use client' only when needed
- Server components by default
```

---

## Conclusion

1. **Conciseness beats comprehensiveness** - 100-200 lines optimal
2. **Progressive disclosure is critical** - Reference, don't embed
3. **Universal applicability matters** - Non-universal gets ignored
4. **Manual crafting outperforms automation** - Refine `/init` output
5. **Iteration drives optimization** - Measure effectiveness
6. **Repository-specific tuning yields best results**
