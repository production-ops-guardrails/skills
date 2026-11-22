<p align="center"><img src="docs/logo.png" width="96" alt="Production Ops Guardrails"></p>

# Production Ops Guardrails

**Agent skills that make Claude Code, Codex and Cursor safe on real production infrastructure:
PostgreSQL, Docker, Ansible and Prometheus.** Every change is linted, dry-run, confirmed and reversible.

[English](#english) · [Español](#español)

---

## English

Free skills ask the model to "be careful". Ours ship executable gates: a migration that would lock a busy
table fails the linter, an alert that uses a metric your Prometheus does not have fails verification, and
a Compose rollout that turns unhealthy rolls itself back. Every script is tested against real PostgreSQL 16,
Docker 29, ansible-core and Prometheus with node_exporter and postgres_exporter before release.

### Free skills in this repo

| Skill | What your agent does with it |
| --- | --- |
| [`postgres-migration-checklist`](skills/postgres-migration-checklist/SKILL.md) | Reviews a PostgreSQL migration against a lock matrix and tells you what will block reads or writes, with the safe rewrite. Instructions only. |
| [`npm-cve-triage`](skills/npm-cve-triage/SKILL.md) | Ranks `npm audit` / OSV-Scanner findings, fixes what patch and minor releases can fix on a scratch copy of the lockfile, applies with backup and auto-rollback if tests fail, and gates CI with exceptions that expire. |
| [`composer-cve-triage`](skills/composer-cve-triage/SKILL.md) | The same for PHP: `composer audit`, first safe release from Packagist, lockfile-only partial updates with no scripts or plugins, rollback and CI gate. |

The CVE skills ship scripts (Python standard library and bash), covered by [`tests/run_tests.sh`](tests/run_tests.sh):
offline fixtures in CI, plus `--live` runs of both fix plans against real vulnerable projects.

![npm fix plan: 4 vulnerable packages before, 1 left that needs a major](docs/npm-fix-plan.png)

```bash
# Claude Code (personal skills)
git clone https://github.com/production-ops-guardrails/skills.git
cp -r skills/skills/npm-cve-triage skills/skills/composer-cve-triage ~/.claude/skills/

# or with skills.sh
npx skills add production-ops-guardrails/skills
```

Then ask your agent: *"Fix the npm audit findings without breaking anything"* or
*"Review migrations/0042_orders.sql before we run it in production."*

### The full pack

| Skill | What it does |
| --- | --- |
| Zero-Downtime PostgreSQL Migrations | Lint for 24 lock and data-loss hazards, preflight, rehearse on a schema copy, apply with lock_timeout and retries. |
| PostgreSQL Restore Drill and Backup Audit | Restore into a scratch database, verify exact row counts, get a dated RPO/RTO report. |
| Prometheus Alerting Baseline and SLO Burn Rates | Alerts verified against your own Prometheus, unit-tested and deployed with rollback. |
| Docker Compose Production Audit and Safe Rollout | Find exposed DB ports and docker.sock mounts, roll out with health gates and auto-rollback. |
| Ansible Idempotency Guard | 19 checks, check-mode diff and a second run that must show changed=0. |
| Docker Disk Reclaim and Crash Forensics | Free disk and debug OOM/crash loops without ever deleting a volume. |
| Dockerfile Hardening (add-on) | Non-root, pinned, multi-stage images, smoke-tested before you ship. |

What the paid migration skill does with a risky migration:

![Migration linter output](docs/migration-lint.png)

**Get it:** [Agensi](AGENSI_PACK_URL) · [SkillHQ](SKILLHQ_URL)

### Support

Open an [issue](../../issues/new/choose). Bug reports for paid skills are welcome here too; please do not
paste paid skill files or secrets.

---

## Español

Las skills gratuitas le piden al modelo que "tenga cuidado". Las nuestras incluyen controles ejecutables:
una migración que bloquearía una tabla con tráfico no pasa el linter, una alerta que usa una métrica que tu
Prometheus no tiene no pasa la verificación, y un despliegue de Compose que deja un servicio sin salud se
revierte solo. Cada script se prueba contra PostgreSQL 16, Docker 29, ansible-core y Prometheus reales antes
de publicarse.

### Skills gratuitas de este repositorio

- **[`postgres-migration-checklist`](skills/postgres-migration-checklist/SKILL.md)**: tu agente revisa una
  migración de PostgreSQL con una matriz de bloqueos y te dice qué bloqueará lecturas o escrituras.
- **[`npm-cve-triage`](skills/npm-cve-triage/SKILL.md)**: prioriza lo que dicen `npm audit` u OSV-Scanner,
  corrige lo que se arregla con versiones patch o minor en una copia del lockfile, aplica con copia de
  seguridad y vuelta atrás automática si fallan los tests, y bloquea la CI con excepciones que caducan.
- **[`composer-cve-triage`](skills/composer-cve-triage/SKILL.md)**: lo mismo para PHP con `composer audit`,
  la primera versión segura según Packagist y actualizaciones parciales sin scripts ni plugins.

```bash
git clone https://github.com/production-ops-guardrails/skills.git
cp -r skills/skills/npm-cve-triage skills/skills/composer-cve-triage ~/.claude/skills/
```

Después pídele a tu agente: *"Arregla los avisos de npm audit sin romper nada."*

### El pack completo

Seis skills (más un add-on) para migraciones PostgreSQL sin caídas, simulacros de restauración con
evidencia, alertas de Prometheus que funcionan de verdad, Docker Compose listo para producción, Ansible
idempotente demostrable y limpieza de disco en Docker sin perder datos.

**Consíguelo en:** [Agensi](AGENSI_PACK_URL) · [SkillHQ](SKILLHQ_URL)

### Soporte

Abre un [issue](../../issues/new/choose). No pegues ficheros de las skills de pago ni secretos.

---

The free skills in this repository are MIT-licensed (see [LICENSE](LICENSE)). The paid skills are not
included here and are licensed per purchase.
