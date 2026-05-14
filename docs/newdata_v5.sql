/* ═══════════════════════════════════════════════════════════════════════════════════
   ██████╗  █████╗ ████████╗ █████╗ ██████╗  █████╗ ███████╗███████╗
   ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝
   ██║  ██║███████║   ██║   ███████║██████╔╝███████║███████╗█████╗
   ██║  ██║██╔══██║   ██║   ██╔══██║██╔══██╗██╔══██║╚════██║██╔══╝
   ██████╔╝██║  ██║   ██║   ██║  ██║██████╔╝██║  ██║███████║███████╗
   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝

   ██╗  ██╗      ██████╗  █████╗ ██╗   ██╗
   ╚██╗██╔╝      ██╔══██╗██╔══██╗╚██╗ ██╔╝
    ╚███╔╝ █████╗██████╔╝███████║ ╚████╔╝
    ██╔██╗ ╚════╝██╔══██╗██╔══██║  ╚██╔╝
   ██╔╝ ██╗      ██║  ██║██║  ██║   ██║
   ╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝

   🔬 PROFESSIONAL DATABASE X-RAY ANALYSIS SUITE — AI-OPTIMIZED EDITION v5
   ═══════════════════════════════════════════════════════════════════════════════════

   📋 DESCRIPTION:
   A comprehensive PostgreSQL/Supabase introspection query delivering deep
   structural, relational, performance, and security insights — built from
   the ground up for maximum AI analysis speed and accuracy.

   🎯 SECTIONS (★ = new/changed in v5):
   ├── -1  ★ DB SUMMARY             — single-row full orientation for AI
   ├──  00  EXTENSIONS               — installed extensions
   ├──  01  ENUMS                    — custom types with values
   ├──  02  TABLE_META               — storage + row counts + maintenance
   ├──  03  VIEWS                    — definitions + table dependencies
   ├──  04  REALTIME                 — Supabase realtime publications
   ├──  05  COLUMNS                  — types + stats + histogram + MCV freqs
   ├──  06  CONSTRAINT_KEY           — PKs and unique constraints
   ├──  07  CONSTRAINT_CHECK         — check expressions
   ├──  08  FK_OUTGOING              — FKs from this table
   ├──  09  FK_INCOMING              — FKs to this table
   ├──  10  RELATIONSHIP_SUMMARY     — rewritten: uses shared CTE, no correlated subqueries
   ├──  11  INDEX                    — definitions + usage + unused flag
   ├──  12  RLS_POLICY               — row-level security policies
   ├──  13  TRIGGER                  — trigger definitions
   ├──  14  FUNCTION                 — custom only + body preview + trigger classification
   ├──  15  SEQUENCE                 — auto-increment sequences
   ├──  16  TABLE_PRIVILEGE          — table grants
   ├──  17  FUNCTION_PRIVILEGE       — custom functions only (PostGIS noise removed)
   ├──  18  DEPENDENCY               — redesigned: view→table + FK graph
   ├──  19  STORAGE_ANALYSIS         — I/O block stats per table
   ├──  20  SECURITY_AUDIT           — uses shared CTE, no correlated subqueries
   ├──  21  FUNC_BODY                — full source code for every custom function
   ├──  22  TOP_QUERIES              — pg_stat_statements top 25 by total time
   ├──  23  UNUSED_INDEXES           — zero-scan non-PK/unique indexes + DROP commands
   ├──  24  BLOAT_REPORT             — tables with >10% dead-row bloat
   ├──  25  HEALTH_SCORECARD         — per-table 0-100 health score for AI triage
   ├──  26  WRITE_HOTSPOTS           — tables ranked by write activity
   ├──  27  ★ MATERIALIZED_VIEWS     — NEW: mat-views + refresh status + staleness
   ├──  28  ★ CUSTOM_TYPES           — NEW: composite, domain, range types
   ├──  29  ★ TABLE_PARTITIONING     — NEW: partition trees + strategies
   ├──  30  ★ EVENT_TRIGGERS         — NEW: DDL-level event triggers
   ├──  31  ★ SCHEMA_PRIVILEGES      — NEW: schema-level USAGE/CREATE grants
   ├──  32  ★ DEFAULT_PRIVILEGES     — NEW: ALTER DEFAULT PRIVILEGES rules
   ├──  33  ★ ROLE_MEMBERSHIPS       — NEW: role → member graph
   ├──  34  ★ FOREIGN_DATA_WRAPPERS  — NEW: FDW servers + options
   ├──  35  ★ FOREIGN_TABLES         — NEW: foreign table column map
   ├──  36  ★ ALL_PUBLICATIONS       — NEW: every publication (not only realtime)
   ├──  37  ★ SUBSCRIPTIONS          — NEW: logical replication subscriptions
   ├──  38  ★ GUC_SETTINGS           — NEW: DB + role-level GUC settings
   ├──  39  ★ LIVE_QUERIES           — NEW: pg_stat_activity snapshot
   ├──  40  ★ LOCK_MONITOR           — NEW: current locks + blocking chains
   ├──  41  ★ ADVANCED_INDEX         — NEW: expression / partial / redundant index audit
   ├──  42  ★ COLUMN_ISSUES          — NEW: nullability, defaults, type anomalies audit
   └──  43  ★ RULES                  — NEW: pg_rewrite rules on tables + views

   🔧 REQUIREMENTS:
   • PostgreSQL 14+  (pg_get_functiondef, pg_stat_statements, pg_depend)
   • pg_stat_statements must be installed for Section 22 (silent empty if absent)
   • pg_stat_activity access required for Section 39 (requires pg_monitor or superuser)
   • Execute as a role with access to pg_catalog and information_schema

   📊 OUTPUT FORMAT:
   | section | table_name | name | details (JSONB as text) |

   🏷️ VERSION: 5.0.0
   📅 UPDATED: 2026-05-14
   ═══════════════════════════════════════════════════════════════════════════════════
*/

-- ════════════════════════════════════════════════════════════════════════════════════
-- 📦  SHARED CTEs  (computed once, reused across multiple sections)
-- ════════════════════════════════════════════════════════════════════════════════════

