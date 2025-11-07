-- ===============================================
-- system.text_log 逐步清理脚本
-- 用于解决表大小超过 max_table_size_to_drop 限制的问题
-- ===============================================

-- ===============================================
-- 第一步：先尝试最简单的方法
-- ===============================================

-- 执行这条命令（如果成功，下面的步骤就不需要了）
-- TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 0;

-- 如果上面的命令成功，跳到最后的"验证清理结果"部分
-- 如果报错，继续执行下面的步骤


-- ===============================================
-- 第二步：查看数据分布（了解情况）
-- ===============================================

-- 2.1 查看当前表大小
SELECT 
    '=== 当前表大小 ===' AS info,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records
FROM system.tables
WHERE database = 'system' AND name = 'text_log';

-- 2.2 查看日志级别分布
SELECT 
    '=== 日志级别分布 ===' AS info,
    level,
    formatReadableQuantity(count()) AS records,
    round(count() * 100.0 / (SELECT count() FROM system.text_log), 2) AS percentage
FROM system.text_log
GROUP BY level
ORDER BY count DESC;

-- 2.3 查看日期分布（最近10天）
SELECT 
    '=== 最近10天的数据量 ===' AS info,
    event_date,
    formatReadableQuantity(count()) AS records
FROM system.text_log
WHERE event_date >= today() - 10
GROUP BY event_date
ORDER BY event_date DESC;

-- 2.4 查看分区情况
SELECT 
    '=== 分区信息 ===' AS info,
    partition,
    formatReadableSize(sum(bytes)) AS size,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.parts
WHERE database = 'system' 
  AND table = 'text_log' 
  AND active = 1
GROUP BY partition
ORDER BY partition DESC
LIMIT 20;


-- ===============================================
-- 第三步：删除 Trace 和 Debug 级别的日志
-- （通常占比 70-90%）
-- ===============================================

-- 执行删除
ALTER TABLE system.text_log DELETE WHERE level IN ('Trace', 'Debug');

-- 等待 3-5 分钟后，检查效果
-- SELECT 
--     formatReadableSize(total_bytes) AS size,
--     round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb
-- FROM system.tables
-- WHERE database = 'system' AND name = 'text_log';


-- ===============================================
-- 第四步：删除 Information 级别的日志
-- ===============================================

-- 如果第三步后空间还是很大，继续删除 Information 级别
-- ALTER TABLE system.text_log DELETE WHERE level = 'Information';

-- 等待 3-5 分钟后，检查效果


-- ===============================================
-- 第五步：按日期分批删除（如果还需要进一步清理）
-- ===============================================

-- 5.1 删除 180 天前的数据
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 180;

-- 等待 5 分钟，检查进度

-- 5.2 删除 90 天前的数据
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 90;

-- 等待 5 分钟，检查进度

-- 5.3 删除 60 天前的数据
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 60;

-- 等待 5 分钟，检查进度

-- 5.4 删除 30 天前的数据
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 30;

-- 等待 5 分钟，检查进度

-- 5.5 删除 7 天前的数据
-- ALTER TABLE system.text_log DELETE WHERE event_date < today() - 7;


-- ===============================================
-- 第六步：如果需要完全清空，删除所有剩余数据
-- ===============================================

-- ALTER TABLE system.text_log DELETE WHERE 1=1;


-- ===============================================
-- 第七步：优化表，立即释放空间
-- ===============================================

-- OPTIMIZE TABLE system.text_log FINAL;


-- ===============================================
-- 验证清理结果
-- ===============================================

-- 查看最终大小
SELECT 
    '=== 清理后的大小 ===' AS info,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS remaining_records
FROM system.tables
WHERE database = 'system' AND name = 'text_log';

-- 查看剩余数据的分布
SELECT 
    '=== 剩余数据分布 ===' AS info,
    level,
    formatReadableQuantity(count()) AS records
FROM system.text_log
GROUP BY level
ORDER BY count DESC;


-- ===============================================
-- 监控后台任务（可选）
-- ===============================================

-- 查看是否有正在执行的删除任务
SELECT 
    '=== 正在执行的任务 ===' AS info,
    query,
    elapsed AS seconds,
    formatReadableSize(read_bytes) AS processed
FROM system.processes
WHERE query LIKE '%text_log%';


-- ===============================================
-- 使用说明
-- ===============================================

-- 1. 先执行"第一步"，如果成功就完成了
-- 2. 如果第一步失败，按顺序执行第二步到第七步
-- 3. 每次执行 DELETE 后，等待 3-5 分钟再继续
-- 4. 随时执行"验证清理结果"查看进度
-- 5. 如果删除速度很慢，可以使用更小的时间范围（如删除 365 天前的数据）

-- 注意：
-- - 所有带 -- 的行是注释或待执行的命令
-- - 需要删除某行开头的 -- 才能执行该命令
-- - DELETE 操作是异步的，需要等待完成
-- - 可以多次运行脚本查看进度
