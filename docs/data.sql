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
   
   🔬 PROFESSIONAL DATABASE X-RAY ANALYSIS SUITE
   ═══════════════════════════════════════════════════════════════════════════════════
   
   📋 DESCRIPTION:
   A comprehensive PostgreSQL database introspection query that provides deep
   insights into database structure, relationships, performance metrics, and
   security configurations.
   
   🎯 FEATURES:
   ├── Extensions & Configuration
   ├── Data Types (ENUMs)
   ├── Tables & Storage Analytics
   ├── Views with Dependency Mapping
   ├── Realtime Publication Status
   ├── Column Definitions & Statistics
   ├── Constraints (PK, Unique, Check, FK)
   ├── Relationship Mapping (Incoming/Outgoing)
   ├── Indexes & Usage Statistics
   ├── Row Level Security Policies
   ├── Triggers & Automation
   ├── Functions & Procedures
   ├── Sequences & Auto-Increment
   ├── Privileges & Access Control
   ├── Dependency Graph
   ├── Storage Analysis
   └── Security Audit Report
   
   🔧 USAGE:
   Execute in PostgreSQL/Supabase SQL Editor
   Results are ordered by section for easy navigation
   
   📊 OUTPUT FORMAT:
   | section | table_name | name | details |
   
   🏷️ VERSION: 2.0.0
   📅 UPDATED: 2026-01-02
   👤 AUTHOR: Database Analytics Suite
   
   ═══════════════════════════════════════════════════════════════════════════════════
*/

-- ════════════════════════════════════════════════════════════════════════════════════
-- 📦 CONFIGURATION & PRE-QUERIES
-- ════════════════════════════════════════════════════════════════════════════════════