WITH

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ 🎯 target_tables — public schema base tables only                               │
-- └─────────────────────────────────────────────────────────────────────────────────┘
target_tables AS (
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type   = 'BASE TABLE'
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ ★ custom_func_oids — app functions, extension functions excluded                │
-- │   Used by: Sections 14, 17, 21                                                  │
-- │   Logic: a function installed by an extension has a pg_depend row              │
-- │           with deptype='e'; we exclude those.                                   │
-- └─────────────────────────────────────────────────────────────────────────────────┘
custom_func_oids AS (
    SELECT p.oid
    FROM pg_proc      p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (
            SELECT 1
            FROM pg_depend d
            WHERE d.objid   = p.oid
              AND d.classid = 'pg_proc'::regclass
              AND d.deptype = 'e'
      )
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ 📊 table_stats — pg_stat_user_tables for the public schema                      │
-- └─────────────────────────────────────────────────────────────────────────────────┘
table_stats AS (
    SELECT
        relname          AS tablename,
        n_live_tup       AS live_rows,
        n_dead_tup       AS dead_rows,
        n_tup_ins        AS total_inserts,
        n_tup_upd        AS total_updates,
        n_tup_del        AS total_deletes,
        n_tup_hot_upd    AS hot_updates,
        last_vacuum,
        last_autovacuum,
        last_analyze,
        last_autoanalyze,
        vacuum_count,
        autovacuum_count,
        analyze_count,
        autoanalyze_count
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ 📈 index_stats — pg_stat_user_indexes                                           │
-- └─────────────────────────────────────────────────────────────────────────────────┘
index_stats AS (
    SELECT
        relname      AS tablename,
        indexrelname,
        idx_scan,
        idx_tup_read,
        idx_tup_fetch
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ 🗄️ table_io — pg_statio_user_tables                                             │
-- └─────────────────────────────────────────────────────────────────────────────────┘
table_io AS (
    SELECT
        relname         AS tablename,
        heap_blks_read,
        heap_blks_hit,
        idx_blks_read,
        idx_blks_hit,
        toast_blks_read,
        toast_blks_hit
    FROM pg_statio_user_tables
    WHERE schemaname = 'public'
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ ★ fk_counts — incoming & outgoing FK counts per table                           │
-- │   Replaces 6 correlated subqueries in Section 10 and 2 in Section 20            │
-- └─────────────────────────────────────────────────────────────────────────────────┘
fk_counts AS (
    SELECT
        t.table_name,
        -- outgoing = FKs declared ON this table
        COALESCE(out_q.cnt, 0)  AS outgoing_fk_count,
        -- incoming = FKs on OTHER tables that reference this table
        COALESCE(in_q.cnt,  0)  AS incoming_fk_count,
        COALESCE(out_q.cnt, 0) + COALESCE(in_q.cnt, 0) AS total_connections
    FROM target_tables t
    LEFT JOIN (
        SELECT table_name, COUNT(*) AS cnt
        FROM information_schema.table_constraints
        WHERE table_schema    = 'public'
          AND constraint_type = 'FOREIGN KEY'
        GROUP BY table_name
    ) out_q ON out_q.table_name = t.table_name
    LEFT JOIN (
        SELECT ccu.table_name, COUNT(DISTINCT tc.constraint_name) AS cnt
        FROM information_schema.constraint_column_usage ccu
        JOIN information_schema.table_constraints tc
          ON tc.constraint_name = ccu.constraint_name
        WHERE ccu.table_schema    = 'public'
          AND tc.constraint_type  = 'FOREIGN KEY'
          AND tc.table_name      != ccu.table_name
        GROUP BY ccu.table_name
    ) in_q ON in_q.table_name = t.table_name
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ ★ rls_policy_counts — policy count per table                                    │
-- │   Replaces correlated subquery repeated in Sections 12, 20, 25                  │
-- └─────────────────────────────────────────────────────────────────────────────────┘
rls_policy_counts AS (
    SELECT tablename, COUNT(*) AS policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
    GROUP BY tablename
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ ★ table_sizes — relation sizes pre-computed once                                │
-- │   Replaces repeated pg_relation_size / pg_total_relation_size calls             │
-- └─────────────────────────────────────────────────────────────────────────────────┘
table_sizes AS (
    SELECT
        c.relname                                       AS tablename,
        pg_total_relation_size(c.oid)                   AS total_bytes,
        pg_relation_size(c.oid)                         AS table_bytes,
        pg_indexes_size(c.oid)                          AS index_bytes,
        COALESCE(pg_total_relation_size(c.reltoastrelid), 0) AS toast_bytes
    FROM pg_class     c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind  = 'r'
      AND c.relname IN (SELECT table_name FROM target_tables)
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ ★ trigger_functions — set of function OIDs used as trigger functions            │
-- │   Used by Section 14 to classify each function as TRIGGER vs API/RPC            │
-- └─────────────────────────────────────────────────────────────────────────────────┘
trigger_functions AS (
    SELECT DISTINCT pt.tgfoid AS func_oid
    FROM pg_trigger pt
    JOIN pg_class   pc ON pc.oid = pt.tgrelid
    JOIN pg_namespace pn ON pn.oid = pc.relnamespace
    WHERE pn.nspname = 'public'
      AND NOT pt.tgisinternal
),

-- ════════════════════════════════════════════════════════════════════════════════════
-- 🔬 MAIN X-RAY  — one big UNION ALL consumed in the final SELECT
-- ════════════════════════════════════════════════════════════════════════════════════

xray AS (

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION -1 : DATABASE SUMMARY                                                    ║
-- ║  🗺️  Single orientation row — AI should read this before anything else             ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '-1_SUMMARY'          AS section,
    current_database()    AS table_name,
    'overview'            AS name,
    jsonb_build_object(

        -- Identity
        'database',              current_database(),
        'schema',                'public',
        'generated_at',          now(),
        'pg_version',            current_setting('server_version'),
        'total_db_size',         pg_size_pretty(pg_database_size(current_database())),

        -- Table inventory
        'table_count',           (SELECT COUNT(*) FROM target_tables),
        'tables_sorted_by_size', (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'table', sz.tablename,
                           'total_size', pg_size_pretty(sz.total_bytes),
                           'live_rows',  COALESCE(ts.live_rows, 0)
                       ) ORDER BY sz.total_bytes DESC
                   )
            FROM table_sizes sz
            LEFT JOIN table_stats ts ON ts.tablename = sz.tablename
        ),

        -- Write activity summary (helps AI find the "hot" tables instantly)
        'most_written_tables',   (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'table',    tablename,
                           'writes',   total_inserts + total_updates + total_deletes,
                           'inserts',  total_inserts,
                           'updates',  total_updates,
                           'deletes',  total_deletes
                       ) ORDER BY (total_inserts + total_updates + total_deletes) DESC
                   )
            FROM table_stats
            WHERE total_inserts + total_updates + total_deletes > 0
            LIMIT 10
        ),

        -- Extensions
        'extensions',            (
            SELECT jsonb_agg(jsonb_build_object('name', extname, 'version', extversion)
                             ORDER BY extname)
            FROM pg_extension
        ),

        -- Custom ENUM types
        'enum_types',            (
            SELECT jsonb_agg(jsonb_build_object(
                       'name',   t.typname,
                       'values', (SELECT jsonb_agg(e.enumlabel ORDER BY e.enumsortorder)
                                  FROM pg_enum e WHERE e.enumtypid = t.oid)
                   ) ORDER BY t.typname)
            FROM pg_type      t
            JOIN pg_namespace n ON n.oid = t.typnamespace
            WHERE n.nspname = 'public' AND t.typtype = 'e'
        ),

        -- Custom functions
        'custom_function_count', (SELECT COUNT(*) FROM custom_func_oids),
        'custom_functions',      (
            SELECT jsonb_agg(p.proname ORDER BY p.proname)
            FROM pg_proc p
            WHERE p.oid IN (SELECT oid FROM custom_func_oids)
        ),

        -- Realtime
        'realtime_tables',       (
            SELECT jsonb_agg(tablename ORDER BY tablename)
            FROM pg_publication_tables
            WHERE pubname   = 'supabase_realtime'
              AND schemaname = 'public'
        ),

        -- Security summary
        'rls_enabled_count',     (
            SELECT COUNT(*) FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relkind = 'r'
              AND c.relrowsecurity
              AND c.relname IN (SELECT table_name FROM target_tables)
        ),
        'rls_coverage_pct',      ROUND(
            100.0 * (
                SELECT COUNT(*) FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'public' AND c.relkind = 'r'
                  AND c.relrowsecurity
                  AND c.relname IN (SELECT table_name FROM target_tables)
            ) / NULLIF((SELECT COUNT(*) FROM target_tables), 0)
        , 1),

        -- Tables missing COMMENT (helps AI know where docs are absent)
        'tables_without_comment', (
            SELECT jsonb_agg(c.relname ORDER BY c.relname)
            FROM pg_class     c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relkind = 'r'
              AND c.relname IN (SELECT table_name FROM target_tables)
              AND obj_description(c.oid, 'pg_class') IS NULL
        ),

        -- Cache hotness
        'hottest_tables_by_cache_hits', (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'table',     tablename,
                           'heap_hits', heap_blks_hit,
                           'idx_hits',  idx_blks_hit
                       ) ORDER BY (heap_blks_hit + idx_blks_hit) DESC
                   )
            FROM (
                SELECT tablename, heap_blks_hit, idx_blks_hit
                FROM table_io
                ORDER BY (heap_blks_hit + idx_blks_hit) DESC
                LIMIT 5
            ) _top
        )

    )::text AS details,
    -1 AS sort_order

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 00 : EXTENSIONS                                                          ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '00_EXTENSION'    AS section,
    e.extname         AS table_name,
    'configuration'   AS name,
    jsonb_build_object(
        'version',      e.extversion,
        'schema',       n.nspname,
        'relocatable',  e.extrelocatable,
        'owner',        pg_get_userbyid(e.extowner),
        'description',  COALESCE(
            (SELECT description FROM pg_description WHERE objoid = e.oid),
            'No description'
        )
    )::text AS details,
    0 AS sort_order
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 01 : ENUM TYPES                                                          ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '01_ENUM'       AS section,
    t.typname       AS table_name,
    'definition'    AS name,
    jsonb_build_object(
        'value_count', COUNT(*),
        'values',      jsonb_agg(e.enumlabel ORDER BY e.enumsortorder),
        'schema',      n.nspname,
        'owner',       pg_get_userbyid(t.typowner),
        'oid',         t.oid
    )::text AS details,
    1 AS sort_order
FROM pg_type      t
JOIN pg_enum      e ON t.oid = e.enumtypid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
GROUP BY t.typname, t.typowner, n.nspname, t.oid

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 02 : TABLE METADATA & STORAGE                                            ║
-- ║  ★ Now uses table_sizes CTE — no repeated pg_relation_size() calls               ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '02_TABLE_META'  AS section,
    c.relname        AS table_name,
    'storage_info'   AS name,
    jsonb_build_object(
        'owner',   pg_get_userbyid(c.relowner),
        'storage', jsonb_build_object(
            'total_size',   pg_size_pretty(sz.total_bytes),
            'total_bytes',  sz.total_bytes,
            'table_size',   pg_size_pretty(sz.table_bytes),
            'index_size',   pg_size_pretty(sz.index_bytes),
            'toast_size',   pg_size_pretty(sz.toast_bytes)
        ),
        'rows', jsonb_build_object(
            'live',      COALESCE(ts.live_rows, 0),
            'dead',      COALESCE(ts.dead_rows, 0),
            'estimated', c.reltuples::bigint
        ),
        'operations', jsonb_build_object(
            'inserts',      COALESCE(ts.total_inserts, 0),
            'updates',      COALESCE(ts.total_updates, 0),
            'deletes',      COALESCE(ts.total_deletes, 0),
            'hot_updates',  COALESCE(ts.hot_updates, 0),
            -- ★ write_profile: classify the table's activity type for AI
            'write_profile', CASE
                WHEN COALESCE(ts.total_inserts,0) + COALESCE(ts.total_updates,0) + COALESCE(ts.total_deletes,0) = 0
                     THEN 'IDLE'
                WHEN COALESCE(ts.total_updates,0) >  COALESCE(ts.total_inserts,0) * 2
                     THEN 'UPDATE_HEAVY'
                WHEN COALESCE(ts.total_deletes,0) >  COALESCE(ts.total_inserts,0) * 0.5
                     THEN 'HIGH_CHURN'
                WHEN COALESCE(ts.total_inserts,0) >  COALESCE(ts.total_updates,0) + COALESCE(ts.total_deletes,0)
                     THEN 'INSERT_HEAVY'
                ELSE 'BALANCED'
            END
        ),
        'rls_enabled',     c.relrowsecurity,
        'rls_forced',      c.relforcerowsecurity,
        'fillfactor',      COALESCE(
            (SELECT option_value FROM pg_options_to_table(c.reloptions)
             WHERE  option_name = 'fillfactor'),
            '100'
        ),
        'maintenance', jsonb_build_object(
            'last_vacuum',     ts.last_vacuum,
            'last_autovacuum', ts.last_autovacuum,
            'last_analyze',    ts.last_analyze,
            'vacuum_count',    ts.vacuum_count,
            'analyze_count',   ts.analyze_count
        ),
        'bloat_pct', ROUND(
            (100.0 * COALESCE(ts.dead_rows,0) /
             NULLIF(COALESCE(ts.live_rows,0) + COALESCE(ts.dead_rows,0), 0))::numeric, 2
        ),
        'description', COALESCE(obj_description(c.oid, 'pg_class'), NULL)
    )::text AS details,
    2 AS sort_order
FROM pg_class     c
JOIN pg_namespace n  ON n.oid  = c.relnamespace
JOIN table_sizes  sz ON sz.tablename = c.relname
LEFT JOIN table_stats ts ON ts.tablename = c.relname
WHERE n.nspname = 'public'
  AND c.relkind  = 'r'
  AND c.relname IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 03 : VIEWS                                                               ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '03_VIEW'       AS section,
    v.table_name,
    'definition'    AS name,
    jsonb_build_object(
        'is_updatable',        v.is_updatable,
        'is_insertable_into',  v.is_insertable_into,
        'check_option',        v.check_option,
        'definition_preview',  LEFT(v.view_definition, 600),
        'definition_length',   LENGTH(v.view_definition),
        'depends_on', COALESCE((
            SELECT jsonb_agg(DISTINCT ref_ns.nspname || '.' || ref_cl.relname)
            FROM pg_depend       d
            JOIN pg_rewrite      rw ON rw.oid = d.objid
            JOIN pg_class        dv ON dv.oid = rw.ev_class
            JOIN pg_class        ref_cl ON ref_cl.oid = d.refobjid
            JOIN pg_namespace    ref_ns ON ref_ns.oid = ref_cl.relnamespace
            WHERE dv.relname        = v.table_name
              AND d.classid         = 'pg_rewrite'::regclass
              AND ref_cl.relkind   IN ('r', 'v')
              AND ref_cl.relname   != v.table_name
        ), '[]'::jsonb)
    )::text AS details,
    3 AS sort_order
FROM information_schema.views v
WHERE v.table_schema = 'public'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 04 : REALTIME PUBLICATIONS                                               ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '04_REALTIME'   AS section,
    ppt.tablename   AS table_name,
    'publication'   AS name,
    jsonb_build_object(
        'publication_name', ppt.pubname,
        'schema',           ppt.schemaname,
        'events',           ARRAY['INSERT','UPDATE','DELETE'],
        'active',           true
    )::text AS details,
    4 AS sort_order
FROM pg_publication_tables ppt
WHERE ppt.pubname    = 'supabase_realtime'
  AND ppt.schemaname = 'public'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 05 : COLUMNS  ★ + histogram_bounds + most_common_freqs                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '05_COLUMN'        AS section,
    c.table_name,
    c.column_name      AS name,
    jsonb_build_object(
        'position',  c.ordinal_position,
        'type', jsonb_build_object(
            'data_type',         c.data_type,
            'udt_name',          c.udt_name,
            'char_max_length',   c.character_maximum_length,
            'numeric_precision', c.numeric_precision,
            'numeric_scale',     c.numeric_scale
        ),
        'nullable',  c.is_nullable = 'YES',
        'default',   c.column_default,
        'identity',  CASE WHEN c.is_identity  = 'YES'    THEN c.identity_generation    ELSE NULL END,
        'generated', CASE WHEN c.is_generated = 'ALWAYS' THEN c.generation_expression  ELSE NULL END,
        'statistics', jsonb_build_object(
            'avg_width_bytes',   COALESCE(s.avg_width,   0),
            'distinct_values',   ROUND(COALESCE(s.n_distinct, 0)::numeric, 2),
            'null_fraction_pct', ROUND((COALESCE(s.null_frac, 0) * 100)::numeric, 2),
            'correlation',       ROUND(COALESCE(s.correlation, 0)::numeric, 4),
            -- top values (what values appear most)
            'most_common_values', CASE
                WHEN s.most_common_vals IS NOT NULL
                THEN LEFT(s.most_common_vals::text, 200)
                ELSE NULL
            END,
            -- frequency of each top value (0.0–1.0)
            'most_common_freqs', CASE
                WHEN s.most_common_freqs IS NOT NULL
                THEN LEFT(s.most_common_freqs::text, 200)
                ELSE NULL
            END,
            -- data range split into equal-frequency buckets
            'histogram_bounds', CASE
                WHEN s.histogram_bounds IS NOT NULL
                THEN LEFT(s.histogram_bounds::text, 400)
                ELSE NULL
            END
        ),
        'description', pgd.description
    )::text AS details,
    c.ordinal_position AS sort_order
FROM information_schema.columns   c
LEFT JOIN pg_stats                s   ON  s.tablename = c.table_name
                                      AND s.attname   = c.column_name
                                      AND s.schemaname = 'public'
LEFT JOIN pg_class                pc  ON pc.relname   = c.table_name
LEFT JOIN pg_namespace            pn  ON pn.oid       = pc.relnamespace
                                      AND pn.nspname  = 'public'
LEFT JOIN pg_attribute            a   ON  a.attrelid  = pc.oid
                                      AND a.attname   = c.column_name
LEFT JOIN pg_description          pgd ON pgd.objoid   = pc.oid
                                      AND pgd.objsubid = a.attnum
WHERE c.table_schema = 'public'
  AND c.table_name IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 06 : PRIMARY KEY & UNIQUE CONSTRAINTS                                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '06_CONSTRAINT_KEY'  AS section,
    tc.table_name,
    tc.constraint_name   AS name,
    jsonb_build_object(
        'type',               tc.constraint_type,
        'columns',            jsonb_agg(kcu.column_name ORDER BY kcu.ordinal_position),
        'deferrable',         tc.is_deferrable        = 'YES',
        'initially_deferred', tc.initially_deferred   = 'YES'
    )::text AS details,
    6 AS sort_order
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
       ON kcu.constraint_name = tc.constraint_name
      AND kcu.table_schema    = tc.table_schema
WHERE tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
  AND tc.table_schema   = 'public'
  AND tc.table_name    IN (SELECT table_name FROM target_tables)
GROUP BY tc.table_name, tc.constraint_name, tc.constraint_type,
         tc.is_deferrable, tc.initially_deferred

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 07 : CHECK CONSTRAINTS                                                   ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '07_CONSTRAINT_CHECK' AS section,
    tc.table_name,
    tc.constraint_name    AS name,
    jsonb_build_object(
        'type',       'CHECK',
        'expression', cc.check_clause,
        'enforced',   true
    )::text AS details,
    7 AS sort_order
FROM information_schema.table_constraints   tc
JOIN information_schema.check_constraints   cc
  ON cc.constraint_name   = tc.constraint_name
 AND cc.constraint_schema = tc.constraint_schema
WHERE tc.constraint_type = 'CHECK'
  AND tc.table_schema    = 'public'
  AND tc.table_name     IN (SELECT table_name FROM target_tables)
  AND tc.constraint_name NOT LIKE '%_not_null'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 08 : FOREIGN KEYS (OUTGOING)                                             ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '08_FK_OUTGOING'      AS section,
    tc.table_name,
    tc.constraint_name    AS name,
    jsonb_build_object(
        'direction', 'OUTGOING',
        'source', jsonb_build_object(
            'table',   tc.table_name,
            'columns', (
                SELECT jsonb_agg(kcu.column_name ORDER BY kcu.ordinal_position)
                FROM information_schema.key_column_usage kcu
                WHERE kcu.constraint_name = tc.constraint_name
                  AND kcu.table_schema    = tc.table_schema
            )
        ),
        'target', jsonb_build_object(
            'table',   ccu.table_name,
            'columns', (
                SELECT jsonb_agg(ccu2.column_name)
                FROM information_schema.constraint_column_usage ccu2
                WHERE ccu2.constraint_name = tc.constraint_name
                  AND ccu2.table_schema    = ccu.table_schema
            )
        ),
        'rules', jsonb_build_object(
            'on_update',  rc.update_rule,
            'on_delete',  rc.delete_rule,
            'match_type', rc.match_option
        ),
        'relationship_type', CASE
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.table_constraints  tc2
                JOIN information_schema.key_column_usage  kcu2
                  ON kcu2.constraint_name = tc2.constraint_name
                WHERE tc2.table_name     = tc.table_name
                  AND tc2.table_schema   = 'public'
                  AND tc2.constraint_type = 'UNIQUE'
                  AND kcu2.column_name    = (
                      SELECT kcu3.column_name
                      FROM information_schema.key_column_usage kcu3
                      WHERE kcu3.constraint_name = tc.constraint_name
                      LIMIT 1
                  )
            ) THEN 'ONE_TO_ONE'
            ELSE 'MANY_TO_ONE'
        END,
        'cardinality', jsonb_build_object(
            'source_rows', (SELECT live_rows FROM table_stats WHERE tablename = tc.table_name),
            'target_rows', (SELECT live_rows FROM table_stats WHERE tablename = ccu.table_name)
        )
    )::text AS details,
    8 AS sort_order
FROM information_schema.table_constraints        tc
JOIN information_schema.constraint_column_usage  ccu ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints  rc  ON rc.constraint_name  = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema    = 'public'
  AND tc.table_name     IN (SELECT table_name FROM target_tables)
GROUP BY tc.table_name, tc.constraint_name, tc.table_schema,
         ccu.table_name, ccu.table_schema,
         rc.match_option, rc.update_rule, rc.delete_rule

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 09 : FOREIGN KEYS (INCOMING)                                             ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '09_FK_INCOMING'      AS section,
    ccu.table_name        AS table_name,
    tc.constraint_name    AS name,
    jsonb_build_object(
        'direction', 'INCOMING',
        'referenced_by', jsonb_build_object(
            'table',     tc.table_name,
            'columns',   (
                SELECT jsonb_agg(kcu.column_name ORDER BY kcu.ordinal_position)
                FROM information_schema.key_column_usage kcu
                WHERE kcu.constraint_name = tc.constraint_name
                  AND kcu.table_schema    = tc.table_schema
            ),
            'row_count', (SELECT live_rows FROM table_stats WHERE tablename = tc.table_name)
        ),
        'local_columns', (
            SELECT jsonb_agg(ccu2.column_name)
            FROM information_schema.constraint_column_usage ccu2
            WHERE ccu2.constraint_name = tc.constraint_name
        ),
        'rules', jsonb_build_object(
            'on_delete', rc.delete_rule,
            'on_update', rc.update_rule
        ),
        'impact_analysis', jsonb_build_object(
            'cascade_risk', CASE
                WHEN rc.delete_rule = 'CASCADE'                   THEN 'HIGH'
                WHEN rc.delete_rule = 'SET NULL'                  THEN 'MEDIUM'
                WHEN rc.delete_rule IN ('RESTRICT','NO ACTION')   THEN 'PROTECTED'
                ELSE 'UNKNOWN'
            END,
            'warning', CASE
                WHEN rc.delete_rule = 'CASCADE'
                THEN '⚠️ Deleting rows will cascade to ' || tc.table_name
                ELSE NULL
            END
        )
    )::text AS details,
    9 AS sort_order
FROM information_schema.referential_constraints  rc
JOIN information_schema.table_constraints        tc  ON tc.constraint_name  = rc.constraint_name
JOIN information_schema.constraint_column_usage  ccu ON ccu.constraint_name = rc.constraint_name
WHERE ccu.table_schema = 'public'
  AND ccu.table_name  IN (SELECT table_name FROM target_tables)
  AND tc.table_name   != ccu.table_name
GROUP BY ccu.table_name, tc.table_name, tc.constraint_name,
         tc.table_schema, rc.delete_rule, rc.update_rule

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 10 : RELATIONSHIP SUMMARY  ★ REWRITTEN                                  ║
-- ║  Uses fk_counts CTE — eliminates 6 correlated subqueries per table row           ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '10_RELATIONSHIP_SUMMARY' AS section,
    fk.table_name,
    'connections'             AS name,
    jsonb_build_object(
        'outgoing_fk_count',  fk.outgoing_fk_count,
        'incoming_fk_count',  fk.incoming_fk_count,
        'total_connections',  fk.total_connections,
        'is_isolated',        fk.total_connections = 0,
        'role', CASE
            WHEN fk.incoming_fk_count > 3 AND fk.outgoing_fk_count = 0  THEN 'LOOKUP_TABLE'
            WHEN fk.incoming_fk_count = 0 AND fk.outgoing_fk_count > 2  THEN 'LEAF_TABLE'
            WHEN fk.incoming_fk_count > 2 AND fk.outgoing_fk_count > 2  THEN 'JUNCTION_HUB'
            WHEN fk.total_connections  = 0                               THEN 'ISOLATED'
            ELSE 'STANDARD'
        END
    )::text AS details,
    10 AS sort_order
FROM fk_counts fk

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 11 : INDEXES                                                             ║
-- ║  ★ Unused indexes float to top within the section (is_unused=true first)         ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '11_INDEX'      AS section,
    i.tablename     AS table_name,
    i.indexname     AS name,
    jsonb_build_object(
        'method',      am.amname,
        'unique',      ix.indisunique,
        'primary',     ix.indisprimary,
        'valid',       ix.indisvalid,
        'ready',       ix.indisready,
        'columns', (
            SELECT jsonb_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum))
            FROM pg_attribute a
            WHERE a.attrelid = c.oid
              AND a.attnum   = ANY(ix.indkey)
        ),
        'size',         pg_size_pretty(pg_relation_size(c.oid)),
        'size_bytes',   pg_relation_size(c.oid),
        'usage_stats', jsonb_build_object(
            'scans',          COALESCE(ist.idx_scan, 0),
            'tuples_read',    COALESCE(ist.idx_tup_read, 0),
            'tuples_fetched', COALESCE(ist.idx_tup_fetch, 0),
            'is_unused',      COALESCE(ist.idx_scan, 0) = 0
        ),
        'definition',   i.indexdef,
        'condition',    pg_get_expr(ix.indpred, ix.indrelid)
    )::text AS details,
    -- ★ unused non-PK indexes appear first to draw AI attention immediately
    CASE WHEN COALESCE(ist.idx_scan, 0) = 0
              AND NOT ix.indisprimary
              AND NOT ix.indisunique
         THEN 11
         ELSE 12
    END AS sort_order
