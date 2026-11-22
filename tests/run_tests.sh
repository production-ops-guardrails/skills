#!/usr/bin/env bash
# run_tests.sh - regression tests for the free skills in this repository.
#   bash tests/run_tests.sh          offline tests (fixtures only, no network, no installs)
#   bash tests/run_tests.sh --live   also runs both fix plans against copies of the fixture projects
#                                    (needs npm 7+, Composer 2.7+ and access to the npm registry and Packagist)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; SK="$HERE/../skills"; FX="$HERE/fixtures"
LIVE=0; [[ "${1:-}" == "--live" ]] && LIVE=1
PASS=0 FAIL=0
expect() {  # expect <exit-code> <must-contain-or-empty> <description> -- command...
  local want="$1" needle="$2" desc="$3"; shift 4
  local out rc; out="$("$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want && ( -z "$needle" || "$out" == *"$needle"* ) ]]; then PASS=$((PASS+1)); echo "ok   $desc"
  else FAIL=$((FAIL+1)); echo "FAIL $desc (rc=$rc, wanted $want${needle:+, '$needle'})"; echo "$out" | tail -n 15 | sed 's/^/     /'; fi
}
T="$SK/npm-cve-triage/scripts/dep_triage.py"
D=(--today 2026-11-21)
NPM=("$FX/npm/audit.json" --lock "$FX/npm/package-lock.json" --manifest "$FX/npm/package.json")
CMP=("$FX/composer/audit.json" --lock "$FX/composer/composer.lock" --manifest "$FX/composer/composer.json")
export DEP_TRIAGE_OFFLINE=1

