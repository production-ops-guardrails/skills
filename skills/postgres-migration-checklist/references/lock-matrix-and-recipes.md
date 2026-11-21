# Safe migration recipes (PostgreSQL 12+)

Every transactional file starts with:
```sql
SET lock_timeout = '3s';          -- give up instead of queueing the whole table behind us
SET statement_timeout = '5min';   -- size to the work; 0 only for CONCURRENTLY files
```

## Lock matrix (what each statement takes)

| Statement | Lock | Blocks reads? | Blocks writes? | Scans/rewrites |
|---|---|---|---|---|
| `CREATE INDEX` | SHARE | no | **yes** | full scan |
| `CREATE INDEX CONCURRENTLY` | SHARE UPDATE EXCLUSIVE | no | no | 2 scans, waits for old txns |
| `DROP INDEX` / `DROP INDEX CONCURRENTLY` | ACCESS EXCLUSIVE / SHARE UPDATE EXCLUSIVE | yes / no | yes / no | none |
| `ADD COLUMN` (nullable or constant default, PG11+) | ACCESS EXCLUSIVE (brief) | brief | brief | none |
| `ADD COLUMN ... DEFAULT now()` (volatile) | ACCESS EXCLUSIVE | **yes** | **yes** | **rewrite** |
| `ALTER COLUMN TYPE` (most) | ACCESS EXCLUSIVE | **yes** | **yes** | **rewrite + reindex** |
| `ALTER COLUMN SET NOT NULL` | ACCESS EXCLUSIVE | **yes** | **yes** | full scan (skipped PG12+ if a valid CHECK proves it) |
| `ADD CONSTRAINT ... FOREIGN KEY` | SHARE ROW EXCLUSIVE on both tables | no | **yes** | full scan |
| `... NOT VALID` then `VALIDATE CONSTRAINT` | brief / SHARE UPDATE EXCLUSIVE | no | no (validate) | scan without blocking writes |
| `ADD UNIQUE` / `PRIMARY KEY` | ACCESS EXCLUSIVE | **yes** | **yes** | index build |
| `ADD CONSTRAINT ... USING INDEX` | ACCESS EXCLUSIVE (brief) | brief | brief | none |
| `VACUUM FULL`, `CLUSTER` | ACCESS EXCLUSIVE | **yes** | **yes** | **rewrite** |
| `REINDEX CONCURRENTLY` | SHARE UPDATE EXCLUSIVE | no | no | rebuild |

"Brief" still means: if a long transaction holds any lock on the table, the statement waits, and every
new query queues behind it. That is what `lock_timeout` prevents.

## Add an index
```sql
-- non-transactional migration
CREATE INDEX CONCURRENTLY IF NOT EXISTS orders_customer_id_idx ON orders (customer_id);
-- if it failed earlier:
-- SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;
-- DROP INDEX CONCURRENTLY IF EXISTS orders_customer_id_idx;   then retry
```

## Add a column with a default computed per row
```sql
ALTER TABLE orders ADD COLUMN created_at timestamptz;               -- instant
ALTER TABLE orders ALTER COLUMN created_at SET DEFAULT now();       -- only affects new rows, instant
-- backfill in batches (see below), then optionally enforce NOT NULL (next recipe)
```


---

More recipes (batched backfills, safe NOT NULL, foreign keys, unique constraints, type changes, renames,
enum changes) plus the executable linter, preflight, rehearsal and apply-with-retries scripts are in the
paid `postgres-safe-migrations` skill of Production Ops Guardrails.