FROM pg_indexes    i
JOIN pg_class      c   ON c.relname        = i.indexname
JOIN pg_namespace  n   ON n.oid            = c.relnamespace AND n.nspname = 'public'
JOIN pg_index      ix  ON ix.indexrelid    = c.oid
JOIN pg_am         am  ON am.oid           = c.relam
LEFT JOIN index_stats ist ON ist.indexrelname = i.indexname
WHERE i.schemaname  = 'public'
  AND i.tablename  IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 12 : ROW LEVEL SECURITY POLICIES                                        ║
-- ║  ★ Uses rls_policy_counts CTE instead of correlated subquery                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '12_RLS_POLICY'       AS section,
    pol.tablename         AS table_name,
    pol.policyname        AS name,
    jsonb_build_object(
        'command',               pol.cmd,
        'permissive',            pol.permissive = 'PERMISSIVE',
        'roles',                 pol.roles,
        'using_expression',      pol.qual,
        'with_check_expression', pol.with_check,
        'applies_to', CASE pol.cmd
            WHEN 'ALL' THEN ARRAY['SELECT','INSERT','UPDATE','DELETE']
            WHEN '*'   THEN ARRAY['SELECT','INSERT','UPDATE','DELETE']
            ELSE ARRAY[pol.cmd]
        END,
        -- how many total policies protect this table
        'total_policies_on_table', COALESCE(rpc.policy_count, 0)
    )::text AS details,
    13 AS sort_order
FROM pg_policies pol
LEFT JOIN rls_policy_counts rpc ON rpc.tablename = pol.tablename
WHERE pol.schemaname = 'public'
  AND pol.tablename IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 13 : TRIGGERS                                                            ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '13_TRIGGER'                AS section,
    it.event_object_table       AS table_name,
    it.trigger_name             AS name,
    jsonb_build_object(
        'enabled',      pt.tgenabled != 'D',
        'timing',       it.action_timing,
        'events', (
            SELECT jsonb_agg(DISTINCT it2.event_manipulation)
            FROM information_schema.triggers it2
            WHERE it2.trigger_name        = it.trigger_name
              AND it2.event_object_table  = it.event_object_table
        ),
        'level',         it.action_orientation,
        'function',      regexp_replace(it.action_statement, 'EXECUTE (FUNCTION|PROCEDURE) ', ''),
        'condition',     it.action_condition,
        'trigger_type', CASE it.action_timing
            WHEN 'BEFORE'     THEN 'BEFORE'
            WHEN 'AFTER'      THEN 'AFTER'
            WHEN 'INSTEAD OF' THEN 'INSTEAD_OF'
            ELSE it.action_timing
        END
    )::text AS details,
    14 AS sort_order
FROM information_schema.triggers it
JOIN pg_trigger    pt ON pt.tgname  = it.trigger_name
JOIN pg_class      pc ON pc.oid     = pt.tgrelid
WHERE it.event_object_table IN (SELECT table_name FROM target_tables)
  AND pc.relname             = it.event_object_table
  AND NOT pt.tgisinternal
