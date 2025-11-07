-- ===============================================
-- system.text_log 快速清理脚本
-- ===============================================
-- 说明：text_log 是文本日志表，记录了所有级别的日志
--      384GB 说明日志累积了很长时间，可以安全清理
-- ===============================================

-- 步骤1：查看当前状态（清理前）
SELECT '=== 清理前的状态 ===' AS step;
SELECT 
    table,
    formatReadableQuantity(total_rows) AS total_records,
    formatReadableSize(total_bytes) AS current_size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system' AND name = 'text_log';

-- 步骤2：查看日志的时间范围
SELECT '=== 日志时间范围 ===' AS step;
SELECT 
    min(event_date) AS earliest_date,
    max(event_date) AS latest_date,
    dateDiff('day', min(event_date), max(event_date)) AS total_days
FROM system.text_log;

-- 步骤3：查看日志级别分布
SELECT '=== 日志级别分布 ===' AS step;
SELECT 
    level,
    formatReadableQuantity(count()) AS count,
    round(count() * 100.0 / (SELECT count() FROM system.text_log), 2) AS percentage
FROM system.text_log
GROUP BY level
ORDER BY count DESC;

-- ===============================================
-- 选择一种清理方法（取消注释后执行）
-- ===============================================

-- 【推荐】方法1：完全清空（最快，释放所有空间）⭐
-- TRUNCATE TABLE system.text_log;

-- 方法2：保留最近7天的日志
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 7;

-- 方法3：保留最近30天的日志
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30;

-- 方法4：只保留 Error 和 Warning 级别的最近30天日志
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30 OR level NOT IN ('Error', 'Warning');

-- 方法5：只删除 Trace 和 Debug 级别的日志
-- ALTER TABLE system.text_log DELETE WHERE level IN ('Trace', 'Debug');

-- ===============================================
-- 步骤4：验证清理效果（清理后执行）
-- ===============================================
/*
SELECT '=== 清理后的状态 ===' AS step;
SELECT 
    table,
    formatReadableQuantity(total_rows) AS remaining_records,
    formatReadableSize(total_bytes) AS new_size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system' AND name = 'text_log';
*/

-- ===============================================
-- 步骤5：（可选）优化表以立即释放空间
-- ===============================================
-- OPTIMIZE TABLE system.text_log FINAL;

-- ===============================================
-- 额外检查：其他可能占用大量空间的系统表
-- ===============================================
SELECT '=== 其他大型系统表 ===' AS step;
SELECT 
    name AS table_name,
    formatReadableQuantity(total_rows) AS records,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.tables
WHERE database = 'system'
  AND total_bytes > 100 * 1024 * 1024  -- 大于100MB
ORDER BY total_bytes DESC
LIMIT 10;