WITH 
-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ 🎯 TARGET TABLES: Filter for public schema base tables                          │
-- └─────────────────────────────────────────────────────────────────────────────────┘
target_tables AS (
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ 📊 TABLE STATISTICS: Live row counts and maintenance info                       │
-- └─────────────────────────────────────────────────────────────────────────────────┘
table_stats AS (
    SELECT 
        pst.schemaname,
        pst.relname AS tablename,
        pst.n_live_tup AS live_rows,
        pst.n_dead_tup AS dead_rows,
        pst.n_tup_ins AS total_inserts,
        pst.n_tup_upd AS total_updates,
        pst.n_tup_del AS total_deletes,
        pst.n_tup_hot_upd AS hot_updates,
        pst.last_vacuum,
        pst.last_autovacuum,
        pst.last_analyze,
        pst.last_autoanalyze,
        pst.vacuum_count,
        pst.autovacuum_count,
        pst.analyze_count,
        pst.autoanalyze_count
    FROM pg_stat_user_tables pst
    WHERE pst.schemaname = 'public'
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ 📈 INDEX STATISTICS: Index usage and performance metrics                        │
-- └─────────────────────────────────────────────────────────────────────────────────┘
index_stats AS (
    SELECT 
        schemaname,
        relname AS tablename,
        indexrelname,
        idx_scan,
        idx_tup_read,
        idx_tup_fetch
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
),

-- ┌─────────────────────────────────────────────────────────────────────────────────┐
-- │ 🗄️ TABLE IO STATS: Read/Write statistics                                        │
-- └─────────────────────────────────────────────────────────────────────────────────┘
table_io AS (
    SELECT 
        schemaname,
        relname AS tablename,
        heap_blks_read,
        heap_blks_hit,
        idx_blks_read,
        idx_blks_hit,
        toast_blks_read,
        toast_blks_hit
    FROM pg_statio_user_tables
    WHERE schemaname = 'public'
),

-- ════════════════════════════════════════════════════════════════════════════════════
-- 🔬 MAIN X-RAY ANALYSIS
-- ════════════════════════════════════════════════════════════════════════════════════

xray AS (

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 00: DATABASE EXTENSIONS                                                  ║
-- ║  📦 Lists all installed PostgreSQL extensions                                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT 
    '00_EXTENSION' AS section,
    e.extname AS table_name, 
    'configuration' AS name,
    jsonb_build_object(
        'version', e.extversion,
        'schema', n.nspname,
        'relocatable', e.extrelocatable,
        'owner', pg_get_userbyid(e.extowner),
        'description', COALESCE(
            (SELECT description FROM pg_description WHERE objoid = e.oid), 
            'No description'
        )
    )::text AS details,
    0 AS sort_order
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 01: ENUM TYPES                                                           ║
-- ║  🏷️ Custom enumeration types with their values                                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '01_ENUM' AS section,
    t.typname AS table_name,
    'definition' AS name,
    jsonb_build_object(
        'value_count', COUNT(*),
        'values', jsonb_agg(e.enumlabel ORDER BY e.enumsortorder),
        'schema', n.nspname,
        'owner', pg_get_userbyid(t.typowner),
        'oid', t.oid
    )::text AS details,
    1 AS sort_order
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_namespace n ON t.typnamespace = n.oid
WHERE n.nspname = 'public'
GROUP BY t.typname, t.typowner, n.nspname, t.oid

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 02: TABLE METADATA & STORAGE                                             ║
-- ║  📊 Comprehensive table information and storage statistics                        ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '02_TABLE_META' AS section,
    c.relname AS table_name,
    'storage_info' AS name,
    jsonb_build_object(
        'owner', pg_get_userbyid(c.relowner),
        'storage', jsonb_build_object(
            'total_size', pg_size_pretty(pg_total_relation_size(c.oid)),
            'total_bytes', pg_total_relation_size(c.oid),
            'table_size', pg_size_pretty(pg_relation_size(c.oid)),
            'index_size', pg_size_pretty(pg_indexes_size(c.oid)),
            'toast_size', pg_size_pretty(COALESCE(pg_total_relation_size(c.reltoastrelid), 0))
        ),
        'rows', jsonb_build_object(
            'live', COALESCE(ts.live_rows, 0),
            'dead', COALESCE(ts.dead_rows, 0),
            'estimated', c.reltuples::bigint
        ),
        'operations', jsonb_build_object(
            'inserts', COALESCE(ts.total_inserts, 0),
            'updates', COALESCE(ts.total_updates, 0),
            'deletes', COALESCE(ts.total_deletes, 0),
            'hot_updates', COALESCE(ts.hot_updates, 0)
        ),
        'rls_enabled', c.relrowsecurity,
        'rls_forced', c.relforcerowsecurity,
        'fillfactor', COALESCE(
            (SELECT option_value FROM pg_options_to_table(c.reloptions) WHERE option_name = 'fillfactor'), 
            '100'
        ),
        'maintenance', jsonb_build_object(
            'last_vacuum', ts.last_vacuum,
            'last_autovacuum', ts.last_autovacuum,
            'last_analyze', ts.last_analyze,
            'vacuum_count', ts.vacuum_count,
            'analyze_count', ts.analyze_count
        ),
        'bloat_percentage', ROUND(
            (100.0 * COALESCE(ts.dead_rows, 0) / NULLIF(COALESCE(ts.live_rows, 0) + COALESCE(ts.dead_rows, 0), 0))::numeric, 
            2
        ),
        'description', COALESCE(obj_description(c.oid, 'pg_class'), 'No description')
    )::text AS details,
    2 AS sort_order
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
LEFT JOIN table_stats ts ON ts.tablename = c.relname
WHERE n.nspname = 'public' 
  AND c.relkind = 'r' 
  AND c.relname IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 03: VIEWS                                                                ║
-- ║  👁️ View definitions with dependency tracking                                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '03_VIEW' AS section,
    v.table_name,
    'definition' AS name,
    jsonb_build_object(
        'is_updatable', v.is_updatable,
        'is_insertable_into', v.is_insertable_into,
        'check_option', v.check_option,
        'definition_preview', LEFT(v.view_definition, 500),
        'definition_length', LENGTH(v.view_definition),
        'depends_on', COALESCE((
            SELECT jsonb_agg(DISTINCT ref_table)
            FROM (
                SELECT dependent_ns.nspname || '.' || ref_class.relname AS ref_table
                FROM pg_depend d
                JOIN pg_rewrite rw ON rw.oid = d.objid
                JOIN pg_class dependent_view ON dependent_view.oid = rw.ev_class
                JOIN pg_class ref_class ON ref_class.oid = d.refobjid
                JOIN pg_namespace dependent_ns ON dependent_ns.oid = ref_class.relnamespace
                WHERE dependent_view.relname = v.table_name
                  AND d.classid = 'pg_rewrite'::regclass
                  AND ref_class.relkind IN ('r', 'v')
                  AND ref_class.relname != v.table_name
            ) deps
        ), '[]'::jsonb)
    )::text AS details,
    3 AS sort_order
FROM information_schema.views v
WHERE v.table_schema = 'public'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 04: REALTIME PUBLICATIONS                                                ║
-- ║  ⚡ Supabase Realtime enabled tables                                              ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '04_REALTIME' AS section,
    ppt.tablename AS table_name,
    'publication' AS name,
    jsonb_build_object(
        'publication_name', ppt.pubname,
        'schema', ppt.schemaname,
        'events', ARRAY['INSERT', 'UPDATE', 'DELETE'],
        'active', true
    )::text AS details,
    4 AS sort_order
FROM pg_publication_tables ppt
WHERE ppt.pubname = 'supabase_realtime' 
  AND ppt.schemaname = 'public'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 05: COLUMNS                                                              ║
-- ║  📋 Column definitions with statistics and metadata                               ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '05_COLUMN' AS section,
    c.table_name,
    c.column_name AS name,
    jsonb_build_object(
        'position', c.ordinal_position,
        'type', jsonb_build_object(
            'data_type', c.data_type,
            'udt_name', c.udt_name,
            'char_max_length', c.character_maximum_length,
            'numeric_precision', c.numeric_precision,
            'numeric_scale', c.numeric_scale
        ),
        'nullable', c.is_nullable = 'YES',
        'default', c.column_default,
        'identity', CASE 
            WHEN c.is_identity = 'YES' THEN c.identity_generation 
            ELSE NULL 
        END,
        'generated', CASE 
            WHEN c.is_generated = 'ALWAYS' THEN c.generation_expression 
            ELSE NULL 
        END,
        'statistics', jsonb_build_object(
            'avg_width_bytes', COALESCE(s.avg_width, 0),
            'distinct_values', ROUND(COALESCE(s.n_distinct, 0)::numeric, 2),
            'null_fraction_pct', ROUND((COALESCE(s.null_frac, 0) * 100)::numeric, 2),
            'correlation', ROUND(COALESCE(s.correlation, 0)::numeric, 4),
            'most_common_values', CASE 
                WHEN s.most_common_vals IS NOT NULL 
                THEN LEFT(s.most_common_vals::text, 100)
                ELSE NULL
            END
        ),
        'description', pgd.description
    )::text AS details,
    c.ordinal_position AS sort_order
FROM information_schema.columns c
LEFT JOIN pg_stats s ON s.tablename = c.table_name 
    AND s.attname = c.column_name 
    AND s.schemaname = 'public'
LEFT JOIN pg_class pc ON pc.relname = c.table_name
LEFT JOIN pg_namespace pn ON pn.oid = pc.relnamespace AND pn.nspname = 'public'
LEFT JOIN pg_attribute a ON a.attrelid = pc.oid AND a.attname = c.column_name
LEFT JOIN pg_description pgd ON pgd.objoid = pc.oid AND pgd.objsubid = a.attnum
WHERE c.table_schema = 'public' 
  AND c.table_name IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 06: PRIMARY KEY & UNIQUE CONSTRAINTS                                     ║
-- ║  🔑 Primary keys and unique constraints                                           ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '06_CONSTRAINT_KEY' AS section,
    tc.table_name,
    tc.constraint_name AS name,
    jsonb_build_object(
        'type', tc.constraint_type,
        'columns', jsonb_agg(kcu.column_name ORDER BY kcu.ordinal_position),
        'deferrable', tc.is_deferrable = 'YES',
        'initially_deferred', tc.initially_deferred = 'YES'
    )::text AS details,
    6 AS sort_order
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name 
    AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE') 
  AND tc.table_schema = 'public'
  AND tc.table_name IN (SELECT table_name FROM target_tables)
GROUP BY tc.table_name, tc.constraint_name, tc.constraint_type, 
         tc.is_deferrable, tc.initially_deferred

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 07: CHECK CONSTRAINTS                                                    ║
-- ║  ✓ Check constraints with validation expressions                                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '07_CONSTRAINT_CHECK' AS section,
    tc.table_name,
    tc.constraint_name AS name,
    jsonb_build_object(
        'type', 'CHECK',
        'expression', cc.check_clause,
        'enforced', true
    )::text AS details,
    7 AS sort_order
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc 
    ON tc.constraint_name = cc.constraint_name
    AND tc.constraint_schema = cc.constraint_schema
WHERE tc.constraint_type = 'CHECK' 
  AND tc.table_schema = 'public'
  AND tc.table_name IN (SELECT table_name FROM target_tables)
  AND tc.constraint_name NOT LIKE '%_not_null' -- Exclude auto-generated NOT NULL constraints

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 08: FOREIGN KEYS (OUTGOING)                                              ║
-- ║  ➡️ References FROM this table TO other tables                                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '08_FK_OUTGOING' AS section,
    tc.table_name,
    tc.constraint_name AS name,
    jsonb_build_object(
        'direction', 'OUTGOING',
        'source', jsonb_build_object(
            'table', tc.table_name,
            'columns', (
                SELECT jsonb_agg(kcu.column_name ORDER BY kcu.ordinal_position)
                FROM information_schema.key_column_usage kcu
                WHERE kcu.constraint_name = tc.constraint_name
                  AND kcu.table_schema = tc.table_schema
            )
        ),
        'target', jsonb_build_object(
            'table', ccu.table_name,
            'columns', (
                SELECT jsonb_agg(ccu2.column_name)
                FROM information_schema.constraint_column_usage ccu2
                WHERE ccu2.constraint_name = tc.constraint_name
                  AND ccu2.table_schema = ccu.table_schema
            )
        ),
        'rules', jsonb_build_object(
            'on_update', rc.update_rule,
            'on_delete', rc.delete_rule,
            'match_type', rc.match_option
        ),
        'relationship_type', CASE 
            WHEN EXISTS (
                SELECT 1 FROM information_schema.table_constraints tc2
                JOIN information_schema.key_column_usage kcu2 ON tc2.constraint_name = kcu2.constraint_name
                WHERE tc2.table_name = tc.table_name 
                  AND tc2.table_schema = 'public'
                  AND tc2.constraint_type = 'UNIQUE'
                  AND kcu2.column_name = (
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
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_schema = 'public'
  AND tc.table_name IN (SELECT table_name FROM target_tables)
GROUP BY tc.table_name, tc.constraint_name, tc.table_schema, 
         ccu.table_name, ccu.table_schema,
         rc.match_option, rc.update_rule, rc.delete_rule

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 09: FOREIGN KEYS (INCOMING)                                              ║
-- ║  ⬅️ References TO this table FROM other tables                                    ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '09_FK_INCOMING' AS section,
    ccu.table_name AS table_name,
    tc.constraint_name AS name,
    jsonb_build_object(
        'direction', 'INCOMING',
        'referenced_by', jsonb_build_object(
            'table', tc.table_name,
            'columns', (
                SELECT jsonb_agg(kcu.column_name ORDER BY kcu.ordinal_position)
                FROM information_schema.key_column_usage kcu
                WHERE kcu.constraint_name = tc.constraint_name
                  AND kcu.table_schema = tc.table_schema
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
                WHEN rc.delete_rule = 'CASCADE' THEN 'HIGH'
                WHEN rc.delete_rule = 'SET NULL' THEN 'MEDIUM'
                WHEN rc.delete_rule IN ('RESTRICT', 'NO ACTION') THEN 'PROTECTED'
                ELSE 'UNKNOWN'
            END,
            'warning', CASE 
                WHEN rc.delete_rule = 'CASCADE' THEN '⚠️ Deleting rows will cascade to ' || tc.table_name
                ELSE NULL
            END
        )
    )::text AS details,
    9 AS sort_order
FROM information_schema.referential_constraints rc
JOIN information_schema.table_constraints tc ON tc.constraint_name = rc.constraint_name
JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = rc.constraint_name
WHERE ccu.table_schema = 'public'
  AND ccu.table_name IN (SELECT table_name FROM target_tables)
  AND tc.table_name != ccu.table_name
GROUP BY ccu.table_name, tc.table_name, tc.constraint_name, tc.table_schema,
         rc.delete_rule, rc.update_rule

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 10: RELATIONSHIP SUMMARY                                                 ║
-- ║  🔗 Quick overview of table connectivity                                          ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '10_RELATIONSHIP_SUMMARY' AS section,
    t.table_name,
    'connections' AS name,
    jsonb_build_object(
        'outgoing_fk_count', (
            SELECT COUNT(*) 
            FROM information_schema.table_constraints tc 
            WHERE tc.table_name = t.table_name 
              AND tc.table_schema = 'public'
              AND tc.constraint_type = 'FOREIGN KEY'
        ),
        'incoming_fk_count', (
            SELECT COUNT(DISTINCT tc.constraint_name) 
            FROM information_schema.constraint_column_usage ccu
            JOIN information_schema.table_constraints tc ON tc.constraint_name = ccu.constraint_name
            WHERE ccu.table_name = t.table_name 
              AND ccu.table_schema = 'public'
              AND tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_name != t.table_name
        ),
        'total_connections', (
            SELECT COUNT(*) 
            FROM information_schema.table_constraints tc 
            WHERE tc.table_name = t.table_name 
              AND tc.table_schema = 'public'
              AND tc.constraint_type = 'FOREIGN KEY'
        ) + (
            SELECT COUNT(DISTINCT tc.constraint_name) 
            FROM information_schema.constraint_column_usage ccu
            JOIN information_schema.table_constraints tc ON tc.constraint_name = ccu.constraint_name
            WHERE ccu.table_name = t.table_name 
              AND ccu.table_schema = 'public'
              AND tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_name != t.table_name
        ),
        'is_isolated', (
            SELECT COUNT(*) 
            FROM information_schema.table_constraints tc 
            WHERE tc.table_name = t.table_name 
              AND tc.table_schema = 'public'
              AND tc.constraint_type = 'FOREIGN KEY'
        ) = 0 AND (
            SELECT COUNT(DISTINCT tc.constraint_name) 
            FROM information_schema.constraint_column_usage ccu
            JOIN information_schema.table_constraints tc ON tc.constraint_name = ccu.constraint_name
            WHERE ccu.table_name = t.table_name 
              AND ccu.table_schema = 'public'
              AND tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_name != t.table_name
        ) = 0
    )::text AS details,
    10 AS sort_order
FROM target_tables t

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 11: INDEXES                                                              ║
-- ║  📇 Index definitions with usage statistics                                       ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '11_INDEX' AS section,
    i.tablename AS table_name,
    i.indexname AS name,
    jsonb_build_object(
        'method', am.amname,
        'unique', ix.indisunique,
        'primary', ix.indisprimary,
        'valid', ix.indisvalid,
        'ready', ix.indisready,
        'columns', (
            SELECT jsonb_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum))
            FROM pg_attribute a
            WHERE a.attrelid = c.oid 
              AND a.attnum = ANY(ix.indkey)
        ),
        'size', pg_size_pretty(pg_relation_size(c.oid)),
        'size_bytes', pg_relation_size(c.oid),
        'usage_stats', jsonb_build_object(
            'scans', COALESCE(ist.idx_scan, 0),
            'tuples_read', COALESCE(ist.idx_tup_read, 0),
            'tuples_fetched', COALESCE(ist.idx_tup_fetch, 0),
            'is_unused', COALESCE(ist.idx_scan, 0) = 0
        ),
        'definition', i.indexdef,
        'condition', pg_get_expr(ix.indpred, ix.indrelid)
    )::text AS details,
    11 AS sort_order
FROM pg_indexes i
JOIN pg_class c ON i.indexname = c.relname
JOIN pg_namespace n ON c.relnamespace = n.oid AND n.nspname = 'public'
JOIN pg_index ix ON c.oid = ix.indexrelid
JOIN pg_am am ON c.relam = am.oid
LEFT JOIN index_stats ist ON ist.indexrelname = i.indexname AND ist.schemaname = 'public'
WHERE i.schemaname = 'public' 
  AND i.tablename IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 12: ROW LEVEL SECURITY POLICIES                                          ║
-- ║  🔒 RLS policies for access control                                               ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '12_RLS_POLICY' AS section,
    pol.tablename AS table_name,
    pol.policyname AS name,
    jsonb_build_object(
        'command', pol.cmd,
        'permissive', pol.permissive = 'PERMISSIVE',
        'roles', pol.roles,
        'using_expression', pol.qual,
        'with_check_expression', pol.with_check,
        'applies_to', CASE pol.cmd
            WHEN 'ALL' THEN ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE']
            WHEN '*' THEN ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE']
            ELSE ARRAY[pol.cmd]
        END
    )::text AS details,
    12 AS sort_order
FROM pg_policies pol
WHERE pol.schemaname = 'public' 
  AND pol.tablename IN (SELECT table_name FROM target_tables)

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 13: TRIGGERS                                                             ║
-- ║  ⚡ Trigger definitions and automation                                             ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '13_TRIGGER' AS section,
    it.event_object_table AS table_name,
    it.trigger_name AS name,
    jsonb_build_object(
        'enabled', pt.tgenabled != 'D',
        'timing', it.action_timing,
        'events', (
            SELECT jsonb_agg(DISTINCT it2.event_manipulation)
            FROM information_schema.triggers it2
            WHERE it2.trigger_name = it.trigger_name 
              AND it2.event_object_table = it.event_object_table
        ),
        'level', it.action_orientation,
        'function', regexp_replace(it.action_statement, 'EXECUTE (FUNCTION|PROCEDURE) ', ''),
        'condition', it.action_condition,
        'trigger_type', CASE 
            WHEN it.action_timing = 'BEFORE' THEN 'BEFORE'
            WHEN it.action_timing = 'AFTER' THEN 'AFTER'
            WHEN it.action_timing = 'INSTEAD OF' THEN 'INSTEAD_OF'
            ELSE it.action_timing
        END
    )::text AS details,
    13 AS sort_order
FROM information_schema.triggers it
JOIN pg_trigger pt ON it.trigger_name = pt.tgname
JOIN pg_class pc ON pt.tgrelid = pc.oid
WHERE it.event_object_table IN (SELECT table_name FROM target_tables) 
  AND pc.relname = it.event_object_table
  AND NOT pt.tgisinternal
GROUP BY it.event_object_table, it.trigger_name, it.action_timing, 
         it.action_statement, it.action_orientation, it.action_condition, pt.tgenabled

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 14: FUNCTIONS                                                            ║
-- ║  🔧 Stored functions and procedures                                               ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '14_FUNCTION' AS section,
    p.proname AS table_name,
    'signature' AS name,
    jsonb_build_object(
        'oid', p.oid,
        'return_type', pg_get_function_result(p.oid),
        'arguments', pg_get_function_arguments(p.oid),
        'language', l.lanname,
        'security', CASE WHEN p.prosecdef THEN 'DEFINER' ELSE 'INVOKER' END,
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
        'cost', p.procost,
        'estimated_rows', CASE WHEN p.proretset THEN p.prorows ELSE NULL END,
        'is_aggregate', p.prokind = 'a',
        'is_window', p.prokind = 'w',
        'is_procedure', p.prokind = 'p',
        'strict', p.proisstrict,
        'owner', pg_get_userbyid(p.proowner),
        'description', COALESCE(obj_description(p.oid, 'pg_proc'), NULL)
    )::text AS details,
    14 AS sort_order
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
JOIN pg_language l ON p.prolang = l.oid
WHERE n.nspname = 'public'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 15: SEQUENCES                                                            ║
-- ║  🔢 Auto-increment sequences                                                      ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '15_SEQUENCE' AS section,
    c.relname AS table_name,
    'configuration' AS name,
    jsonb_build_object(
        'owner', pg_get_userbyid(c.relowner),
        'data_type', format_type(s.seqtypid, NULL),
        'start_value', s.seqstart,
        'min_value', s.seqmin,
        'max_value', s.seqmax,
        'increment', s.seqincrement,
        'cycle', s.seqcycle,
        'cache_size', s.seqcache,
        'last_value', (
            SELECT last_value 
            FROM pg_sequences 
            WHERE schemaname = 'public' AND sequencename = c.relname
        ),
        'owned_by', (
            SELECT d.refobjid::regclass::text || '.' || a.attname
            FROM pg_depend d
            JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
            WHERE d.objid = c.oid AND d.deptype = 'a'
            LIMIT 1
        )
    )::text AS details,
    15 AS sort_order
FROM pg_class c
JOIN pg_sequence s ON s.seqrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 16: TABLE PRIVILEGES                                                     ║
-- ║  👥 Access control and grants                                                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '16_TABLE_PRIVILEGE' AS section,
    table_name,
    grantee AS name,
    jsonb_build_object(
        'grantee', grantee,
        'grantor', grantor,
        'privileges', jsonb_agg(privilege_type ORDER BY privilege_type),
        'with_grant_option', bool_or(is_grantable = 'YES')
    )::text AS details,
    16 AS sort_order
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name IN (SELECT table_name FROM target_tables)
GROUP BY table_name, grantee, grantor

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 17: FUNCTION PRIVILEGES                                                  ║
-- ║  🔐 Function execution grants                                                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '17_FUNCTION_PRIVILEGE' AS section,
    routine_name AS table_name,
    grantee AS name,
    jsonb_build_object(
        'function', routine_name,
        'grantee', grantee,
        'grantor', grantor,
        'privilege', privilege_type,
        'with_grant_option', is_grantable = 'YES'
    )::text AS details,
    17 AS sort_order
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 18: DEPENDENCIES                                                         ║
-- ║  🌳 Object dependency graph                                                       ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '18_DEPENDENCY' AS section,
    dependent.relname AS table_name,
    'depends_on' AS name,
    jsonb_build_object(
        'depends_on', jsonb_build_object(
            'schema', ref_nsp.nspname,
            'name', ref.relname,
            'type', CASE ref.relkind
                WHEN 'r' THEN 'TABLE'
                WHEN 'v' THEN 'VIEW'
                WHEN 'i' THEN 'INDEX'
                WHEN 'S' THEN 'SEQUENCE'
                WHEN 'm' THEN 'MATERIALIZED_VIEW'
                WHEN 'f' THEN 'FOREIGN_TABLE'
                WHEN 'p' THEN 'PARTITIONED_TABLE'
                ELSE ref.relkind::text
            END
        ),
        'dependency_type', CASE d.deptype
            WHEN 'n' THEN 'NORMAL'
            WHEN 'a' THEN 'AUTO'
            WHEN 'i' THEN 'INTERNAL'
            WHEN 'e' THEN 'EXTENSION'
            WHEN 'p' THEN 'PIN'
            ELSE d.deptype::text
        END
    )::text AS details,
    18 AS sort_order
FROM pg_depend d
JOIN pg_class dependent ON dependent.oid = d.objid
JOIN pg_namespace dep_nsp ON dep_nsp.oid = dependent.relnamespace
JOIN pg_class ref ON ref.oid = d.refobjid
JOIN pg_namespace ref_nsp ON ref_nsp.oid = ref.relnamespace
WHERE dependent.relname IN (SELECT table_name FROM target_tables)
  AND dep_nsp.nspname = 'public'
  AND ref.relkind IN ('r', 'v', 'i', 'S', 'm', 'f', 'p')
  AND d.deptype IN ('n', 'a')
  AND dependent.relname != ref.relname

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 19: STORAGE ANALYSIS                                                     ║
-- ║  💾 Detailed storage metrics per table                                            ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '19_STORAGE_ANALYSIS' AS section,
    t.table_name,
    'io_stats' AS name,
    jsonb_build_object(
        'heap_blocks', jsonb_build_object(
            'read', COALESCE(tio.heap_blks_read, 0),
            'hit', COALESCE(tio.heap_blks_hit, 0),
            'hit_ratio', CASE 
                WHEN COALESCE(tio.heap_blks_read, 0) + COALESCE(tio.heap_blks_hit, 0) > 0
                THEN ROUND(
                    (100.0 * COALESCE(tio.heap_blks_hit, 0) / 
                    (COALESCE(tio.heap_blks_read, 0) + COALESCE(tio.heap_blks_hit, 0)))::numeric, 
                    2
                )
                ELSE 100.0
            END
        ),
        'index_blocks', jsonb_build_object(
            'read', COALESCE(tio.idx_blks_read, 0),
            'hit', COALESCE(tio.idx_blks_hit, 0)
        ),
        'toast_blocks', jsonb_build_object(
            'read', COALESCE(tio.toast_blks_read, 0),
            'hit', COALESCE(tio.toast_blks_hit, 0)
        )
    )::text AS details,
    19 AS sort_order
FROM target_tables t
LEFT JOIN table_io tio ON tio.tablename = t.table_name

UNION ALL

-- ╔═══════════════════════════════════════════════════════════════════════════════════╗
-- ║  SECTION 20: SECURITY AUDIT                                                       ║
-- ║  🛡️ Security configuration summary per table                                      ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════╝
SELECT
    '20_SECURITY_AUDIT' AS section,
    c.relname AS table_name,
    'security_status' AS name,
    jsonb_build_object(
        'rls', jsonb_build_object(
            'enabled', c.relrowsecurity,
            'forced', c.relforcerowsecurity,
            'policy_count', (
                SELECT COUNT(*) FROM pg_policies p 
                WHERE p.tablename = c.relname AND p.schemaname = 'public'
            )
        ),
        'grants', jsonb_build_object(
            'role_count', (
                SELECT COUNT(DISTINCT grantee) 
                FROM information_schema.table_privileges tp
                WHERE tp.table_name = c.relname AND tp.table_schema = 'public'
            ),
            'has_public_access', EXISTS (
                SELECT 1 FROM information_schema.table_privileges tp
                WHERE tp.table_name = c.relname 
                  AND tp.table_schema = 'public'
                  AND tp.grantee = 'PUBLIC'
            )
        ),
        'recommendations', CASE 
            WHEN NOT c.relrowsecurity THEN '⚠️ Consider enabling RLS'
            WHEN c.relrowsecurity AND (
                SELECT COUNT(*) FROM pg_policies p 
                WHERE p.tablename = c.relname AND p.schemaname = 'public'
            ) = 0 THEN '⚠️ RLS enabled but no policies defined'
            ELSE '✅ Security configured'
        END
    )::text AS details,
    20 AS sort_order
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public' 
  AND c.relkind = 'r' 
  AND c.relname IN (SELECT table_name FROM target_tables)

)

-- ════════════════════════════════════════════════════════════════════════════════════
-- 📊 FINAL OUTPUT
-- ════════════════════════════════════════════════════════════════════════════════════
SELECT 
    section,
    table_name,
    name,
    details
FROM xray
ORDER BY 
    sort_order ASC,
    section ASC, 
    table_name ASC, 
    name ASC;

/* ═══════════════════════════════════════════════════════════════════════════════════
   📝 SECTION REFERENCE GUIDE
   ═══════════════════════════════════════════════════════════════════════════════════
   
   Section ID                 | Description
   ---------------------------|--------------------------------------------------
   00_EXTENSION               | PostgreSQL extensions installed
   01_ENUM                    | Custom enumeration types
   02_TABLE_META              | Table metadata and storage statistics
   03_VIEW                    | View definitions and dependencies
   04_REALTIME                | Supabase Realtime publication status
   05_COLUMN                  | Column definitions and statistics
   06_CONSTRAINT_KEY          | Primary key and unique constraints
   07_CONSTRAINT_CHECK        | Check constraints
   08_FK_OUTGOING             | Foreign keys FROM this table
   09_FK_INCOMING             | Foreign keys TO this table
   10_RELATIONSHIP_SUMMARY    | Table connectivity overview
   11_INDEX                   | Index definitions and usage
   12_RLS_POLICY              | Row Level Security policies
   13_TRIGGER                 | Trigger definitions
   14_FUNCTION                | Stored functions and procedures
   15_SEQUENCE                | Auto-increment sequences
   16_TABLE_PRIVILEGE         | Table access grants
   17_FUNCTION_PRIVILEGE      | Function execution grants
   18_DEPENDENCY              | Object dependency graph
   19_STORAGE_ANALYSIS        | I/O and storage metrics
   20_SECURITY_AUDIT          | Security configuration summary
   
   ═══════════════════════════════════════════════════════════════════════════════════
*/