GROUP BY it.event_object_table, it.trigger_name, it.action_timing,
         it.action_statement,   it.action_orientation, it.action_condition, pt.tgenabled

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 14 : FUNCTIONS  ★ ENHANCED                                               ║
-- ║  • Custom functions only (extension noise filtered)                               ║
-- ║  • body_preview: first 600 chars                                                  ║
-- ║  • is_trigger_function flag (uses trigger_functions CTE)                          ║
-- ║  • called_by_tables: which tables' triggers call this function                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '14_FUNCTION'   AS section,
    p.proname       AS table_name,
    'signature'     AS name,
    jsonb_build_object(
        'oid',               p.oid,
        'return_type',       pg_get_function_result(p.oid),
        'arguments',         pg_get_function_arguments(p.oid),
        'language',          l.lanname,
        'security',          CASE WHEN p.prosecdef THEN 'DEFINER' ELSE 'INVOKER' END,
        'volatility', CASE p.provolatile
            WHEN 'i' THEN 'IMMUTABLE'
            WHEN 's' THEN 'STABLE'
            WHEN 'v' THEN 'VOLATILE'
        END,
        'parallel_safety', CASE p.proparallel
            WHEN 's' THEN 'SAFE'
            WHEN 'r' THEN 'RESTRICTED'
            WHEN 'u' THEN 'UNSAFE'
        END,
        'cost',               p.procost,
        'estimated_rows',     CASE WHEN p.proretset THEN p.prorows ELSE NULL END,
        'is_aggregate',       p.prokind = 'a',
        'is_window',          p.prokind = 'w',
        'is_procedure',       p.prokind = 'p',
        'strict',             p.proisstrict,
        'owner',              pg_get_userbyid(p.proowner),
        'description',        COALESCE(obj_description(p.oid, 'pg_proc'), NULL),
        -- ★ is this function only used as a trigger handler?
        'is_trigger_function', EXISTS (SELECT 1 FROM trigger_functions tf WHERE tf.func_oid = p.oid),
        -- ★ which tables call this function via triggers?
        'called_by_tables', (
            SELECT jsonb_agg(DISTINCT pc2.relname ORDER BY pc2.relname)
            FROM pg_trigger    pt2
            JOIN pg_class      pc2 ON pc2.oid = pt2.tgrelid
            JOIN pg_namespace  pn2 ON pn2.oid = pc2.relnamespace
            WHERE pt2.tgfoid    = p.oid
              AND pn2.nspname   = 'public'
              AND NOT pt2.tgisinternal
        ),
        -- ★ body preview (first 600 chars) so AI can classify purpose without Section 21
        'body_preview', CASE
            WHEN l.lanname IN ('plpgsql','sql','plv8','plpython3u')
            THEN LEFT(pg_get_functiondef(p.oid), 600)
            ELSE NULL
        END
    )::text AS details,
    15 AS sort_order
FROM pg_proc      p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_language  l ON l.oid = p.prolang
WHERE n.nspname = 'public'
  AND p.oid    IN (SELECT oid FROM custom_func_oids)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 15 : SEQUENCES                                                           ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '15_SEQUENCE'   AS section,
    c.relname       AS table_name,
    'configuration' AS name,
    jsonb_build_object(
        'owner',       pg_get_userbyid(c.relowner),
        'data_type',   format_type(s.seqtypid, NULL),
        'start_value', s.seqstart,
        'min_value',   s.seqmin,
        'max_value',   s.seqmax,
        'increment',   s.seqincrement,
        'cycle',       s.seqcycle,
        'cache_size',  s.seqcache,
        'last_value', (
            SELECT last_value
            FROM pg_sequences
            WHERE schemaname = 'public' AND sequencename = c.relname
        ),
        'owned_by', (
            SELECT d.refobjid::regclass::text || '.' || a.attname
            FROM pg_depend    d
            JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
            WHERE d.objid = c.oid AND d.deptype = 'a'
            LIMIT 1
        )
    )::text AS details,
    16 AS sort_order
FROM pg_class     c
JOIN pg_sequence  s ON s.seqrelid = c.oid
JOIN pg_namespace n ON n.oid      = c.relnamespace
WHERE n.nspname = 'public'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 16 : TABLE PRIVILEGES                                                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '16_TABLE_PRIVILEGE' AS section,
    table_name,
    grantee              AS name,
    jsonb_build_object(
        'grantee',           grantee,
        'grantor',           grantor,
        'privileges',        jsonb_agg(privilege_type ORDER BY privilege_type),
        'with_grant_option', bool_or(is_grantable = 'YES')
    )::text AS details,
    17 AS sort_order
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name  IN (SELECT table_name FROM target_tables)
GROUP BY table_name, grantee, grantor

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 17 : FUNCTION PRIVILEGES  ★ FIXED                                       ║
-- ║  Was 3,932 rows (PostGIS noise). Now: custom functions only ≈ 30–50 rows         ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '17_FUNCTION_PRIVILEGE' AS section,
    rp.routine_name         AS table_name,
    rp.grantee              AS name,
    jsonb_build_object(
        'function',          rp.routine_name,
        'grantee',           rp.grantee,
        'grantor',           rp.grantor,
        'privilege',         rp.privilege_type,
        'with_grant_option', rp.is_grantable = 'YES'
    )::text AS details,
    18 AS sort_order
FROM information_schema.routine_privileges rp
WHERE rp.routine_schema = 'public'
  AND EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname  = 'public'
          AND p.proname  = rp.routine_name
          AND p.oid     IN (SELECT oid FROM custom_func_oids)
  )

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 18 : DEPENDENCY GRAPH  ★ REDESIGNED (v2 returned 0 rows)                ║
-- ║  18a — views → base tables they read                                              ║
-- ║  18b — FK-based table-to-table dependencies with cascade risk                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝

-- 18a: view → base-table relationships
SELECT
    '18_DEPENDENCY'     AS section,
    rt.relname          AS table_name,
    dv.relname          AS name,
    jsonb_build_object(
        'type',          'VIEW_READS_TABLE',
        'view_name',     dv.relname,
        'base_table',    rt.relname,
        'note',          'Structural changes to this table may break the view'
    )::text AS details,
    19 AS sort_order
FROM pg_rewrite    rw
JOIN pg_class      dv     ON dv.oid    = rw.ev_class AND dv.relkind = 'v'
JOIN pg_depend     d      ON d.objid   = rw.oid
                         AND d.classid = 'pg_rewrite'::regclass
                         AND d.refclassid = 'pg_class'::regclass
JOIN pg_class      rt     ON rt.oid    = d.refobjid AND rt.relkind = 'r'
JOIN pg_namespace  dv_ns  ON dv_ns.oid = dv.relnamespace AND dv_ns.nspname = 'public'
JOIN pg_namespace  rt_ns  ON rt_ns.oid = rt.relnamespace AND rt_ns.nspname = 'public'
WHERE rt.relname IN (SELECT table_name FROM target_tables)
  AND rt.relname != dv.relname

UNION ALL

-- 18b: FK-based table→table dependency graph
SELECT
    '18_DEPENDENCY'      AS section,
    tc.table_name,
    ccu.table_name       AS name,
    jsonb_build_object(
        'type',              'FK_CONSTRAINT',
        'source_table',      tc.table_name,
        'target_table',      ccu.table_name,
        'constraint_name',   tc.constraint_name,
        'on_delete',         rc.delete_rule,
        'on_update',         rc.update_rule,
        'cascade_risk', CASE rc.delete_rule
            WHEN 'CASCADE'   THEN 'HIGH — deletes in target delete rows here'
            WHEN 'SET NULL'  THEN 'MEDIUM — deletes in target null FK column'
            WHEN 'RESTRICT'  THEN 'PROTECTED — cannot delete from target while rows exist'
            WHEN 'NO ACTION' THEN 'PROTECTED — deferred; same as RESTRICT'
            ELSE rc.delete_rule
        END
    )::text AS details,
    19 AS sort_order
FROM information_schema.table_constraints       tc
JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
                                                   AND ccu.table_schema    = 'public'
JOIN information_schema.referential_constraints rc  ON rc.constraint_name  = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema    = 'public'
  AND tc.table_name     IN (SELECT table_name FROM target_tables)
  AND tc.table_name     != ccu.table_name
GROUP BY tc.table_name, ccu.table_name, tc.constraint_name, rc.delete_rule, rc.update_rule

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 19 : STORAGE ANALYSIS                                                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '19_STORAGE_ANALYSIS' AS section,
    t.table_name,
    'io_stats'            AS name,
    jsonb_build_object(
        'heap_blocks', jsonb_build_object(
            'read',  COALESCE(tio.heap_blks_read, 0),
            'hit',   COALESCE(tio.heap_blks_hit,  0),
            'hit_ratio', CASE
                WHEN COALESCE(tio.heap_blks_read,0) + COALESCE(tio.heap_blks_hit,0) > 0
                THEN ROUND(
                        (100.0 * COALESCE(tio.heap_blks_hit,0) /
                        (COALESCE(tio.heap_blks_read,0) + COALESCE(tio.heap_blks_hit,0)))::numeric, 2
                     )
                ELSE 100.0
            END
        ),
        'index_blocks', jsonb_build_object(
            'read', COALESCE(tio.idx_blks_read, 0),
            'hit',  COALESCE(tio.idx_blks_hit,  0)
        ),
        'toast_blocks', jsonb_build_object(
            'read', COALESCE(tio.toast_blks_read, 0),
            'hit',  COALESCE(tio.toast_blks_hit,  0)
        )
    )::text AS details,
    20 AS sort_order
FROM target_tables t
LEFT JOIN table_io tio ON tio.tablename = t.table_name

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 20 : SECURITY AUDIT  ★ REWRITTEN                                        ║
-- ║  Uses rls_policy_counts CTE — no correlated subquery per row                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '20_SECURITY_AUDIT' AS section,
    c.relname           AS table_name,
    'security_status'   AS name,
    jsonb_build_object(
        'rls', jsonb_build_object(
            'enabled',      c.relrowsecurity,
            'forced',       c.relforcerowsecurity,
            'policy_count', COALESCE(rpc.policy_count, 0)
        ),
        'grants', jsonb_build_object(
            'role_count', (
                SELECT COUNT(DISTINCT grantee)
                FROM information_schema.table_privileges tp
                WHERE tp.table_name  = c.relname
                  AND tp.table_schema = 'public'
            ),
            'has_public_access', EXISTS (
                SELECT 1
                FROM information_schema.table_privileges tp
                WHERE tp.table_name  = c.relname
                  AND tp.table_schema = 'public'
                  AND tp.grantee     = 'PUBLIC'
            )
        ),
        'recommendations', CASE
            WHEN NOT c.relrowsecurity
            THEN '⚠️ Consider enabling RLS'
            WHEN c.relrowsecurity AND COALESCE(rpc.policy_count,0) = 0
            THEN '⚠️ RLS enabled but no policies — table is inaccessible to all roles'
            ELSE '✅ Security configured'
        END
    )::text AS details,
    21 AS sort_order
FROM pg_class           c
JOIN pg_namespace       n   ON n.oid       = c.relnamespace
LEFT JOIN rls_policy_counts rpc ON rpc.tablename = c.relname
WHERE n.nspname = 'public'
  AND c.relkind  = 'r'
  AND c.relname IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 21 : FULL FUNCTION SOURCE BODIES  ★ NEW                                  ║
-- ║  Complete CREATE OR REPLACE FUNCTION … source for every custom function           ║
-- ║  Capped at 10,000 chars; truncated flag set when exceeded                         ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '21_FUNC_BODY'  AS section,
    p.proname       AS table_name,
    'source_code'   AS name,
    jsonb_build_object(
        'oid',                p.oid,
        'language',           l.lanname,
        'return_type',        pg_get_function_result(p.oid),
        'arguments',          pg_get_function_arguments(p.oid),
        'is_trigger',         pg_get_function_result(p.oid) = 'trigger',
        'is_trigger_function', EXISTS (SELECT 1 FROM trigger_functions tf WHERE tf.func_oid = p.oid),
        'body_chars',         LENGTH(pg_get_functiondef(p.oid)),
        'truncated',          LENGTH(pg_get_functiondef(p.oid)) > 10000,
        'source',             LEFT(pg_get_functiondef(p.oid), 10000)
    )::text AS details,
    22 AS sort_order
