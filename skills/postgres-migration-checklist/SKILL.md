---
name: postgres-migration-checklist
description: "Review a PostgreSQL schema migration for lock and outage risks before it runs, using a lock matrix and a short checklist. Use when the user writes or reviews a SQL or ORM migration for PostgreSQL that adds an index, column, constraint or NOT NULL, changes a column type, renames something, or runs on a large or busy table. Instructions only: no scripts are executed. Do not use for MySQL, SQLite or query tuning."
version: 1.0.0
tags: [postgresql, postgres, migrations, ddl, zero-downtime, locking, checklist]
license: MIT
---

# PostgreSQL Migration Checklist (free edition)

Catch the migrations that take production down before they run. This free skill is a review checklist:
it reads the migration, compares every statement with the lock matrix in
`references/lock-matrix-and-recipes.md`, and tells the user what will block reads or writes and how to
rewrite it. It does not connect to the database or run anything.

## When to use

Use when a `.sql` file or an ORM migration (Django, Rails, Alembic, Flyway, Liquibase, Prisma,
golang-migrate) that emits DDL is written or reviewed for PostgreSQL 12+.

Do NOT use when the database is MySQL, MariaDB, SQLite or SQL Server, or the task is query tuning.
A table created in the same migration has no lock risk: skip it.

## Review workflow

1. **Find the real SQL.** For ORM migrations, ask for or generate the SQL (`sqlmigrate`, `--sql`, `alembic upgrade --sql`). Review the SQL, not the ORM code.
2. **Check the top of each transactional file** for `SET lock_timeout` (e.g. `'3s'`) and a `statement_timeout`. Missing: flag it. A DDL statement that waits for a lock makes every later query on that table queue behind it.
3. **Classify every statement** with the lock matrix: lock level, whether it blocks reads or writes, and whether it scans or rewrites the table. Report it as a table.
4. **Flag these as errors** and propose the recipe from the reference:
   - `CREATE INDEX` without `CONCURRENTLY` on an existing table.
   - `CREATE INDEX CONCURRENTLY` inside a transaction (most ORMs wrap migrations in one; the migration must be marked non-transactional).
   - `ADD COLUMN ... DEFAULT` with a volatile value such as `now()` or `gen_random_uuid()`.
   - `ADD COLUMN ... NOT NULL` without a default on a non-empty table.
   - `ALTER COLUMN ... TYPE` (most changes rewrite the table and its indexes).
   - `ADD FOREIGN KEY` or `ADD CHECK` without `NOT VALID`.
   - `UPDATE` or `DELETE` without `WHERE`, `VACUUM FULL`, `CLUSTER`.
5. **Flag these as warnings:** `RENAME` of anything the running app uses (use expand/contract), `DROP COLUMN` or `DROP TABLE` (needs a verified backup).
6. **Rewrite** the migration with the safe pattern and say which deploy each part belongs to when a change must be split (expand, backfill, contract).
7. **Hand over.** Show the findings and the rewritten SQL. Do not run it. Recommend testing it on a copy of the schema first.

## The agent MUST NOT

- Run the migration or any DDL against a database.
- Suggest `pg_terminate_backend` to get a lock, or disabling triggers or foreign keys to go faster.
- Call a migration safe without having seen the SQL it emits.

## Limits of the free edition

This edition only reviews. It has no linter, no preflight against the live database (long transactions,
lock queues, replication lag), no rehearsal on a schema copy and no apply step with `lock_timeout` and
retries. Those are in the paid `postgres-safe-migrations` skill.
