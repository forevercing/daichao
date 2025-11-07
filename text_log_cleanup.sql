-- ===============================================
-- ClickHouse system.text_log 表分析和清理
-- ===============================================

-- 1. 查看 text_log 表的基本信息
SELECT 
    table,
    engine,
    total_rows,
    formatReadableSize(total_bytes) AS size_formatted,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system' 
  AND name = 'text_log';

-- 2. 查看 text_log 表的详细分区信息
SELECT 
    partition,
    count() AS parts_count,
    formatReadableQuantity(sum(rows)) AS rows_formatted,
    sum(rows) AS total_rows,
    formatReadableSize(sum(bytes)) AS size_formatted,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    min(min_date) AS earliest_date,
    max(max_date) AS latest_date
FROM system.parts
WHERE database = 'system' 
  AND table = 'text_log' 
  AND active = 1
GROUP BY partition
ORDER BY partition DESC;

-- 3. 查看日志的时间范围
SELECT 
    min(event_date) AS earliest_log_date,
    max(event_date) AS latest_log_date,
    dateDiff('day', min(event_date), max(event_date)) AS days_span,
    count() AS total_records,
    formatReadableQuantity(count()) AS records_formatted
FROM system.text_log;

-- 4. 查看各日志级别的分布
SELECT 
    level,
    count() AS count,
    formatReadableQuantity(count()) AS count_formatted,
    round(count() * 100.0 / (SELECT count() FROM system.text_log), 2) AS percentage
FROM system.text_log
GROUP BY level
ORDER BY count DESC;

-- 5. 查看最近的日志记录（最新10条）
SELECT 
    event_time,
    level,
    substring(message, 1, 100) AS message_preview
FROM system.text_log
ORDER BY event_time DESC
LIMIT 10;

-- ===============================================
-- 清理方法
-- ===============================================

-- 方法1：清空整个表（最快，推荐）⭐
-- TRUNCATE TABLE system.text_log;

-- 方法2：删除指定日期之前的数据（保留最近N天）
-- 例如：删除30天之前的数据
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30;

-- 方法3：删除指定日期之前的数据（保留最近7天）
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 7;

-- 方法4：只保留ERROR和WARNING级别的日志，删除其他级别
-- ALTER TABLE system.text_log DELETE WHERE level NOT IN ('Error', 'Warning');

-- 方法5：删除指定分区（如果知道分区名称）
-- ALTER TABLE system.text_log DROP PARTITION '202401';

-- ===============================================
-- 验证清理效果
-- ===============================================

-- 清理后，再次检查表的大小
SELECT 
    table,
    formatReadableQuantity(total_rows) AS rows_formatted,
    total_rows,
    formatReadableSize(total_bytes) AS size_formatted,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system' 
  AND name = 'text_log';

-- ===============================================
-- 检查其他可能占用大量空间的系统表
-- ===============================================

SELECT 
    name AS table_name,
    engine,
    formatReadableQuantity(total_rows) AS rows_formatted,
    total_rows,
    formatReadableSize(total_bytes) AS size_formatted,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system'
  AND total_bytes > 1024 * 1024 * 1024  -- 大于1GB的表
ORDER BY total_bytes DESC;