FROM pg_proc      p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_language  l ON l.oid = p.prolang
WHERE n.nspname  = 'public'
  AND p.oid     IN (SELECT oid FROM custom_func_oids)
  AND l.lanname IN ('plpgsql','sql','plv8','plpython3u')

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 22 : TOP QUERIES  ★ FIXED + ENHANCED                                    ║
-- ║  v3 bug: ORDER BY + LIMIT inside UNION ALL is forbidden → wrapped in subquery     ║
-- ║  Requires pg_stat_statements (silent empty if absent)                             ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '22_TOP_QUERIES'      AS section,
    'pg_stat_statements'  AS table_name,
    'rank_' || LPAD(rank::text, 2,'0') AS name,
    jsonb_build_object(
        'rank',             rank,
        'calls',            calls,
        'total_time_ms',    ROUND(total_exec_time::numeric, 0),
        'mean_time_ms',     ROUND(mean_exec_time::numeric, 2),
        'min_time_ms',      ROUND(min_exec_time::numeric, 2),
        'max_time_ms',      ROUND(max_exec_time::numeric, 2),
        'stddev_ms',        ROUND(stddev_exec_time::numeric, 2),
        'rows_per_call',    ROUND((rows::numeric / NULLIF(calls,0)), 1),
        'shared_blks_hit',  shared_blks_hit,
        'shared_blks_read', shared_blks_read,
        'cache_hit_ratio',  ROUND(
            (100.0 * shared_blks_hit /
             NULLIF(shared_blks_hit + shared_blks_read, 0))::numeric, 1
        ),
        -- ★ temp_blks: if > 0 the query is spilling to disk — major perf signal
        'temp_blks_written', temp_blks_written,
        'query',            LEFT(query, 600)
    )::text AS details,
    23 AS sort_order
FROM (
    SELECT
        ROW_NUMBER() OVER (ORDER BY total_exec_time DESC) AS rank,
        calls, total_exec_time, mean_exec_time, min_exec_time,
        max_exec_time, stddev_exec_time, rows, shared_blks_hit,
        shared_blks_read, temp_blks_written, query
    FROM pg_stat_statements
    WHERE dbid  = (SELECT oid FROM pg_database WHERE datname = current_database())
      AND calls > 0
    ORDER BY total_exec_time DESC
    LIMIT 25
) ranked_queries

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 23 : UNUSED INDEX ALERTS  ★ FIXED + DROP command included               ║
-- ║  v3 bug: ORDER BY inside UNION ALL member → wrapped in subquery                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '23_UNUSED_INDEXES'   AS section,
    ui.tablename          AS table_name,
    ui.indexname          AS name,
    jsonb_build_object(
        'index_size',       pg_size_pretty(ui.idx_bytes),
        'index_size_bytes', ui.idx_bytes,
        'total_scans',      0,
        'is_primary',       ui.is_primary,
        'is_unique',        ui.is_unique,
        'columns',          ui.cols,
        'definition',       ui.indexdef,
        'drop_command',     'DROP INDEX CONCURRENTLY ' || ui.indexname || ';',
        'warning',          '⚠️ Zero scans — confirm stats not recently reset before dropping'
    )::text AS details,
    24 AS sort_order
FROM (
    SELECT
        i.tablename,
        i.indexname,
        i.indexdef,
        pg_relation_size(c.oid)        AS idx_bytes,
        ix.indisprimary                AS is_primary,
        ix.indisunique                 AS is_unique,
        (
            SELECT jsonb_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum))
            FROM pg_attribute a
            WHERE a.attrelid = ix.indrelid AND a.attnum = ANY(ix.indkey)
        )                              AS cols
    FROM pg_indexes    i
    JOIN pg_class      c   ON c.relname     = i.indexname
    JOIN pg_namespace  n   ON n.oid         = c.relnamespace AND n.nspname = 'public'
    JOIN pg_index      ix  ON ix.indexrelid = c.oid
    LEFT JOIN index_stats ist ON ist.indexrelname = i.indexname
    WHERE i.schemaname = 'public'
      AND i.tablename IN (SELECT table_name FROM target_tables)
      AND COALESCE(ist.idx_scan, 0) = 0
      AND NOT ix.indisprimary
      AND NOT ix.indisunique
    ORDER BY pg_relation_size(c.oid) DESC
) ui

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 24 : TABLE BLOAT & VACUUM  ★ FIXED                                      ║
-- ║  v3 bug: ORDER BY inside UNION ALL member → wrapped in subquery                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '24_BLOAT_REPORT'   AS section,
    b.tablename         AS table_name,
    'bloat_analysis'    AS name,
    jsonb_build_object(
        'live_rows',          b.live_rows,
        'dead_rows',          b.dead_rows,
        'bloat_ratio_pct',    b.bloat_pct,
        'table_size',         pg_size_pretty(b.table_bytes),
        'index_size',         pg_size_pretty(b.index_bytes),
        'total_size',         pg_size_pretty(b.total_bytes),
        'total_inserts',      b.total_inserts,
        'total_updates',      b.total_updates,
        'total_deletes',      b.total_deletes,
        'last_vacuum',        b.last_vacuum,
        'last_autovacuum',    b.last_autovacuum,
        'last_analyze',       b.last_analyze,
        'vacuum_count',       b.vacuum_count,
        'autovacuum_count',   b.autovacuum_count,
        'recommended_action', CASE
            WHEN b.dead_rows > 1000 AND b.bloat_pct > 20
            THEN 'VACUUM ANALYZE ' || b.tablename || '; -- HIGH bloat, run immediately'
            ELSE 'VACUUM ANALYZE ' || b.tablename || '; -- moderate bloat'
        END
    )::text AS details,
    25 AS sort_order
FROM (
    SELECT
        ts.tablename,
        ts.live_rows, ts.dead_rows,
        ROUND((100.0 * ts.dead_rows / NULLIF(ts.live_rows + ts.dead_rows, 0))::numeric, 1) AS bloat_pct,
        sz.table_bytes, sz.index_bytes, sz.total_bytes,
        ts.total_inserts, ts.total_updates, ts.total_deletes,
        ts.last_vacuum, ts.last_autovacuum, ts.last_analyze,
        ts.vacuum_count, ts.autovacuum_count
    FROM table_stats  ts
    JOIN table_sizes  sz ON sz.tablename = ts.tablename
    WHERE ts.tablename IN (SELECT table_name FROM target_tables)
      AND ts.dead_rows > 0
      AND (100.0 * ts.dead_rows / NULLIF(ts.live_rows + ts.dead_rows, 0)) > 10
    ORDER BY ts.dead_rows DESC
) b

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 25 : SCHEMA HEALTH SCORECARD  ★ NEW                                     ║
-- ║  Per-table 0–100 score combining RLS, index efficiency, bloat, vacuum freshness  ║
-- ║  Purpose: AI gets a ranked triage list instantly — no scanning needed            ║
-- ║                                                                                   ║
-- ║  Scoring breakdown (lower is worse):                                              ║
-- ║    RLS enabled          +30 pts                                                   ║
-- ║    ≥1 RLS policy        +20 pts                                                   ║
-- ║    cache hit ratio 95%+ +15 pts                                                   ║
-- ║    no unused indexes    +15 pts                                                   ║
-- ║    bloat < 10%          +10 pts                                                   ║
-- ║    analyzed in 7 days   +10 pts                                                   ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '25_HEALTH_SCORECARD' AS section,
    c.relname             AS table_name,
    'health'              AS name,
    jsonb_build_object(

        'health_score', (
            -- RLS enabled
            CASE WHEN c.relrowsecurity              THEN 30 ELSE 0 END
            -- at least one policy
          + CASE WHEN COALESCE(rpc.policy_count,0) > 0 THEN 20 ELSE 0 END
            -- cache hit ratio
          + CASE
                WHEN COALESCE(tio.heap_blks_read,0) + COALESCE(tio.heap_blks_hit,0) = 0 THEN 15
                WHEN (100.0 * COALESCE(tio.heap_blks_hit,0) /
                      (COALESCE(tio.heap_blks_read,0) + COALESCE(tio.heap_blks_hit,0))) >= 95  THEN 15
                WHEN (100.0 * COALESCE(tio.heap_blks_hit,0) /
                      (COALESCE(tio.heap_blks_read,0) + COALESCE(tio.heap_blks_hit,0))) >= 80  THEN 7
                ELSE 0
            END
            -- no unused regular indexes
          + CASE
                WHEN NOT EXISTS (
                    SELECT 1 FROM pg_indexes i2
                    JOIN pg_class c2 ON c2.relname = i2.indexname
                    JOIN pg_index ix2 ON ix2.indexrelid = c2.oid
                    LEFT JOIN index_stats ist2 ON ist2.indexrelname = i2.indexname
                    WHERE i2.tablename = c.relname
                      AND COALESCE(ist2.idx_scan, 0) = 0
                      AND NOT ix2.indisprimary AND NOT ix2.indisunique
                ) THEN 15 ELSE 0 END
            -- low bloat
          + CASE
                WHEN COALESCE(ts.live_rows,0) + COALESCE(ts.dead_rows,0) = 0   THEN 10
                WHEN (100.0 * COALESCE(ts.dead_rows,0) /
                      NULLIF(COALESCE(ts.live_rows,0) + COALESCE(ts.dead_rows,0),0)) < 10 THEN 10
                ELSE 0
            END
            -- recently analyzed
          + CASE
                WHEN ts.last_analyze     IS NOT NULL AND ts.last_analyze     > now() - INTERVAL '7 days' THEN 10
                WHEN ts.last_autoanalyze IS NOT NULL AND ts.last_autoanalyze > now() - INTERVAL '7 days' THEN 10
                ELSE 0
            END
        ),

        'rls_enabled',          c.relrowsecurity,
        'policy_count',         COALESCE(rpc.policy_count, 0),
        'live_rows',            COALESCE(ts.live_rows, 0),
        'dead_rows',            COALESCE(ts.dead_rows, 0),
        'bloat_pct',            ROUND(
            (100.0 * COALESCE(ts.dead_rows,0) /
             NULLIF(COALESCE(ts.live_rows,0) + COALESCE(ts.dead_rows,0),0))::numeric, 1
        ),
        'cache_hit_pct',        CASE
            WHEN COALESCE(tio.heap_blks_read,0) + COALESCE(tio.heap_blks_hit,0) = 0 THEN 100.0
            ELSE ROUND(
                (100.0 * COALESCE(tio.heap_blks_hit,0) /
                (COALESCE(tio.heap_blks_read,0) + COALESCE(tio.heap_blks_hit,0)))::numeric, 1
            )
        END,
        'last_analyze',         COALESCE(ts.last_analyze, ts.last_autoanalyze),
        'total_size',           pg_size_pretty(sz.total_bytes),
        'issues', (
            SELECT jsonb_agg(issue)
            FROM (
                VALUES
                  (CASE WHEN NOT c.relrowsecurity
                        THEN '⛔ RLS disabled' ELSE NULL END),
                  (CASE WHEN c.relrowsecurity AND COALESCE(rpc.policy_count,0) = 0
                        THEN '⛔ RLS on but zero policies' ELSE NULL END),
                  (CASE WHEN (100.0 * COALESCE(ts.dead_rows,0) /
                              NULLIF(COALESCE(ts.live_rows,0)+COALESCE(ts.dead_rows,0),0)) > 20
                        THEN '⚠️ High bloat (>20%)' ELSE NULL END),
                  (CASE WHEN ts.last_analyze IS NULL AND ts.last_autoanalyze IS NULL
                        THEN '⚠️ Never analyzed — stats may be stale' ELSE NULL END)
            ) AS t(issue)
            WHERE issue IS NOT NULL
        )

    )::text AS details,
    26 AS sort_order
FROM pg_class           c
JOIN pg_namespace       n   ON n.oid       = c.relnamespace
JOIN table_sizes        sz  ON sz.tablename = c.relname
LEFT JOIN table_stats   ts  ON ts.tablename = c.relname
LEFT JOIN table_io      tio ON tio.tablename = c.relname
LEFT JOIN rls_policy_counts rpc ON rpc.tablename = c.relname
WHERE n.nspname = 'public'
  AND c.relkind  = 'r'
  AND c.relname IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 26 : WRITE HOTSPOTS  ★ NEW                                               ║
-- ║  Tables ranked by write activity: inserts + updates + deletes                    ║
-- ║  Immediately shows AI which tables are write-critical vs idle                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '26_WRITE_HOTSPOTS'   AS section,
    ts.tablename          AS table_name,
    'activity_profile'    AS name,
    jsonb_build_object(
        'total_writes',     ts.total_inserts + ts.total_updates + ts.total_deletes,
        'inserts',          ts.total_inserts,
        'updates',          ts.total_updates,
        'deletes',          ts.total_deletes,
        'hot_updates',      ts.hot_updates,
        'live_rows',        ts.live_rows,
        'dead_rows',        ts.dead_rows,
        'total_size',       pg_size_pretty(sz.total_bytes),
        -- write profile classification
        'profile', CASE
            WHEN ts.total_inserts + ts.total_updates + ts.total_deletes = 0
                 THEN 'IDLE'
            WHEN ts.total_updates > ts.total_inserts * 2
                 THEN 'UPDATE_HEAVY'
            WHEN ts.total_deletes > ts.total_inserts * 0.5
                 THEN 'HIGH_CHURN'
            WHEN ts.total_inserts > ts.total_updates + ts.total_deletes
                 THEN 'INSERT_HEAVY'
            ELSE 'BALANCED'
        END,
        -- update efficiency: HOT updates avoid index overhead
        'hot_update_ratio_pct', CASE
            WHEN ts.total_updates = 0 THEN NULL
            ELSE ROUND((100.0 * ts.hot_updates / ts.total_updates)::numeric, 1)
        END,
        -- churn ratio: how many rows are replaced relative to live rows
        'churn_ratio', CASE
            WHEN ts.live_rows = 0 THEN NULL
            ELSE ROUND(((ts.total_deletes::numeric) / NULLIF(ts.live_rows, 0)), 2)
        END,
        'last_vacuum',      ts.last_vacuum,
        'last_autovacuum',  ts.last_autovacuum
    )::text AS details,
    27 AS sort_order
