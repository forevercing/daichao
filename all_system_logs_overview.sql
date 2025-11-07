-- ===============================================
-- ClickHouse 所有系统日志表概览
-- ===============================================

-- 查看所有系统日志表的大小和用途
SELECT 
    name AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records,
    CASE 
        -- 主要的日志表
        WHEN name = 'text_log' THEN '文本日志（所有级别）'
        WHEN name = 'query_log' THEN '查询日志'
        WHEN name = 'trace_log' THEN '查询跟踪日志（CPU/内存采样）'
        WHEN name = 'processors_profile_log' THEN '处理器性能日志'
        WHEN name = 'part_log' THEN '分区操作日志'
        
        -- 其他日志表
        WHEN name = 'query_thread_log' THEN '查询线程日志'
        WHEN name = 'metric_log' THEN '指标日志'
        WHEN name = 'asynchronous_metric_log' THEN '异步指标日志'
        WHEN name = 'crash_log' THEN '崩溃日志'
        WHEN name = 'session_log' THEN '会话日志'
        WHEN name = 'query_views_log' THEN '物化视图查询日志'
        WHEN name = 'asynchronous_insert_log' THEN '异步插入日志'
        WHEN name = 'opentelemetry_span_log' THEN 'OpenTelemetry 跟踪日志'
        WHEN name = 'zookeeper_log' THEN 'ZooKeeper 操作日志'
        WHEN name = 'blob_storage_log' THEN 'Blob 存储日志'
        WHEN name = 'filesystem_cache_log' THEN '文件系统缓存日志'
        WHEN name = 'backup_log' THEN '备份日志'
        
        ELSE '其他系统表'
    END AS description,
    CASE 
        -- 清理优先级
        WHEN name = 'processors_profile_log' THEN '高'
        WHEN name = 'trace_log' THEN '中'
        WHEN name = 'text_log' THEN '中'
        WHEN name = 'query_log' THEN '低'
        WHEN name = 'query_thread_log' THEN '中'
        WHEN name = 'metric_log' THEN '中'
        WHEN name = 'asynchronous_metric_log' THEN '中'
        WHEN name = 'part_log' THEN '低'
        WHEN name = 'crash_log' THEN '低（保留）'
        ELSE '低'
    END AS cleanup_priority,
    CASE 
        -- 建议保留时间
        WHEN name = 'processors_profile_log' THEN '3天'
        WHEN name = 'trace_log' THEN '7天'
        WHEN name = 'text_log' THEN '7天'
        WHEN name = 'query_log' THEN '30天'
        WHEN name = 'query_thread_log' THEN '7天'
        WHEN name = 'metric_log' THEN '7天'
        WHEN name = 'asynchronous_metric_log' THEN '7天'
        WHEN name = 'part_log' THEN '30天'
        WHEN name = 'crash_log' THEN '保留所有'
        WHEN name = 'session_log' THEN '30天'
        ELSE '7天'
    END AS recommended_retention
FROM system.tables
WHERE database = 'system'
  AND name LIKE '%_log'
  AND total_bytes > 0  -- 只显示有数据的表
ORDER BY total_bytes DESC;


-- ===============================================
-- 统计：系统日志表总占用空间
-- ===============================================

SELECT 
    '=== 系统日志表总占用空间 ===' AS info,
    count() AS total_log_tables,
    formatReadableSize(sum(total_bytes)) AS total_size,
    round(sum(total_bytes) / 1024 / 1024 / 1024, 2) AS total_size_gb,
    round(sum(total_bytes) / 1024 / 1024 / 1024 / 1024, 2) AS total_size_tb,
    formatReadableQuantity(sum(total_rows)) AS total_records
FROM system.tables
WHERE database = 'system'
  AND name LIKE '%_log';


-- ===============================================
-- TOP 10 占用空间最大的系统日志表
-- ===============================================

SELECT 
    '=== TOP 10 最大的系统日志表 ===' AS info,
    name AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    round(total_bytes * 100.0 / (SELECT sum(total_bytes) FROM system.tables WHERE database = 'system' AND name LIKE '%_log'), 2) AS percentage_of_total
FROM system.tables
WHERE database = 'system'
  AND name LIKE '%_log'
  AND total_bytes > 0
ORDER BY total_bytes DESC
LIMIT 10;


-- ===============================================
-- 检查哪些日志表超过 1GB
-- ===============================================

SELECT 
    '=== 超过 1GB 的日志表 ===' AS info,
    name AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records
FROM system.tables
WHERE database = 'system'
  AND name LIKE '%_log'
  AND total_bytes > 1024 * 1024 * 1024  -- 大于 1GB
ORDER BY total_bytes DESC;


-- ===============================================
-- 检查哪些日志表超过 10GB（需要优先清理）
-- ===============================================

SELECT 
    '=== 超过 10GB 的日志表（优先清理）===' AS info,
    name AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system'
  AND name LIKE '%_log'
  AND total_bytes > 10 * 1024 * 1024 * 1024  -- 大于 10GB
ORDER BY total_bytes DESC;


-- ===============================================
-- 各类日志表的分类统计
-- ===============================================

SELECT 
    '=== 日志表分类统计 ===' AS info,
    CASE 
        WHEN name IN ('text_log', 'query_log', 'query_thread_log') THEN '查询相关日志'
        WHEN name IN ('trace_log', 'processors_profile_log') THEN '性能分析日志'
        WHEN name IN ('part_log') THEN '数据操作日志'
        WHEN name IN ('metric_log', 'asynchronous_metric_log') THEN '监控指标日志'
        WHEN name IN ('crash_log') THEN '错误日志'
        ELSE '其他日志'
    END AS category,
    count() AS table_count,
    formatReadableSize(sum(total_bytes)) AS total_size,
    round(sum(total_bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system'
  AND name LIKE '%_log'
GROUP BY category
ORDER BY sum(total_bytes) DESC;


-- ===============================================
-- 生成清理命令（针对大于 1GB 的表）
-- ===============================================

SELECT 
    '=== 针对大表的清理命令建议 ===' AS info,
    name AS table_name,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    CASE 
        WHEN name = 'processors_profile_log' THEN 'TRUNCATE TABLE system.processors_profile_log SETTINGS max_table_size_to_drop = 0;'
        WHEN name = 'trace_log' THEN 'TRUNCATE TABLE system.trace_log SETTINGS max_table_size_to_drop = 0;'
        WHEN name = 'text_log' THEN 'TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 0;'
        WHEN name = 'part_log' THEN 'ALTER TABLE system.part_log DELETE WHERE event_date < today() - 30;'
        WHEN name = 'query_log' THEN 'ALTER TABLE system.query_log DELETE WHERE event_date < today() - 30;'
        ELSE concat('ALTER TABLE system.', name, ' DELETE WHERE event_date < today() - 7;')
    END AS suggested_cleanup_command
FROM system.tables
WHERE database = 'system'
  AND name LIKE '%_log'
  AND total_bytes > 1024 * 1024 * 1024  -- 大于 1GB
ORDER BY total_bytes DESC;
