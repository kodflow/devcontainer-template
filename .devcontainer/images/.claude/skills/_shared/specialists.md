# Specialist routing — who actually knows this technology

One table, shared by `/challenge`, `/feature` and `/fix`, so the three cannot
disagree about who reviews what. When an agent is added or removed, this file is
the only place to change.

## The table

Route on **evidence** — a file that exists, a dependency that is declared, a
manifest present — never on the prose of a description alone.

```bash
ls ~/.claude/agents/*.md | xargs -n1 basename | sed 's/\.md$//'
```

The table below is the routing this template ships with. **It is not a claim
that every one of these agents is installed** — a consumer may have pruned the
languages it does not build. Check the listing above, dispatch what is there,
and report a matched row whose agent is absent rather than passing over it.

| Evidence | Specialist |
|---|---|
| `.go`, `go.mod`, `go.work` | `developer-specialist-go` |
| `.rs`, `Cargo.toml` | `developer-specialist-rust` |
| `.py`, `pyproject.toml`, `requirements.txt` | `developer-specialist-python` |
| `.ts` `.js` `.mjs`, `package.json` | `developer-specialist-nodejs` |
| a `react` dependency, `.tsx` `.jsx` | `developer-specialist-react` |
| `.c` `.h` | `developer-specialist-c` |
| `.cc` `.cpp` `.hpp` `.cxx` | `developer-specialist-cpp` |
| `.zig`, `build.zig`, `build.zig.zon` | `developer-specialist-zig` |
| SQL, a migration, a schema change | `data-specialist-postgres` |
| `Dockerfile`, `docker-compose.y*ml` | `devops-specialist-docker` |
| k8s manifests, `Chart.yaml`, Helm values | `devops-specialist-kubernetes` |
| `.tf`, `.hcl`, Terragrunt | `devops-specialist-infrastructure` |
| Vault, Consul, Nomad, Packer | `devops-specialist-hashicorp` |
| `.github/workflows/` | `tooling-specialist-github-actions` |
| `.sh`, a CI shell step, `Makefile` recipes | `developer-executor-shell` |
| auth, crypto, input handling, a trust boundary **in code** | `developer-executor-security` |
| secrets in config, image/dependency CVEs, compliance **in infrastructure** | `devops-specialist-security` |
| systemd units, packaging, host configuration | `devops-executor-linux` |
| `.java`, `pom.xml`, `build.gradle` | `developer-specialist-java` |
| `.kt` `.kts` | `developer-specialist-kotlin` |
| `.cs`, `.csproj` | `developer-specialist-csharp` |
| `.vb`, `.vbproj` | `developer-specialist-vbnet` |
| `.rb`, `Gemfile` | `developer-specialist-ruby` |
| `.php`, `composer.json` | `developer-specialist-php` |
| `.scala`, `build.sbt` | `developer-specialist-scala` |
| `.ex` `.exs`, `mix.exs` | `developer-specialist-elixir` |
| `.dart`, `pubspec.yaml` | `developer-specialist-dart` |
| `.swift`, `Package.swift` | `developer-specialist-swift` |
| `.pl` `.pm`, `cpanfile` | `developer-specialist-perl` |
| `.lua`, `.rockspec` | `developer-specialist-lua` |
| `.r` `.R`, `DESCRIPTION` | `developer-specialist-r` |
| `.m` (MATLAB/Octave) | `developer-specialist-matlab` |
| `.f90` `.f95` `.f03`, `fpm.toml` | `developer-specialist-fortran` |
| `.adb` `.ads`, `alire.toml` | `developer-specialist-ada` |
| `.pas` `.pp`, `.lpi` | `developer-specialist-pascal` |
| `.cob` `.cbl` | `developer-specialist-cobol` |
| `.s` `.asm` | `developer-specialist-assembly` |
| Playwright tests, `playwright.config.*` | `developer-specialist-playwright` |
| an AWS provider or service | `devops-specialist-aws` |
| a Google Cloud provider or service | `devops-specialist-gcp` |
| an Azure provider or service | `devops-specialist-azure` |
| `wrangler.toml`, Workers/Pages/R2/KV/D1 | `devops-specialist-cloudflare` |
| cost, budget, right-sizing, waste | `devops-specialist-finops` |
| a BSD host | `devops-executor-bsd` |
| a macOS host | `devops-executor-osx` |
| a Windows host | `devops-executor-windows` |
| QEMU/KVM, libvirt, cloud-init | `devops-executor-qemu` |
| vSphere, ESXi, vCenter | `devops-executor-vmware` |

Several rows can match at once, and then **every match is dispatched**. A change
touching Go, Kubernetes and a workflow file gets three specialists, not the one
that felt most relevant.

## Two rules that make it worth doing

**Dispatch every match.** Skipping a matched specialist because the set "feels
big enough" is how a change ships with the exact defect the installed specialist
would have named on sight. If the cost is the concern, that is an argument about
which specialists to install, not about which to consult.

**Report a match with no installed specialist.** Say the domain went unreviewed.
Silence reads as "reviewed and clean", which is the opposite of true.

## What every specialist owes back

Each specialist carries a standing instruction to verify before asserting: an
API's existence, a default, a limit, a deprecation, a version behaviour or a
security property is checked against documentation — `context7` first, then the
vendor's own docs and release notes, then `~/.claude/docs/` **respecting its
`verified` dates**, since a stale entry is a hypothesis rather than a source.

So the brief must ask for the evidence back:

```
Return `consulted`: the documentation you actually checked, per claim that
needed it. Return `unverified`: anything you could not confirm, with what you
tried. A claim about how this technology behaves, with an empty `consulted`
list, is a memory claim — mark it, do not present it as fact.
```

**A technology claim with an empty `consulted` list is not evidence.** Treat it
as unresolved rather than accepting it. This is the whole point of routing to a
specialist instead of reasoning about the technology yourself: not that it knows
more, but that it goes and checks.

## Briefing well

- **Paste the material inline** — the plan, the diff, the description. A
  specialist that has to go fetch what it is judging spends its turns fetching.
- **State the question.** "Is this correct in Go?" gets a survey; "does this
  plan's use of `errgroup` leak the goroutine when the parent context is already
  cancelled?" gets an answer.
- **Say what is already decided.** Pass the constraint ledger's MUST entries, so
  the specialist argues within them rather than against them.