# --- the shared script is identical in both skills
expect 0 "" "dep_triage.py is identical in both skills" -- cmp "$T" "$SK/composer-cve-triage/scripts/dep_triage.py"
expect 0 "" "dep_triage.py compiles" -- python3 -m py_compile "$T"
for s in "$SK"/*/scripts/*.sh; do expect 0 "" "bash -n $(basename "$s")" -- bash -n "$s"; done

# --- npm audit
expect 1 "CRITICAL  minimist" "npm: critical minimist first"                 -- python3 "$T" report "${NPM[@]}" "${D[@]}"
expect 1 "prod/direct"        "npm: scope from lockfile"                     -- python3 "$T" report "${NPM[@]}" "${D[@]}"
expect 1 "lodash@4.18.1 (minor)" "npm: fix target and semver jump"           -- python3 "$T" report "${NPM[@]}" "${D[@]}"
expect 0 "Gate --fail-on none: pass" "npm: --fail-on none reports but passes" -- python3 "$T" report "${NPM[@]}" --fail-on none "${D[@]}"
expect 1 "FAIL (1)"           "npm: --fail-on critical counts 1"             -- python3 "$T" report "${NPM[@]}" --fail-on critical "${D[@]}"
expect 0 ""                   "npm: --omit-dev drops dev-only debug"         -- bash -c "! python3 '$T' report ${NPM[*]} --omit-dev ${D[*]} | grep -q debug"
expect 0 "\"gated\": 0"       "npm: json output, low gate on prod only"      -- bash -c "python3 '$T' report ${NPM[*]} --omit-dev --fail-on none --format json ${D[*]}"
expect 1 "| CRITICAL | minimist |" "npm: markdown table"                     -- python3 "$T" report "${NPM[@]}" --format md "${D[@]}"

# --- allowlist
expect 1 "ALLOWED   debug"    "allowlist: valid entry suppresses debug"      -- python3 "$T" report "${NPM[@]}" --allowlist "$FX/allowlist-valid.json" --fail-on low "${D[@]}"
expect 3 "expired on 2026-10-01" "allowlist: expired entry fails"            -- python3 "$T" report "${NPM[@]}" --allowlist "$FX/allowlist-expired.json" "${D[@]}"
expect 3 "'reason' must explain" "allowlist: missing reason fails"           -- python3 "$T" report "${NPM[@]}" --allowlist "$FX/allowlist-noreason.json" "${D[@]}"
expect 3 "matched nothing"    "allowlist: stale entry reported"              -- python3 "$T" report "${NPM[@]}" --allowlist "$FX/allowlist-noreason.json" "${D[@]}"
expect 3 "more than 30 days"  "allowlist: too-long expiry fails"             -- python3 "$T" report "${NPM[@]}" --allowlist "$FX/allowlist-valid.json" --max-allow-days 30 "${D[@]}"

# --- malware advisories always stop
expect 4 "MALWARE ADVISORY"   "npm: malware advisory exits 4"                -- python3 "$T" report "$FX/npm/audit-malware.json" "${D[@]}"
expect 4 "MALWARE ADVISORY"   "osv: MAL- id exits 4"                         -- python3 "$T" report "$FX/osv/osv-malware.json" "${D[@]}"
expect 4 "MALWARE"            "malware ignores --fail-on none"               -- python3 "$T" report "$FX/osv/osv-malware.json" --fail-on none "${D[@]}"
expect 4 "no upgrade suggestions" "suggest refuses on malware"               -- python3 "$T" suggest "$FX/npm/audit-malware.json" --lock "$FX/npm/package-lock.json" --manifest "$FX/npm/package.json"

# --- composer audit (object-vs-list quirk, Packagist fix resolution from cache)
expect 1 "CRITICAL  twig/twig" "composer: critical twig"                     -- python3 "$T" report "${CMP[@]}" "${D[@]}"
expect 1 "GHSA-"              "composer: GHSA ids preferred over PKSA"       -- python3 "$T" report "${CMP[@]}" "${D[@]}"
expect 1 "dev/direct"         "composer: packages-dev marked dev"            -- python3 "$T" report "${CMP[@]}" "${D[@]}"
expect 1 "guzzlehttp/guzzle@7.15.2 (minor)" "composer: first safe release from Packagist" -- \
  python3 "$T" report "${CMP[@]}" --packagist --cache-dir "$FX/packagist-cache" "${D[@]}"
expect 1 "guzzlehttp/psr7@2.12.3 (major)" "composer: major flagged as manual" -- \
  python3 "$T" report "${CMP[@]}" --packagist --cache-dir "$FX/packagist-cache" "${D[@]}"
expect 0 "phpunit/phpunit:9.6.33" "suggest: exact pin gets exact require"    -- \
  python3 "$T" suggest "$FX/composer/audit.json" --lock "$FX/composer/composer.lock" --manifest "$FX/composer/composer.json" --cache-dir "$FX/packagist-cache"
expect 0 "skipped guzzlehttp/psr7" "suggest: majors are skipped, not applied" -- \
  python3 "$T" suggest "$FX/composer/audit.json" --lock "$FX/composer/composer.lock" --manifest "$FX/lockdiff/psr7-direct.composer.json" --cache-dir "$FX/packagist-cache"
expect 0 "lodash@4.18.1"      "suggest: npm exact pins"                      -- python3 "$T" suggest "$FX/npm/audit.json" --lock "$FX/npm/package-lock.json" --manifest "$FX/npm/package.json"
expect 0 ""                   "suggest: ^ range already covering fix is skipped" -- bash -c "! python3 '$T' suggest '$FX/composer/audit.json' --lock '$FX/composer/composer.lock' --manifest '$FX/composer/composer.json' --cache-dir '$FX/packagist-cache' | grep -q twig"

# --- osv-scanner
expect 1 "twig/twig@3.27.0"   "osv: fix version from OSV ranges"             -- python3 "$T" report "$FX/osv/osv.json" --format text "${D[@]}"
expect 1 "axios@0.33.0 (major)" "osv: 0.x minor jump treated as major"       -- python3 "$T" report "$FX/osv/osv.json" "${D[@]}"
expect 0 ""                   "osv: dev group from osv-scanner"              -- bash -c "! python3 '$T' report '$FX/osv/osv.json' --omit-dev ${D[*]} | grep -q phpunit"

# --- lockdiff
expect 0 "minor    lodash"    "lockdiff: npm direct changes listed"          -- python3 "$T" lockdiff "$FX/npm/package-lock.json" "$FX/lockdiff/npm-after.json" --manifest "$FX/lockdiff/npm-after.package.json"
expect 1 "brings an install script" "lockdiff: new install script flagged"   -- python3 "$T" lockdiff "$FX/npm/package-lock.json" "$FX/lockdiff/npm-after-suspicious.json"
expect 1 "evil.example.net"   "lockdiff: foreign registry flagged"           -- python3 "$T" lockdiff "$FX/npm/package-lock.json" "$FX/lockdiff/npm-after-suspicious.json"
expect 0 ""                   "lockdiff: extra registry host can be allowed" -- bash -c "python3 '$T' lockdiff '$FX/npm/package-lock.json' '$FX/lockdiff/npm-after-suspicious.json' --registry-host evil.example.net | grep -q 'install script'; test \$? -eq 0"
expect 1 "is a minor change"  "lockdiff: --max-bump patch blocks minors"     -- python3 "$T" lockdiff "$FX/composer/composer.lock" "$FX/lockdiff/composer-after.lock" --manifest "$FX/lockdiff/composer-after.composer.json" --max-bump patch
expect 0 "Transitive:"        "lockdiff: composer transitive summary"        -- python3 "$T" lockdiff "$FX/composer/composer.lock" "$FX/lockdiff/composer-after.lock" --manifest "$FX/lockdiff/composer-after.composer.json"

# --- errors
expect 2 "not valid JSON"     "error: broken JSON exits 2"                   -- python3 "$T" report "$FX/allowlist-valid.json.broken"
expect 2 "too old"            "error: lockfile v1 refused"                   -- python3 "$T" report "$FX/npm/audit.json" --lock "$FX/lockdiff/lockfile-v1.json"

if [[ $LIVE -eq 1 ]]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  cp -r "$FX/npm" "$W/npm"; cp -r "$FX/composer" "$W/composer"
  BEFORE_N="$(cat "$W/npm/package-lock.json" "$W/npm/package.json" | sha256sum)"
  expect 1 "dry run only"     "live npm: dry run plans a fix"                -- bash "$SK/npm-cve-triage/scripts/npm_fix_plan.sh" --dir "$W/npm"
  expect 0 "$BEFORE_N"        "live npm: dry run left files untouched"       -- bash -c "cat '$W/npm/package-lock.json' '$W/npm/package.json' | sha256sum"
  expect 5 "were restored"    "live npm: failed verify restores files"       -- bash "$SK/npm-cve-triage/scripts/npm_fix_plan.sh" --dir "$W/npm" --apply --verify "false"
  expect 0 "$BEFORE_N"        "live npm: restore is byte-identical"          -- bash -c "cat '$W/npm/package-lock.json' '$W/npm/package.json' | sha256sum"
  expect 1 "APPLIED"          "live npm: apply (axios needs a major: exit 1)" -- bash "$SK/npm-cve-triage/scripts/npm_fix_plan.sh" --dir "$W/npm" --apply
  BEFORE_C="$(cat "$W/composer/composer.lock" "$W/composer/composer.json" | sha256sum)"
  expect 0 "dry run only"     "live composer: dry run clears every advisory" -- bash "$SK/composer-cve-triage/scripts/composer_fix_plan.sh" --dir "$W/composer"
  expect 0 "$BEFORE_C"        "live composer: dry run left files untouched"  -- bash -c "cat '$W/composer/composer.lock' '$W/composer/composer.json' | sha256sum"
  expect 5 "were restored"    "live composer: failed verify restores files"  -- bash "$SK/composer-cve-triage/scripts/composer_fix_plan.sh" --dir "$W/composer" --apply --verify "false"
  expect 0 "$BEFORE_C"        "live composer: restore is byte-identical"     -- bash -c "cat '$W/composer/composer.lock' '$W/composer/composer.json' | sha256sum"
  expect 0 "APPLIED"          "live composer: apply"                         -- bash "$SK/composer-cve-triage/scripts/composer_fix_plan.sh" --dir "$W/composer" --apply
  expect 0 "No known vulnerabilities" "live composer: re-audit is clean"     -- bash -c "cd '$W/composer' && composer audit --locked --format=json --no-plugins 2>/dev/null > a.json; python3 '$T' report a.json"
fi
echo; echo "passed: $PASS  failed: $FAIL"
[[ $FAIL -eq 0 ]]
