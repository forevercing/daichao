<?php
/**
 * ClickHouse 表概览查询 - PHP示例
 * 
 * 这个脚本演示如何使用PHP连接ClickHouse并查询表的基本信息
 */

// ClickHouse连接配置
$config = [
    'host' => 'localhost',  // 修改为你的ClickHouse主机地址
    'port' => 8123,         // HTTP接口端口，默认8123
    'username' => 'default', // 修改为你的用户名
    'password' => '',        // 修改为你的密码
    'database' => 'default'  // 默认数据库
];

/**
 * 执行ClickHouse查询
 */
function executeClickHouseQuery($config, $query) {
    $url = sprintf(
        'http://%s:%d/?user=%s&password=%s&database=%s',
        $config['host'],
        $config['port'],
        $config['username'],
        $config['password'],
        $config['database']
    );
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $query);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: text/plain',
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    
    curl_close($ch);
    
    if ($httpCode !== 200) {
        throw new Exception("ClickHouse查询失败: HTTP $httpCode - $response");
    }
    
    return $response;
}

// 查询1：获取所有表的基本信息
$query = "
SELECT 
    database,
    table,
    sum(rows) AS total_rows,
    round(sum(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM system.parts
WHERE active = 1 
  AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
GROUP BY database, table
ORDER BY database, table
FORMAT JSONEachRow
";

try {
    echo "<h1>ClickHouse 表概览</h1>\n";
    echo "<h2>使用说明</h2>\n";
    echo "<p>请先修改本文件中的ClickHouse连接配置（host、port、username、password）</p>\n";
    echo "<h2>查询结果</h2>\n";
    
    // 执行查询
    $result = executeClickHouseQuery($config, $query);
    
    // 解析结果
    $lines = explode("\n", trim($result));
    $tables = [];
    foreach ($lines as $line) {
        if (!empty($line)) {
            $tables[] = json_decode($line, true);
        }
    }
    
    // 显示结果
    if (empty($tables)) {
        echo "<p>没有找到表</p>\n";
    } else {
        echo "<table border='1' cellpadding='10' cellspacing='0' style='border-collapse: collapse;'>\n";
        echo "<tr style='background-color: #f0f0f0;'>";
        echo "<th>数据库名</th>";
        echo "<th>表名</th>";
        echo "<th>行数</th>";
        echo "<th>占用空间(GB)</th>";
        echo "</tr>\n";
        
        foreach ($tables as $table) {
            echo "<tr>";
            echo "<td>" . htmlspecialchars($table['database']) . "</td>";
            echo "<td>" . htmlspecialchars($table['table']) . "</td>";
            echo "<td style='text-align: right;'>" . number_format($table['total_rows']) . "</td>";
            echo "<td style='text-align: right;'>" . $table['size_gb'] . "</td>";
            echo "</tr>\n";
        }
        
        echo "</table>\n";
        
        // 统计信息
        $totalRows = array_sum(array_column($tables, 'total_rows'));
        $totalGB = array_sum(array_column($tables, 'size_gb'));
        
        echo "<h2>汇总统计</h2>\n";
        echo "<p>表总数: " . count($tables) . "</p>\n";
        echo "<p>总行数: " . number_format($totalRows) . "</p>\n";
        echo "<p>总占用空间: " . round($totalGB, 2) . " GB</p>\n";
    }
    
} catch (Exception $e) {
    echo "<p style='color: red;'>错误: " . htmlspecialchars($e->getMessage()) . "</p>\n";
    echo "<p>提示：请检查以下内容：</p>\n";
    echo "<ul>\n";
    echo "<li>ClickHouse服务是否正常运行</li>\n";
    echo "<li>连接配置是否正确（主机地址、端口、用户名、密码）</li>\n";
    echo "<li>是否已安装并启用PHP的curl扩展</li>\n";
    echo "</ul>\n";
}

echo "\n<hr>\n";
echo "<h2>相关文件说明</h2>\n";
echo "<ul>\n";
echo "<li><strong>simple_query.sql</strong> - 最简单的查询语句，直接在ClickHouse客户端执行</li>\n";
echo "<li><strong>quick_query.sql</strong> - 完整的一键查询脚本，包含多个查询步骤</li>\n";
echo "<li><strong>clickhouse_tables_overview.sql</strong> - 多种查询方案</li>\n";
echo "<li><strong>README_CLICKHOUSE.md</strong> - 详细的使用指南</li>\n";
echo "</ul>\n";