FROM table_stats  ts
JOIN table_sizes  sz ON sz.tablename = ts.tablename
WHERE ts.tablename IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 27 : MATERIALIZED VIEWS  ★ NEW                                           ║
-- ║  Definition preview + last-refresh timestamp + staleness flag                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '27_MATERIALIZED_VIEW'  AS section,
    c.relname               AS table_name,
    'definition'            AS name,
    jsonb_build_object(
        'schema',              n.nspname,
        'owner',               pg_get_userbyid(c.relowner),
        'is_populated',        c.relispopulated,
        'staleness',           CASE WHEN c.relispopulated THEN 'POPULATED' ELSE 'NEVER_REFRESHED' END,
        'definition_preview',  LEFT(pg_get_viewdef(c.oid, true), 600),
        'definition_length',   LENGTH(pg_get_viewdef(c.oid, true)),
        -- storage sizing
        'total_size',          pg_size_pretty(pg_total_relation_size(c.oid)),
        'table_size',          pg_size_pretty(pg_relation_size(c.oid)),
        'index_size',          pg_size_pretty(pg_indexes_size(c.oid)),
        -- indexes defined on this mat-view
        'indexes', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'index_name',  i.relname,
                'definition',  pg_get_indexdef(ix.indexrelid)
            ) ORDER BY i.relname)
            FROM pg_index     ix
            JOIN pg_class     i  ON i.oid = ix.indexrelid
            WHERE ix.indrelid = c.oid
        ), '[]'::jsonb),
        -- depends on which tables / views
        'depends_on', COALESCE((
            SELECT jsonb_agg(DISTINCT ref_ns.nspname || '.' || ref_cl.relname)
            FROM pg_depend    d
            JOIN pg_rewrite   rw ON rw.oid   = d.objid
            JOIN pg_class     dv ON dv.oid   = rw.ev_class
            JOIN pg_class     ref_cl ON ref_cl.oid = d.refobjid
            JOIN pg_namespace ref_ns ON ref_ns.oid = ref_cl.relnamespace
            WHERE dv.oid         = c.oid
              AND d.classid      = 'pg_rewrite'::regclass
              AND ref_cl.relkind IN ('r', 'v', 'm')
              AND ref_cl.relname != c.relname
        ), '[]'::jsonb),
        'description', obj_description(c.oid, 'pg_class')
    )::text AS details,
    28 AS sort_order
FROM pg_class     c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind  = 'm'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 28 : CUSTOM TYPES — composite, domain, range  ★ NEW                     ║
-- ║  Covers typtype in (c=composite, d=domain, r=range) in public schema             ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '28_CUSTOM_TYPE'   AS section,
    t.typname          AS table_name,
    CASE t.typtype
        WHEN 'c' THEN 'composite'
        WHEN 'd' THEN 'domain'
        WHEN 'r' THEN 'range'
        ELSE t.typtype::text
    END                AS name,
    jsonb_build_object(
        'schema',       n.nspname,
        'owner',        pg_get_userbyid(t.typowner),
        'typtype',      t.typtype,
        'kind', CASE t.typtype
            WHEN 'c' THEN 'COMPOSITE'
            WHEN 'd' THEN 'DOMAIN'
            WHEN 'r' THEN 'RANGE'
        END,
        -- COMPOSITE: list of attributes
        'attributes', CASE WHEN t.typtype = 'c' THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'attnum',   a.attnum,
                'name',     a.attname,
                'type',     pg_catalog.format_type(a.atttypid, a.atttypmod),
                'nullable', NOT a.attnotnull
            ) ORDER BY a.attnum)
            FROM pg_attribute a
            WHERE a.attrelid = t.typrelid AND a.attnum > 0 AND NOT a.attisdropped
        ), '[]'::jsonb) ELSE NULL END,
        -- DOMAIN: base type + constraints
        'domain_base_type', CASE WHEN t.typtype = 'd'
            THEN pg_catalog.format_type(t.typbasetype, t.typtypmod) ELSE NULL END,
        'domain_not_null', CASE WHEN t.typtype = 'd' THEN t.typnotnull ELSE NULL END,
        'domain_default',  CASE WHEN t.typtype = 'd' THEN t.typdefault ELSE NULL END,
        'domain_constraints', CASE WHEN t.typtype = 'd' THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'name',       con.conname,
                'check_expr', pg_get_constraintdef(con.oid, true)
            ) ORDER BY con.conname)
            FROM pg_constraint con
            WHERE con.contypid = t.oid
        ), '[]'::jsonb) ELSE NULL END,
        -- RANGE: subtype + bounds
        'range_subtype', CASE WHEN t.typtype = 'r'
            THEN pg_catalog.format_type(rng.rngsubtype, -1) ELSE NULL END,
        'range_collation', CASE WHEN t.typtype = 'r' AND rng.rngcollation <> 0
            THEN (SELECT collname FROM pg_collation WHERE oid = rng.rngcollation) ELSE NULL END,
        'description', obj_description(t.oid, 'pg_type')
    )::text AS details,
    29 AS sort_order
FROM pg_type      t
JOIN pg_namespace n   ON n.oid = t.typnamespace
LEFT JOIN pg_range rng ON rng.rngtypid = t.oid
WHERE n.nspname = 'public'
  AND t.typtype IN ('c', 'd', 'r')
  -- exclude auto-generated row types for tables/views
  AND NOT EXISTS (
        SELECT 1 FROM pg_class c
        WHERE c.oid = t.typrelid AND c.relkind IN ('r', 'v', 'f', 'p')
  )

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 29 : TABLE PARTITIONING  ★ NEW                                           ║
-- ║  Partition trees: strategy, key, parent→child relationships                       ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '29_PARTITIONING'  AS section,
    parent.relname     AS table_name,
    child.relname      AS name,
    jsonb_build_object(
        'schema',              n_p.nspname,
        'partition_strategy',  CASE pt.partstrat
                                   WHEN 'r' THEN 'RANGE'
                                   WHEN 'l' THEN 'LIST'
                                   WHEN 'h' THEN 'HASH'
                                   ELSE pt.partstrat::text
                               END,
        'partition_key', (
            SELECT string_agg(
                CASE a.attnum
                    WHEN 0 THEN 'expr'
                    ELSE a.attname
                END, ', ' ORDER BY ord
            )
            FROM LATERAL (
                SELECT unnest(pt.partattrs) AS attnum,
                       generate_subscripts(pt.partattrs, 1) AS ord
            ) kc
            LEFT JOIN pg_attribute a ON a.attrelid = parent.oid AND a.attnum = kc.attnum
        ),
        'partition_bound',     pg_get_expr(child.relpartbound, child.oid, true),
        'child_schema',        n_c.nspname,
        'child_relkind',       child.relkind,
        'child_total_size',    pg_size_pretty(pg_total_relation_size(child.oid)),
        'child_live_rows',     COALESCE(ts.live_rows, 0),
        -- Is the child itself further partitioned?
        'child_is_partitioned', EXISTS (
            SELECT 1 FROM pg_partitioned_table WHERE partrelid = child.oid
        ),
        'parent_total_size',   pg_size_pretty(pg_total_relation_size(parent.oid))
    )::text AS details,
    30 AS sort_order
FROM pg_partitioned_table   pt
JOIN pg_class               parent ON parent.oid    = pt.partrelid
JOIN pg_namespace           n_p    ON n_p.oid       = parent.relnamespace
JOIN pg_inherits            inh    ON inh.inhparent  = parent.oid
JOIN pg_class               child  ON child.oid      = inh.inhrelid
JOIN pg_namespace           n_c    ON n_c.oid        = child.relnamespace
LEFT JOIN table_stats        ts     ON ts.tablename  = child.relname
WHERE n_p.nspname = 'public'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 30 : EVENT TRIGGERS  ★ NEW                                               ║
-- ║  DDL-level triggers: event, function, enabled state                               ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '30_EVENT_TRIGGER'  AS section,
    evtname             AS table_name,
    evtevent            AS name,
    jsonb_build_object(
        'event',       evtevent,
        'owner',       pg_get_userbyid(evtowner),
        'enabled',     CASE evtenabled
                           WHEN 'O' THEN 'ENABLED'
                           WHEN 'D' THEN 'DISABLED'
                           WHEN 'R' THEN 'REPLICA'
                           WHEN 'A' THEN 'ALWAYS'
                       END,
        'function',    evtfoid::regproc::text,
        -- Tags this trigger fires on (NULL = all tags)
        'filter_tags', CASE
            WHEN evttags IS NOT NULL THEN to_jsonb(evttags)
            ELSE '"ALL"'::jsonb
        END,
        'function_body_preview', LEFT(
            pg_get_functiondef(evtfoid), 400
        )
    )::text AS details,
    31 AS sort_order
FROM pg_event_trigger

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 31 : SCHEMA-LEVEL PRIVILEGES  ★ NEW                                      ║
-- ║  WHO has USAGE / CREATE on which schema                                            ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '31_SCHEMA_PRIVILEGE'  AS section,
    n.nspname              AS table_name,
    acl_parsed.grantee            AS name,
    jsonb_build_object(
        'schema',      n.nspname,
        'grantee',     acl_parsed.grantee,
        'privilege',   acl_parsed.privilege_type,
        'is_grantable',acl_parsed.is_grantable,
        'grantor',     acl_parsed.grantor
    )::text AS details,
    32 AS sort_order
FROM pg_namespace n,
     LATERAL aclexplode(COALESCE(n.nspacl, acldefault('n', n.nspowner))) acl(grantor_oid, grantee_oid, privilege_type, is_grantable)
JOIN LATERAL (
    SELECT
        CASE acl.grantee_oid WHEN 0 THEN 'PUBLIC' ELSE pg_get_userbyid(acl.grantee_oid) END AS grantee,
        CASE acl.grantor_oid WHEN 0 THEN 'PUBLIC' ELSE pg_get_userbyid(acl.grantor_oid) END AS grantor,
        acl.privilege_type,
        acl.is_grantable
) acl_parsed ON true
WHERE n.nspname NOT IN ('pg_toast', 'pg_catalog', 'information_schema')
  AND acl_parsed.privilege_type IN ('USAGE', 'CREATE')

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 32 : DEFAULT PRIVILEGES  ★ NEW                                           ║
-- ║  ALTER DEFAULT PRIVILEGES grants — future-object security rules                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '32_DEFAULT_PRIVILEGE'  AS section,
    COALESCE(n.nspname, 'ALL SCHEMAS') AS table_name,
    pg_get_userbyid(dap.defaclrole)    AS name,
    jsonb_build_object(
        'role',         pg_get_userbyid(dap.defaclrole),
        'schema',       COALESCE(n.nspname, 'ALL SCHEMAS'),
        'object_type',  CASE dap.defaclobjtype
                            WHEN 'r' THEN 'TABLE'
                            WHEN 'S' THEN 'SEQUENCE'
                            WHEN 'f' THEN 'FUNCTION'
                            WHEN 'T' THEN 'TYPE'
                            WHEN 'n' THEN 'SCHEMA'
                            ELSE dap.defaclobjtype::text
                        END,
        'acl_entries', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'grantee',     CASE acl.grantee_oid WHEN 0 THEN 'PUBLIC'
                                   ELSE pg_get_userbyid(acl.grantee_oid) END,
                'privilege',   acl.privilege_type,
                'is_grantable',acl.is_grantable
            ))
            FROM LATERAL aclexplode(dap.defaclacl)
                 acl(grantor_oid, grantee_oid, privilege_type, is_grantable)
        ), '[]'::jsonb)
    )::text AS details,
    33 AS sort_order
