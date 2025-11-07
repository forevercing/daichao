-- ===============================================
-- ClickHouse 系统表详细分析
-- trace_log, processors_profile_log, part_log
-- ===============================================

-- ===============================================
-- 1. trace_log - 查询跟踪日志表
-- ===============================================

SELECT '=== trace_log 表信息 ===' AS info;

-- 1.1 查看 trace_log 表大小
SELECT 
    'trace_log' AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records,
    engine
FROM system.tables
WHERE database = 'system' AND name = 'trace_log';

-- 1.2 查看 trace_log 的数据时间范围
SELECT 
    min(event_date) AS earliest_date,
    max(event_date) AS latest_date,
    dateDiff('day', min(event_date), max(event_date)) AS days_span
FROM system.trace_log;

-- 1.3 查看 trace_log 的跟踪类型分布
SELECT 
    trace_type,
    formatReadableQuantity(count()) AS count,
    round(count() * 100.0 / (SELECT count() FROM system.trace_log), 2) AS percentage
FROM system.trace_log
GROUP BY trace_type
ORDER BY count DESC;

-- 1.4 查看 trace_log 的分区情况
SELECT 
    partition,
    formatReadableSize(sum(bytes)) AS size,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(sum(rows)) AS rows
FROM system.parts
WHERE database = 'system' AND table = 'trace_log' AND active = 1
GROUP BY partition
ORDER BY partition DESC
LIMIT 10;

-- 1.5 查看最近的跟踪记录
SELECT 
    event_time,
    trace_type,
    thread_id,
    query_id
FROM system.trace_log
ORDER BY event_time DESC
LIMIT 5;


-- ===============================================
-- 2. processors_profile_log - 查询处理器性能日志表
-- ===============================================

SELECT '=== processors_profile_log 表信息 ===' AS info;

-- 2.1 查看 processors_profile_log 表大小
SELECT 
    'processors_profile_log' AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records,
    engine
FROM system.tables
WHERE database = 'system' AND name = 'processors_profile_log';

-- 2.2 查看 processors_profile_log 的数据时间范围
SELECT 
    min(event_date) AS earliest_date,
    max(event_date) AS latest_date,
    dateDiff('day', min(event_date), max(event_date)) AS days_span
FROM system.processors_profile_log;

-- 2.3 查看处理器名称分布（TOP 10）
SELECT 
    name AS processor_name,
    formatReadableQuantity(count()) AS count
FROM system.processors_profile_log
GROUP BY name
ORDER BY count DESC
LIMIT 10;

-- 2.4 查看分区情况
SELECT 
    partition,
    formatReadableSize(sum(bytes)) AS size,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(sum(rows)) AS rows
FROM system.parts
WHERE database = 'system' AND table = 'processors_profile_log' AND active = 1
GROUP BY partition
ORDER BY partition DESC
LIMIT 10;


-- ===============================================
-- 3. part_log - 数据分区操作日志表
-- ===============================================

SELECT '=== part_log 表信息 ===' AS info;

-- 3.1 查看 part_log 表大小
SELECT 
    'part_log' AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records,
    engine
FROM system.tables
WHERE database = 'system' AND name = 'part_log';

-- 3.2 查看 part_log 的数据时间范围
SELECT 
    min(event_date) AS earliest_date,
    max(event_date) AS latest_date,
    dateDiff('day', min(event_date), max(event_date)) AS days_span
FROM system.part_log;

-- 3.3 查看事件类型分布
SELECT 
    event_type,
    formatReadableQuantity(count()) AS count,
    round(count() * 100.0 / (SELECT count() FROM system.part_log), 2) AS percentage
FROM system.part_log
GROUP BY event_type
ORDER BY count DESC;

-- 3.4 查看哪些表的分区操作最多（TOP 10）
SELECT 
    database,
    table,
    formatReadableQuantity(count()) AS operations
FROM system.part_log
GROUP BY database, table
ORDER BY count DESC
LIMIT 10;

-- 3.5 查看分区情况
SELECT 
    partition,
    formatReadableSize(sum(bytes)) AS size,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(sum(rows)) AS rows
FROM system.parts
WHERE database = 'system' AND table = 'part_log' AND active = 1
GROUP BY partition
ORDER BY partition DESC
LIMIT 10;

-- 3.6 查看最近的分区操作
SELECT 
    event_time,
    event_type,
    database,
    table,
    part_name,
    round(duration_ms / 1000, 2) AS duration_seconds
FROM system.part_log
ORDER BY event_time DESC
LIMIT 10;


-- ===============================================
-- 汇总：所有三个表的概览
-- ===============================================

SELECT '=== 三个表的大小对比 ===' AS info;

SELECT 
    name AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records,
    CASE 
        WHEN name = 'trace_log' THEN '查询跟踪日志'
        WHEN name = 'processors_profile_log' THEN '处理器性能日志'
        WHEN name = 'part_log' THEN '分区操作日志'
    END AS description
FROM system.tables
WHERE database = 'system' 
  AND name IN ('trace_log', 'processors_profile_log', 'part_log')
ORDER BY total_bytes DESC;


-- ===============================================
-- 清理建议：查看所有系统日志表
-- ===============================================

SELECT '=== 所有大型系统日志表 ===' AS info;

SELECT 
    name AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records
FROM system.tables
WHERE database = 'system'
  AND total_bytes > 100 * 1024 * 1024  -- 大于 100MB
  AND name LIKE '%_log'  -- 只看日志表
ORDER BY total_bytes DESC;
