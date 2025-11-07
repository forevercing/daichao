-- ===============================================
-- 解决 TRUNCATE TABLE 报错：表大小超过限制
-- 错误：TABLE_SIZE_EXCEEDS_MAX_DROP_SIZE_LIMIT
-- ===============================================

-- 问题：表大小 413.21 GB 超过了 max_table_size_to_drop 限制（50 GB）
-- 由于没有服务器权限，无法创建 force_drop_table 文件

-- ===============================================
-- 方案1：在查询中设置参数（推荐）⭐
-- ===============================================

-- 方法1A：使用 SETTINGS 临时绕过限制
TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 0;

-- 如果方法1A不行，尝试这个：
-- TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 500000000000;  -- 500GB


-- ===============================================
-- 方案2：使用 DELETE 分批删除（如果方案1不行）
-- ===============================================

-- 方法2A：按日期分批删除（推荐用于大表）
-- 先查看有哪些日期的数据
SELECT 
    event_date,
    formatReadableQuantity(count()) AS records,
    formatReadableSize(sum(length(message))) AS approx_size
FROM system.text_log
GROUP BY event_date
ORDER BY event_date;

-- 然后按日期逐个删除（示例：删除2024-01-01的数据）
-- ALTER TABLE system.text_log DELETE WHERE event_date = '2024-01-01';

-- 方法2B：按月份分批删除
-- 查看按月的数据分布
SELECT 
    toYYYYMM(event_date) AS year_month,
    formatReadableQuantity(count()) AS records
FROM system.text_log
GROUP BY year_month
ORDER BY year_month;

-- 删除指定月份（示例：删除2024年1月）
-- ALTER TABLE system.text_log DELETE WHERE toYYYYMM(event_date) = 202401;

-- 方法2C：分多次删除旧数据
-- 第1次：删除90天前的数据
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 90;

-- 等待几分钟后，第2次：删除60天前的数据
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 60;

-- 等待几分钟后，第3次：删除30天前的数据
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30;

-- 等待几分钟后，第4次：删除7天前的数据
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 7;


-- ===============================================
-- 方案3：按分区删除（如果表是按分区的）
-- ===============================================

-- 查看所有分区
SELECT 
    partition,
    count() AS parts_count,
    formatReadableQuantity(sum(rows)) AS total_rows,
    formatReadableSize(sum(bytes)) AS size
FROM system.parts
WHERE database = 'system' 
  AND table = 'text_log' 
  AND active = 1
GROUP BY partition
ORDER BY partition;

-- 逐个删除分区（比 DELETE 更快）
-- ALTER TABLE system.text_log DROP PARTITION '202401';
-- ALTER TABLE system.text_log DROP PARTITION '202402';
-- 继续删除其他分区...


-- ===============================================
-- 方案4：删除特定级别的日志（减少数据量）
-- ===============================================

-- 先删除 Trace 和 Debug 级别的日志（通常占比最大）
-- ALTER TABLE system.text_log DELETE WHERE level IN ('Trace', 'Debug');

-- 等待几分钟后，再删除 Information 级别
-- ALTER TABLE system.text_log DELETE WHERE level = 'Information';

-- 只保留 Error 和 Warning
-- ALTER TABLE system.text_log DELETE WHERE level NOT IN ('Error', 'Warning');


-- ===============================================
-- 验证删除进度
-- ===============================================

-- 查看当前大小
SELECT 
    formatReadableSize(total_bytes) AS current_size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records
FROM system.tables
WHERE database = 'system' AND name = 'text_log';

-- 查看后台删除任务的进度
SELECT 
    query,
    elapsed,
    formatReadableSize(read_bytes) AS processed,
    formatReadableQuantity(read_rows) AS rows_processed
FROM system.processes
WHERE query LIKE '%text_log%';


-- ===============================================
-- 优化表以立即释放空间
-- ===============================================

-- 在每次删除后执行（可选）
-- OPTIMIZE TABLE system.text_log FINAL;