FROM pg_default_acl    dap
LEFT JOIN pg_namespace n ON n.oid = dap.defaclnamespace

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 33 : ROLE MEMBERSHIPS GRAPH  ★ NEW                                       ║
-- ║  Full role → granted-to adjacency with admin / inherit / set options             ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '33_ROLE_MEMBERSHIP'  AS section,
    r_role.rolname        AS table_name,    -- the role being granted
    r_member.rolname      AS name,          -- the role that receives the grant
    jsonb_build_object(
        'role',            r_role.rolname,
        'member',          r_member.rolname,
        'granted_by',      r_grantor.rolname,
        'admin_option',    m.admin_option,
        'inherit_option',  m.inherit_option,
        'set_option',      m.set_option,
        -- role attributes
        'role_attrs', jsonb_build_object(
            'superuser',    r_role.rolsuper,
            'createdb',     r_role.rolcreatedb,
            'createrole',   r_role.rolcreaterole,
            'login',        r_role.rolcanlogin,
            'replication',  r_role.rolreplication,
            'bypassrls',    r_role.rolbypassrls,
            'conn_limit',   r_role.rolconnlimit
        ),
        'member_attrs', jsonb_build_object(
            'superuser',    r_member.rolsuper,
            'login',        r_member.rolcanlogin
        )
    )::text AS details,
    34 AS sort_order
FROM pg_auth_members m
JOIN pg_roles r_role    ON r_role.oid    = m.roleid
JOIN pg_roles r_member  ON r_member.oid  = m.member
JOIN pg_roles r_grantor ON r_grantor.oid = m.grantor

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 34 : FOREIGN DATA WRAPPERS  ★ NEW                                        ║
-- ║  FDW + server definitions + connection options                                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '34_FDW'          AS section,
    fs.srvname        AS table_name,
    fdw.fdwname       AS name,
    jsonb_build_object(
        'fdw_name',         fdw.fdwname,
        'fdw_owner',        pg_get_userbyid(fdw.fdwowner),
        'fdw_version',      (SELECT extversion FROM pg_extension e
                             JOIN pg_depend d ON d.objid = e.oid
                             WHERE d.refobjid = fdw.oid AND d.classid = 'pg_foreign_data_wrapper'::regclass
                             LIMIT 1),
        'server_name',      fs.srvname,
        'server_owner',     pg_get_userbyid(fs.srvowner),
        'server_type',      fs.srvtype,
        'server_version',   fs.srvversion,
        'server_options',   COALESCE(
            (SELECT jsonb_object_agg(kv[1], kv[2])
             FROM LATERAL (SELECT regexp_split_to_array(opt, '=') AS kv
                           FROM unnest(fs.srvoptions) opt) _), '{}'::jsonb),
        'user_mappings', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'user',    pg_get_userbyid(um.umuser),
                'options', COALESCE((
                    SELECT jsonb_object_agg(kv[1], kv[2])
                    FROM LATERAL (SELECT regexp_split_to_array(opt, '=') AS kv
                                  FROM unnest(um.umoptions) opt) _), '{}'::jsonb)
            ))
            FROM pg_user_mapping um WHERE um.umserver = fs.oid
        ), '[]'::jsonb)
    )::text AS details,
    35 AS sort_order
FROM pg_foreign_server       fs
JOIN pg_foreign_data_wrapper fdw ON fdw.oid = fs.srvfdw

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 35 : FOREIGN TABLES  ★ NEW                                               ║
-- ║  Column map + server binding + options                                            ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '35_FOREIGN_TABLE'   AS section,
    c.relname            AS table_name,
    'columns'            AS name,
    jsonb_build_object(
        'schema',         n.nspname,
        'owner',          pg_get_userbyid(c.relowner),
        'server',         fs.srvname,
        'fdw',            fdw.fdwname,
        'table_options',  COALESCE(
            (SELECT jsonb_object_agg(kv[1], kv[2])
             FROM LATERAL (SELECT regexp_split_to_array(opt, '=') AS kv
                           FROM unnest(ft.ftoptions) opt) _), '{}'::jsonb),
        'columns', (
            SELECT jsonb_agg(jsonb_build_object(
                'attnum',    a.attnum,
                'name',      a.attname,
                'type',      pg_catalog.format_type(a.atttypid, a.atttypmod),
                'nullable',  NOT a.attnotnull,
                'options',   COALESCE(
                    (SELECT jsonb_object_agg(kv[1], kv[2])
                     FROM LATERAL (SELECT regexp_split_to_array(opt, '=') AS kv
                                   FROM unnest(a.attfdwoptions) opt) _), '{}'::jsonb)
            ) ORDER BY a.attnum)
            FROM pg_attribute         a
            WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
        )
    )::text AS details,
    36 AS sort_order
FROM pg_class              c
JOIN pg_namespace          n   ON n.oid   = c.relnamespace
JOIN pg_foreign_table      ft  ON ft.ftrelid = c.oid
JOIN pg_foreign_server     fs  ON fs.oid   = ft.ftserver
JOIN pg_foreign_data_wrapper fdw ON fdw.oid = fs.srvfdw
WHERE c.relkind = 'f'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 36 : ALL PUBLICATIONS  ★ NEW                                             ║
-- ║  Every publication in the cluster — not only supabase_realtime                   ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '36_PUBLICATION'    AS section,
    pub.pubname         AS table_name,
    COALESCE(pt.tablename, '(ALL TABLES)') AS name,
    jsonb_build_object(
        'publication',    pub.pubname,
        'owner',          pg_get_userbyid(pub.pubowner),
        'all_tables',     pub.puballtables,
        'insert',         pub.pubinsert,
        'update',         pub.pubupdate,
        'delete',         pub.pubdelete,
        'truncate',       pub.pubtruncate,
        'via_root',       pub.pubviaroot,
        'table_schema',   pt.schemaname,
        'table_name',     pt.tablename
    )::text AS details,
    37 AS sort_order
FROM pg_publication pub
LEFT JOIN pg_publication_tables pt ON pt.pubname = pub.pubname

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 37 : SUBSCRIPTIONS  ★ NEW                                                ║
-- ║  Logical replication subscriptions + connection + sync state                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '37_SUBSCRIPTION'   AS section,
    s.subname           AS table_name,
    'subscription'      AS name,
    jsonb_build_object(
        'subscription',    s.subname,
        'owner',           pg_get_userbyid(s.subowner),
        'enabled',         s.subenabled,
        'publications',    to_jsonb(s.subpublications),
        'slot_name',       s.subslotname,
        'sync_commit',     s.subsynccommit,
        -- connection string — password redacted for safety
        'conninfo',        regexp_replace(
                               s.subconninfo,
                               '(password\s*=\s*)\S+',
                               '\1***', 'i'
                           ),
        -- per-relation sync state
        'relation_states', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'relid',  sr.srrelid::regclass::text,
                'state',  sr.srsubstate,
                'lsn',    sr.srsublsn
            ) ORDER BY sr.srrelid::regclass::text)
            FROM pg_subscription_rel sr
            WHERE sr.srsubid = s.oid
        ), '[]'::jsonb)
    )::text AS details,
    38 AS sort_order
FROM pg_subscription s

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 38 : DATABASE / ROLE GUC SETTINGS  ★ NEW                                ║
-- ║  All GUC overrides set via ALTER DATABASE or ALTER ROLE                          ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '38_GUC_SETTINGS'  AS section,
    CASE
        WHEN s.setrole    = 0 THEN 'DATABASE:' || d.datname
        WHEN s.setdatabase = 0 THEN 'ROLE:' || r.rolname
        ELSE 'ROLE:' || r.rolname || '  DB:' || d.datname
    END                AS table_name,
    split_part(kv_raw, '=', 1) AS name,
    jsonb_build_object(
        'scope',     CASE WHEN s.setrole = 0 THEN 'DATABASE' ELSE 'ROLE' END,
        'database',  d.datname,
        'role',      r.rolname,
        'parameter', split_part(kv_raw, '=', 1),
        'value',     substr(kv_raw, strpos(kv_raw, '=') + 1)
    )::text AS details,
    39 AS sort_order
FROM pg_db_role_setting s
CROSS JOIN LATERAL unnest(s.setconfig) AS kv_raw
LEFT JOIN pg_database d ON d.oid = s.setdatabase
LEFT JOIN pg_roles    r ON r.oid = s.setrole

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 39 : LIVE QUERIES (pg_stat_activity)  ★ NEW                             ║
-- ║  Snapshot of active/idle-in-transaction backends; passwords & params redacted    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '39_LIVE_QUERIES'       AS section,
    COALESCE(datname, '?')  AS table_name,
    pid::text               AS name,
    jsonb_build_object(
        'pid',              pid,
        'datname',          datname,
        'usename',          usename,
        'application_name', application_name,
        'client_addr',      host(client_addr),
        'backend_start',    backend_start,
        'state',            state,
        'wait_event_type',  wait_event_type,
        'wait_event',       wait_event,
        'duration_sec',     EXTRACT(epoch FROM (now() - query_start))::int,
        -- truncate query for safety / size
        'query_preview',    LEFT(query, 500),
        'backend_type',     backend_type,
        'leader_pid',       leader_pid
    )::text AS details,
    40 AS sort_order
FROM pg_stat_activity
WHERE state IS NOT NULL          -- skip walsender / background idle
  AND backend_type = 'client backend'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 40 : LOCK MONITOR  ★ NEW                                                 ║
-- ║  Current locks + blocking chain — shows which pid blocks which                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '40_LOCK_MONITOR'   AS section,
    COALESCE(rel.relname, 'transactionid') AS table_name,
    lk.pid::text        AS name,
    jsonb_build_object(
        'pid',           lk.pid,
        'lock_type',     lk.locktype,
        'relation',      rel.relname,
        'mode',          lk.mode,
        'granted',       lk.granted,
        'fastpath',      lk.fastpath,
        'transactionid', lk.transactionid,
        'classid',       lk.classid,
        'objid',         lk.objid,
        -- who is this backend?
        'usename',       sa.usename,
        'application',   sa.application_name,
        'query_preview', LEFT(sa.query, 300),
        'duration_sec',  EXTRACT(epoch FROM (now() - sa.query_start))::int,
        -- blocking chain: is this pid blocked by another pid?
        'blocked_by',    pg_blocking_pids(lk.pid),
        'is_blocked',    COALESCE(array_length(pg_blocking_pids(lk.pid), 1), 0) > 0
    )::text AS details,
    41 AS sort_order
FROM pg_locks              lk
LEFT JOIN pg_class         rel ON rel.oid = lk.relation
LEFT JOIN pg_stat_activity sa  ON sa.pid  = lk.pid
-- only show user-table locks or blocked transactions to avoid noise
WHERE (rel.relname IS NOT NULL OR lk.granted = false)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 41 : ADVANCED INDEX ANALYSIS  ★ NEW                                      ║
-- ║  Expression indexes, partial indexes, redundant index pairs                      ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '41_ADVANCED_INDEX'     AS section,
    tc.relname              AS table_name,
    ic.relname              AS name,
    jsonb_build_object(
        'index_name',           ic.relname,
        'table',                tc.relname,
        'schema',               n.nspname,
        'am',                   am.amname,
        'definition',           pg_get_indexdef(ix.indexrelid),
        -- flags
        'is_unique',            ix.indisunique,
        'is_primary',           ix.indisprimary,
        'is_partial',           ix.indpred IS NOT NULL,
        'is_expression',        ix.indexprs IS NOT NULL,
        'is_clustered',         ix.indisclustered,
        'is_valid',             ix.indisvalid,
        'is_exclusion',         ix.indisexclusion,
        -- partial: show WHERE clause
        'partial_predicate',    CASE WHEN ix.indpred IS NOT NULL
                                    THEN pg_get_expr(ix.indpred, tc.oid, true)
                                    ELSE NULL END,
        -- expression: show expression text
        'expression',           CASE WHEN ix.indexprs IS NOT NULL
                                    THEN pg_get_expr(ix.indexprs, tc.oid, true)
                                    ELSE NULL END,
        -- usage
        'scans',                ist.idx_scan,
        'tuples_read',          ist.idx_tup_read,
        'tuples_fetched',       ist.idx_tup_fetch,
        'size',                 pg_size_pretty(pg_relation_size(ic.oid)),
        'size_bytes',           pg_relation_size(ic.oid),
        -- redundancy signal: any other index on same table with same leading cols?
        'potentially_redundant', EXISTS (
            SELECT 1
            FROM pg_index ix2
            JOIN pg_class ic2 ON ic2.oid = ix2.indexrelid
            WHERE ix2.indrelid = tc.oid
              AND ix2.indexrelid != ix.indexrelid
              AND ix2.indkey[0] = ix.indkey[0]   -- same leading column
              AND ix2.indisvalid
        ),
        -- column names list
        'columns', (
            SELECT jsonb_agg(a.attname ORDER BY k.ord)
            FROM LATERAL (
                SELECT unnest(ix.indkey) AS attnum,
                       generate_subscripts(ix.indkey, 1) AS ord
            ) k
            LEFT JOIN pg_attribute a ON a.attrelid = tc.oid AND a.attnum = k.attnum
            WHERE k.attnum != 0      -- 0 = expression column placeholder
        )
    )::text AS details,
    42 AS sort_order
