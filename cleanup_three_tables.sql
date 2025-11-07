-- ===============================================
-- trace_log, processors_profile_log, part_log
-- 三表清理脚本
-- ===============================================

-- ===============================================
-- 步骤1：查看当前状态
-- ===============================================

SELECT '=== 清理前的状态 ===' AS step;

SELECT 
    name AS table_name,
    formatReadableSize(total_bytes) AS current_size,
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

-- 查看数据时间范围
SELECT '=== trace_log 时间范围 ===' AS step;
SELECT 
    min(event_date) AS earliest,
    max(event_date) AS latest,
    dateDiff('day', min(event_date), max(event_date)) AS days_span
FROM system.trace_log;

SELECT '=== processors_profile_log 时间范围 ===' AS step;
SELECT 
    min(event_date) AS earliest,
    max(event_date) AS latest,
    dateDiff('day', min(event_date), max(event_date)) AS days_span
FROM system.processors_profile_log;

SELECT '=== part_log 时间范围 ===' AS step;
SELECT 
    min(event_date) AS earliest,
    max(event_date) AS latest,
    dateDiff('day', min(event_date), max(event_date)) AS days_span
FROM system.part_log;


-- ===============================================
-- 步骤2：清理 processors_profile_log（优先级最高）
-- ===============================================

-- 方案A：完全清空（推荐，如果不需要性能分析）
-- TRUNCATE TABLE system.processors_profile_log SETTINGS max_table_size_to_drop = 0;

-- 方案B：保留最近3天
-- ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 3;

-- 方案C：保留最近7天
-- ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 7;

-- 方案D：分批删除（如果表很大）
-- ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 90;
-- 等待5分钟
-- ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 30;
-- 等待5分钟
-- ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 7;


-- ===============================================
-- 步骤3：清理 trace_log（优先级中等）
-- ===============================================

-- 方案A：完全清空（如果不需要性能调优）
-- TRUNCATE TABLE system.trace_log SETTINGS max_table_size_to_drop = 0;

-- 方案B：保留最近7天
-- ALTER TABLE system.trace_log DELETE WHERE event_date < today() - 7;

-- 方案C：保留最近14天
-- ALTER TABLE system.trace_log DELETE WHERE event_date < today() - 14;

-- 方案D：只保留 CPU 和 Memory 类型的跟踪
-- ALTER TABLE system.trace_log DELETE WHERE trace_type NOT IN ('CPU', 'Memory') AND event_date < today() - 7;


-- ===============================================
-- 步骤4：清理 part_log（优先级低，谨慎清理）
-- ===============================================

-- 方案A：保留最近30天（推荐）
-- ALTER TABLE system.part_log DELETE WHERE event_date < today() - 30;

-- 方案B：保留最近60天
-- ALTER TABLE system.part_log DELETE WHERE event_date < today() - 60;

-- 方案C：保留最近7天（如果空间非常紧张）
-- ALTER TABLE system.part_log DELETE WHERE event_date < today() - 7;

-- 方案D：只删除 NewPart 类型的旧记录（保留重要的合并记录）
-- ALTER TABLE system.part_log DELETE WHERE event_type = 'NewPart' AND event_date < today() - 7;


-- ===============================================
-- 步骤5：优化表（可选，加快空间释放）
-- ===============================================

-- OPTIMIZE TABLE system.processors_profile_log FINAL;
-- OPTIMIZE TABLE system.trace_log FINAL;
-- OPTIMIZE TABLE system.part_log FINAL;


-- ===============================================
-- 步骤6：验证清理结果
-- ===============================================

SELECT '=== 清理后的状态 ===' AS step;

SELECT 
    name AS table_name,
    formatReadableSize(total_bytes) AS new_size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS remaining_records
FROM system.tables
WHERE database = 'system' 
  AND name IN ('trace_log', 'processors_profile_log', 'part_log')
ORDER BY total_bytes DESC;

-- 计算节省的空间
SELECT '=== 空间节省统计 ===' AS step;
-- 注意：需要在清理前后分别记录数据才能计算


-- ===============================================
-- 推荐的清理命令（复制使用）
-- ===============================================

/*
-- 推荐方案：根据优先级清理

-- 1. 清理 processors_profile_log（优先级最高）
TRUNCATE TABLE system.processors_profile_log SETTINGS max_table_size_to_drop = 0;
-- 或保留3天：
-- ALTER TABLE system.processors_profile_log DELETE WHERE event_date < today() - 3;

-- 2. 清理 trace_log（优先级中等）
TRUNCATE TABLE system.trace_log SETTINGS max_table_size_to_drop = 0;
-- 或保留7天：
-- ALTER TABLE system.trace_log DELETE WHERE event_date < today() - 7;

-- 3. 清理 part_log（优先级低）
ALTER TABLE system.part_log DELETE WHERE event_date < today() - 30;

-- 4. 优化表
OPTIMIZE TABLE system.processors_profile_log FINAL;
OPTIMIZE TABLE system.trace_log FINAL;
OPTIMIZE TABLE system.part_log FINAL;
*/


-- ===============================================
-- 额外：检查其他可能占用空间的系统表
-- ===============================================

SELECT '=== 其他大型系统日志表 ===' AS step;

SELECT 
    name AS table_name,
    formatReadableSize(total_bytes) AS size,
    round(total_bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    formatReadableQuantity(total_rows) AS records
FROM system.tables
WHERE database = 'system'
  AND total_bytes > 100 * 1024 * 1024  -- 大于 100MB
  AND name LIKE '%_log'
  AND name NOT IN ('trace_log', 'processors_profile_log', 'part_log')
ORDER BY total_bytes DESC;


-- ===============================================
-- 使用说明
-- ===============================================

/*
使用步骤：

1. 先执行"步骤1：查看当前状态"，了解三个表的大小

2. 根据空间需求选择清理方案：
   - 如果不需要性能分析：完全清空 processors_profile_log 和 trace_log
   - 如果偶尔需要性能分析：保留最近3-7天
   - part_log 建议至少保留7-30天

3. 按优先级清理：
   第一优先：processors_profile_log（最容易膨胀）
   第二优先：trace_log
   第三优先：part_log（最后考虑）

4. 每次清理后等待3-5分钟，让删除操作完成

5. 执行"步骤6：验证清理结果"确认效果

6. 如果删除后空间释放较慢，执行 OPTIMIZE TABLE

注意事项：
- TRUNCATE 比 DELETE 快，但有大小限制
- DELETE 是异步的，需要等待
- part_log 相对重要，不要过度清理
- 清理不影响 ClickHouse 正常运行
*/