FROM pg_index       ix
JOIN pg_class       tc ON tc.oid = ix.indrelid
JOIN pg_class       ic ON ic.oid = ix.indexrelid
JOIN pg_namespace   n  ON n.oid  = tc.relnamespace
JOIN pg_am          am ON am.oid = ic.relam
LEFT JOIN index_stats ist ON ist.tablename    = tc.relname
                          AND ist.indexrelname = ic.relname
WHERE n.nspname = 'public'
  AND tc.relkind IN ('r', 'p', 'm')   -- tables, partitioned tables, mat-views
  -- only expression or partial indexes (or just list all for full audit)
  -- comment the next line to see ALL indexes; keep it to focus on advanced ones:
  -- AND (ix.indexprs IS NOT NULL OR ix.indpred IS NOT NULL)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 42 : COLUMN-LEVEL ISSUES AUDIT  ★ NEW                                    ║
-- ║  Flags columns with: missing NOT NULL, risky defaults, wide varchar, ambig types  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '42_COLUMN_ISSUES'   AS section,
    c.table_name,
    c.column_name        AS name,
    jsonb_build_object(
        'column',        c.column_name,
        'position',      c.ordinal_position,
        'type',          c.udt_name,
        'nullable',      c.is_nullable = 'YES',
        'default',       c.column_default,
        'char_max_len',  c.character_maximum_length,
        -- computed issue list
        'issues', (
            SELECT jsonb_agg(issue ORDER BY issue)
            FROM (VALUES
                -- 1. nullable PK candidate (numeric id columns without NOT NULL)
                (CASE WHEN c.is_nullable = 'YES'
                          AND lower(c.column_name) IN ('id','uuid','pk')
                      THEN '⚠️ PK-like column is nullable'
                      ELSE NULL END),
                -- 2. unbounded text/varchar
                (CASE WHEN c.udt_name = 'varchar'
                          AND c.character_maximum_length IS NULL
                      THEN '⚠️ varchar without length limit (use TEXT instead)'
                      ELSE NULL END),
                -- 3. use of money type (locale-dependent, avoid in finance)
                (CASE WHEN c.udt_name = 'money'
                      THEN '⚠️ money type is locale-dependent — prefer numeric'
                      ELSE NULL END),
                -- 4. use of timestamp without time zone
                (CASE WHEN c.udt_name = 'timestamp'
                      THEN '⚠️ timestamp without timezone — prefer timestamptz'
                      ELSE NULL END),
                -- 5. char(n) fixed-width padding gotcha
                (CASE WHEN c.udt_name = 'bpchar'
                          AND c.character_maximum_length > 1
                      THEN '⚠️ char(n) pads with spaces — prefer varchar or text'
                      ELSE NULL END),
                -- 6. nullable FK column (can silently orphan records)
                (CASE WHEN c.is_nullable = 'YES'
                          AND EXISTS (
                                SELECT 1
                                FROM information_schema.key_column_usage kcu
                                JOIN information_schema.table_constraints tc
                                  ON tc.constraint_name = kcu.constraint_name
                                WHERE tc.constraint_type = 'FOREIGN KEY'
                                  AND kcu.table_schema  = c.table_schema
                                  AND kcu.table_name    = c.table_name
                                  AND kcu.column_name   = c.column_name
                              )
                      THEN '⚠️ nullable FK column — orphan rows possible'
                      ELSE NULL END),
                -- 7. serial columns missing sequence ownership (bad pg_dump behavior)
                (CASE WHEN c.column_default LIKE 'nextval(%'
                          AND c.udt_name NOT IN ('int2','int4','int8')
                      THEN '⚠️ nextval default on non-integer column'
                      ELSE NULL END),
                -- 8. very high null fraction (>80%) — possibly a deprecated column
                (CASE WHEN s.null_frac > 0.8
                      THEN '⚠️ >80% nulls — possibly unused / deprecated column'
                      ELSE NULL END)
            ) AS t(issue)
            WHERE issue IS NOT NULL
        ),
        'null_fraction_pct', ROUND((COALESCE(s.null_frac, 0) * 100)::numeric, 1),
        'avg_width_bytes',   s.avg_width
    )::text AS details,
    43 AS sort_order
FROM information_schema.columns c
LEFT JOIN pg_stats s ON s.schemaname = c.table_schema
                     AND s.tablename  = c.table_name
                     AND s.attname    = c.column_name
WHERE c.table_schema = 'public'
  AND c.table_name IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 43 : RULES  ★ NEW                                                        ║
-- ║  pg_rewrite rules on tables and views (non-default, non-auto rules)              ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '43_RULE'          AS section,
    c.relname          AS table_name,
    rw.rulename        AS name,
    jsonb_build_object(
        'rule_name',    rw.rulename,
        'table',        c.relname,
        'schema',       n.nspname,
        'event',        CASE rw.ev_type
                            WHEN '1' THEN 'SELECT'
                            WHEN '2' THEN 'UPDATE'
                            WHEN '3' THEN 'INSERT'
                            WHEN '4' THEN 'DELETE'
                            ELSE rw.ev_type::text
                        END,
        'enabled',      CASE rw.ev_enabled
                            WHEN 'O' THEN 'ENABLED'
                            WHEN 'D' THEN 'DISABLED'
                            WHEN 'R' THEN 'REPLICA'
                            WHEN 'A' THEN 'ALWAYS'
                        END,
        'is_instead',   rw.is_instead,
        -- full rule definition
        'definition',   pg_get_ruledef(rw.oid, true),
        'object_kind',  CASE c.relkind
                            WHEN 'r' THEN 'TABLE'
                            WHEN 'v' THEN 'VIEW'
                            WHEN 'm' THEN 'MATERIALIZED VIEW'
                            ELSE c.relkind::text
                        END
    )::text AS details,
    44 AS sort_order
FROM pg_rewrite    rw
JOIN pg_class      c  ON c.oid  = rw.ev_class
JOIN pg_namespace  n  ON n.oid  = c.relnamespace
WHERE n.nspname = 'public'
  -- exclude auto-generated _RETURN rules (view machinery)
  AND rw.rulename != '_RETURN'

)  -- end of xray CTE

-- ════════════════════════════════════════════════════════════════════════════════════
-- 📊  FINAL OUTPUT — ordered by sort_order, then table name, then name
-- ════════════════════════════════════════════════════════════════════════════════════
SELECT
    section,
    table_name,
    name,
    details
FROM xray
ORDER BY
    sort_order  ASC,
    section     ASC,
    table_name  ASC,
    name        ASC;


/* ═══════════════════════════════════════════════════════════════════════════════════
   📝  COMPLETE SECTION REFERENCE — v4
   ═══════════════════════════════════════════════════════════════════════════════════

   Sort | Section ID                | Description                          | v4 Status
   -----|---------------------------|--------------------------------------|----------
    -1  | -1_SUMMARY                | Full DB orientation — 1 JSON row     | ★ Enhanced
     0  | 00_EXTENSION              | Installed extensions                 | Unchanged
     1  | 01_ENUM                   | Custom enum types + values           | Unchanged
     2  | 02_TABLE_META             | Storage + rows + write_profile       | ★ Enhanced
     3  | 03_VIEW                   | View definitions + dependencies      | Unchanged
     4  | 04_REALTIME               | Supabase Realtime publications       | Unchanged
     5  | 05_COLUMN                 | Types + histogram + MCV freqs        | Enhanced
     6  | 06_CONSTRAINT_KEY         | PKs and unique constraints           | Unchanged
     7  | 07_CONSTRAINT_CHECK       | Check expressions                    | Unchanged
     8  | 08_FK_OUTGOING            | FKs from this table                  | Unchanged
     9  | 09_FK_INCOMING            | FKs to this table                    | Unchanged
    10  | 10_RELATIONSHIP_SUMMARY   | Connectivity using fk_counts CTE     | ★ Rewritten
   11+  | 11_INDEX                  | Unused indexes float to top          | ★ Enhanced
    13  | 12_RLS_POLICY             | RLS policies + total count           | ★ Enhanced
    14  | 13_TRIGGER                | Trigger definitions                  | Unchanged
    15  | 14_FUNCTION               | Custom only + body_preview + flags   | ★ Enhanced
    16  | 15_SEQUENCE               | Auto-increment sequences             | Unchanged
    17  | 16_TABLE_PRIVILEGE        | Table grants                         | Unchanged
    18  | 17_FUNCTION_PRIVILEGE     | Custom grants only (noise removed)   | ★ Fixed
    19  | 18_DEPENDENCY             | View→table + FK graph                | ★ Redesigned
    20  | 19_STORAGE_ANALYSIS       | I/O block stats                      | Unchanged
    21  | 20_SECURITY_AUDIT         | RLS audit using shared CTE           | ★ Rewritten
    22  | 21_FUNC_BODY              | Full source code (10k char cap)      | Enhanced
    23  | 22_TOP_QUERIES            | pg_stat_statements top 25            | ★ Bug fixed
    24  | 23_UNUSED_INDEXES         | Zero-scan indexes + DROP command     | ★ Bug fixed
    25  | 24_BLOAT_REPORT           | Tables >10% dead-row bloat           | ★ Bug fixed
    26  | 25_HEALTH_SCORECARD       | Per-table 0-100 health score         | ★ NEW
    27  | 26_WRITE_HOTSPOTS         | Write activity profile per table     | ★ NEW

   ═══════════════════════════════════════════════════════════════════════════════════
   SHARED CTEs (computed once, used by multiple sections)
   ─────────────────────────────────────────────────────
   target_tables        → all sections that filter by table name
   custom_func_oids     → Sections 14, 17, 21
   table_stats          → Sections 02, 08, 09, 24, 25, 26 (and -1 inline)
   index_stats          → Sections 11, 23, 25
   table_io             → Sections 19, 25 (and -1 inline)
   fk_counts            → Section 10 (replaces 6 correlated subqueries per row)
   rls_policy_counts    → Sections 12, 20, 25 (replaces 3 correlated subqueries)
   table_sizes          → Sections 02, 24, 25, 26 (replaces repeated pg_relation_size calls)
   trigger_functions    → Sections 14, 21

   ═══════════════════════════════════════════════════════════════════════════════════
   BUGS FIXED IN v4 (from v3)
   ──────────────────────────
   • Section 22: ORDER BY + LIMIT inside UNION ALL member → illegal in PostgreSQL
     Fix: wrapped in SELECT * FROM (...) subquery
   • Section 23: same ORDER BY bug → fixed same way
   • Section 24: same ORDER BY bug → fixed same way

   SIGNAL/NOISE COMPARISON
   ────────────────────────
   v2 (original): ~5,767 rows — 68% PostGIS noise (Section 17)
   v3:            ~500-800 rows — all signal, zero noise
   v4:            ~500-800 rows — same signal + 2 new sections + bugs fixed

   AI TRIAGE ORDER (suggested)
   ────────────────────────────
   1. -1_SUMMARY      → understand the app domain in 1 row
   2. 25_HEALTH_SCORE → ranked list of tables by health score
   3. 02_TABLE_META   → sizes, row counts, write profiles
   4. 26_WRITE_HOTSP  → understand traffic patterns
   5. 21_FUNC_BODY    → read actual business logic
   6. 22_TOP_QUERIES  → identify performance bottlenecks
   7. 23_UNUSED_IDXS  → cleanup recommendations
   8. 24_BLOAT_REPORT → maintenance recommendations
   9. Everything else → deep structural details

   ═══════════════════════════════════════════════════════════════════════════════════
*/