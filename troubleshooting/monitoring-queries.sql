-- ========================================
-- Microsoft Fabric Mirroring Demo
-- File: monitoring-queries.sql
-- Author: stuba83 (https://github.com/stuba83)
-- Purpose: Monitoring and troubleshooting queries for Fabric Mirroring
-- ========================================

-- IMPORTANT: Execute these queries in Azure SQL Database (source) to monitor mirroring health
-- These queries help diagnose mirroring issues and monitor performance

PRINT '=== FABRIC MIRRORING MONITORING & TROUBLESHOOTING ===';
PRINT 'Execution Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT 'Database: ' + DB_NAME();
PRINT 'Server: ' + @@SERVERNAME;
PRINT '';

-- ========================================
-- MIRRORING STATUS CHECKS
-- ========================================

PRINT '--- Mirroring Status Checks ---';
PRINT 'These queries help verify that mirroring is configured and running properly.';
PRINT '';

-- Check if Change Feed is enabled (required for mirroring)
PRINT '1. Change Feed Status:';
SELECT 
    database_id,
    DB_NAME(database_id) as database_name,
    is_change_feed_enabled,
    change_feed_enabled_time,
    DATEDIFF(HOUR, change_feed_enabled_time, GETDATE()) as hours_since_enabled
FROM sys.change_feed_databases
WHERE database_id = DB_ID();

-- Check Change Feed Log Scan Sessions (active mirroring sessions)
PRINT '';
PRINT '2. Active Mirroring Sessions:';
SELECT 
    session_id,
    database_id,
    DB_NAME(database_id) as database_name,
    start_time,
    end_time,
    status,
    DATEDIFF(MINUTE, start_time, ISNULL(end_time, GETDATE())) as duration_minutes,
    error_number,
    error_message
FROM sys.dm_change_feed_log_scan_sessions
WHERE database_id = DB_ID()
ORDER BY start_time DESC;

-- Check Change Feed Tables (tables being mirrored)
PRINT '';
PRINT '3. Tables Configured for Mirroring:';
SELECT 
    t.object_id,
    OBJECT_SCHEMA_NAME(t.object_id) as schema_name,
    OBJECT_NAME(t.object_id) as table_name,
    t.is_change_feed_enabled,
    t.change_feed_enabled_time,
    t.has_change_feed_exception,
    t.exception_message,
    DATEDIFF(HOUR, t.change_feed_enabled_time, GETDATE()) as hours_since_enabled
FROM sys.change_feed_tables t
WHERE t.is_change_feed_enabled = 1
ORDER BY schema_name, table_name;

-- ========================================
-- PERFORMANCE MONITORING
-- ========================================

PRINT '';
PRINT '--- Performance Monitoring ---';
PRINT 'Monitor database performance and resource usage during mirroring.';
PRINT '';

-- Database Resource Usage
PRINT '4. Database Resource Usage:';
SELECT 
    database_name = DB_NAME(),
    
    -- CPU Usage
    avg_cpu_percent = AVG(avg_cpu_percent),
    max_cpu_percent = MAX(avg_cpu_percent),
    
    -- IO Usage  
    avg_data_io_percent = AVG(avg_data_io_percent),
    max_data_io_percent = MAX(avg_data_io_percent),
    avg_log_write_percent = AVG(avg_log_write_percent),
    max_log_write_percent = MAX(avg_log_write_percent),
    
    -- Memory Usage
    avg_memory_usage_percent = AVG(avg_memory_usage_percent),
    max_memory_usage_percent = MAX(avg_memory_usage_percent),
    
    -- DTU Usage (for DTU-based databases)
    avg_dtu_percent = AVG(avg_dtu_percent),
    max_dtu_percent = MAX(avg_dtu_percent),

    -- Sample Time Range
    sample_time_start = MIN(end_time),
    sample_time_end = MAX(end_time)
    
FROM sys.dm_db_resource_stats
WHERE end_time >= DATEADD(HOUR, -2, GETDATE())  -- Last 2 hours
HAVING COUNT(*) > 0;

-- Transaction Log Usage
PRINT '';
PRINT '5. Transaction Log Status:';
SELECT 
    database_name = DB_NAME(),
    log_reuse_wait_desc,
    log_space_used_percent = CAST(FILEPROPERTY(name, 'SpaceUsed') AS FLOAT) / CAST(FILEPROPERTY(name, 'Size') AS FLOAT) * 100,
    log_space_available_percent = 100 - (CAST(FILEPROPERTY(name, 'SpaceUsed') AS FLOAT) / CAST(FILEPROPERTY(name, 'Size') AS FLOAT) * 100),
    log_size_mb = CAST(FILEPROPERTY(name, 'Size') AS BIGINT) * 8 / 1024,
    log_used_mb = CAST(FILEPROPERTY(name, 'SpaceUsed') AS BIGINT) * 8 / 1024,
    
    -- Log Health Status
    log_health_status = CASE 
        WHEN CAST(FILEPROPERTY(name, 'SpaceUsed') AS FLOAT) / CAST(FILEPROPERTY(name, 'Size') AS FLOAT) * 100 > 90 THEN 'CRITICAL'
        WHEN CAST(FILEPROPERTY(name, 'SpaceUsed') AS FLOAT) / CAST(FILEPROPERTY(name, 'Size') AS FLOAT) * 100 > 75 THEN 'WARNING'
        WHEN CAST(FILEPROPERTY(name, 'SpaceUsed') AS FLOAT) / CAST(FILEPROPERTY(name, 'Size') AS FLOAT) * 100 > 50 THEN 'CAUTION'
        ELSE 'HEALTHY'
    END
FROM sys.database_files 
WHERE type_desc = 'LOG';

-- Active Transactions (can block mirroring)
PRINT '';
PRINT '6. Long-Running Transactions:';
SELECT 
    t.transaction_id,
    t.name as transaction_name,
    t.transaction_begin_time,
    DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) as duration_seconds,
    t.transaction_type,
    t.transaction_state,
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    r.command,
    r.status as request_status,
    r.blocking_session_id,
    
    -- Transaction Classification
    CASE 
        WHEN DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) > 300 THEN 'LONG_RUNNING'
        WHEN DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) > 60 THEN 'MODERATE'
        ELSE 'SHORT'
    END as transaction_classification
    
FROM sys.dm_tran_active_transactions t
LEFT JOIN sys.dm_tran_session_transactions st ON t.transaction_id = st.transaction_id
LEFT JOIN sys.dm_exec_sessions s ON st.session_id = s.session_id
LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
WHERE t.transaction_begin_time < DATEADD(MINUTE, -1, GETDATE())  -- Transactions older than 1 minute
ORDER BY t.transaction_begin_time;

-- ========================================
-- DATA CHANGE MONITORING
-- ========================================

PRINT '';
PRINT '--- Data Change Monitoring ---';
PRINT 'Monitor data changes that trigger mirroring updates.';
PRINT '';

-- Recent Data Changes by Table
PRINT '7. Recent Data Changes by Table:';
SELECT 
    table_schema = SCHEMA_NAME(o.schema_id),
    table_name = o.name,
    
    -- Recent Modifications
    records_modified_last_hour = (
        SELECT COUNT(*) 
        FROM sys.dm_db_stats_properties(o.object_id, i.index_id) sp
        WHERE i.index_id IN (0, 1) 
        AND sp.modification_counter > 0
    ),
    
    -- Table Information
    total_rows = (
        SELECT SUM(p.rows) 
        FROM sys.partitions p 
        WHERE p.object_id = o.object_id 
        AND p.index_id IN (0, 1)
    ),
    
    -- Last Stats Update
    last_stats_update = (
        SELECT MAX(sp.last_updated)
        FROM sys.stats s
        CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
        WHERE s.object_id = o.object_id
    ),
    
    -- Change Feed Status
    is_mirrored = CASE 
        WHEN EXISTS (
            SELECT 1 FROM sys.change_feed_tables cft 
            WHERE cft.object_id = o.object_id 
            AND cft.is_change_feed_enabled = 1
        ) THEN 'YES'
        ELSE 'NO'
    END,
    
    -- Activity Level
    activity_level = CASE 
        WHEN (
            SELECT SUM(sp.modification_counter) 
            FROM sys.dm_db_stats_properties(o.object_id, i.index_id) sp
            WHERE i.index_id IN (0, 1)
        ) > 1000 THEN 'HIGH'
        WHEN (
            SELECT SUM(sp.modification_counter) 
            FROM sys.dm_db_stats_properties(o.object_id, i.index_id) sp
            WHERE i.index_id IN (0, 1)
        ) > 100 THEN 'MEDIUM'
        WHEN (
            SELECT SUM(sp.modification_counter) 
            FROM sys.dm_db_stats_properties(o.object_id, i.index_id) sp
            WHERE i.index_id IN (0, 1)
        ) > 0 THEN 'LOW'
        ELSE 'NONE'
    END

FROM sys.objects o
JOIN sys.indexes i ON o.object_id = i.object_id
WHERE o.type = 'U'  -- User tables only
  AND SCHEMA_NAME(o.schema_id) = 'SalesLT'  -- Focus on demo schema
  AND i.index_id IN (0, 1)  -- Heap or clustered index
ORDER BY activity_level DESC, table_name;

-- Table Modification Summary
PRINT '';
PRINT '8. Table Modification Summary (Last 24 Hours):';
WITH TableActivity AS (
    SELECT 
        SCHEMA_NAME(o.schema_id) as schema_name,
        o.name as table_name,
        SUM(sp.modification_counter) as total_modifications,
        MAX(sp.last_updated) as last_stats_update,
        SUM(p.rows) as current_row_count
    FROM sys.objects o
    JOIN sys.partitions p ON o.object_id = p.object_id
    JOIN sys.dm_db_stats_properties(o.object_id, p.index_id) sp ON p.partition_id = sp.partition_id
    WHERE o.type = 'U' 
      AND SCHEMA_NAME(o.schema_id) = 'SalesLT'
      AND p.index_id IN (0, 1)
    GROUP BY SCHEMA_NAME(o.schema_id), o.name
)
SELECT 
    schema_name,
    table_name,
    current_row_count,
    total_modifications,
    last_stats_update,
    
    -- Modification Rate
    CASE 
        WHEN current_row_count > 0 THEN 
            ROUND((total_modifications * 100.0) / current_row_count, 2)
        ELSE 0
    END as modification_rate_percent,
    
    -- Activity Classification
    CASE 
        WHEN total_modifications > current_row_count * 0.5 THEN 'VERY_HIGH'
        WHEN total_modifications > current_row_count * 0.2 THEN 'HIGH'
        WHEN total_modifications > current_row_count * 0.05 THEN 'MEDIUM'
        WHEN total_modifications > 0 THEN 'LOW'
        ELSE 'NONE'
    END as activity_classification,
    
    -- Mirroring Impact
    CASE 
        WHEN total_modifications > 10000 THEN 'High mirroring load expected'
        WHEN total_modifications > 1000 THEN 'Medium mirroring load expected'
        WHEN total_modifications > 100 THEN 'Low mirroring load expected'
        ELSE 'Minimal mirroring load'
    END as mirroring_impact

FROM TableActivity
WHERE total_modifications > 0
ORDER BY total_modifications DESC;

-- ========================================
-- ERROR DETECTION AND DIAGNOSTICS
-- ========================================

PRINT '';
PRINT '--- Error Detection and Diagnostics ---';
PRINT 'Identify potential issues affecting mirroring performance.';
PRINT '';

-- Change Feed Errors
PRINT '9. Change Feed Errors:';
SELECT 
    session_id,
    database_id,
    DB_NAME(database_id) as database_name,
    start_time,
    end_time,
    status,
    error_number,
    error_message,
    DATEDIFF(MINUTE, start_time, ISNULL(end_time, GETDATE())) as session_duration_minutes
FROM sys.dm_change_feed_log_scan_sessions
WHERE error_number IS NOT NULL
   OR status = 'Error'
ORDER BY start_time DESC;

-- Tables with Change Feed Exceptions
PRINT '';
PRINT '10. Tables with Mirroring Issues:';
SELECT 
    OBJECT_SCHEMA_NAME(object_id) as schema_name,
    OBJECT_NAME(object_id) as table_name,
    is_change_feed_enabled,
    has_change_feed_exception,
    exception_message,
    change_feed_enabled_time,
    DATEDIFF(HOUR, change_feed_enabled_time, GETDATE()) as hours_since_enabled,
    
    -- Issue Classification
    CASE 
        WHEN has_change_feed_exception = 1 THEN 'ERROR'
        WHEN is_change_feed_enabled = 0 THEN 'NOT_ENABLED'
        ELSE 'OK'
    END as status
    
FROM sys.change_feed_tables
WHERE has_change_feed_exception = 1
   OR is_change_feed_enabled = 0
ORDER BY schema_name, table_name;

-- Blocking Sessions
PRINT '';
PRINT '11. Blocking Sessions (Can Impact Mirroring):';
SELECT 
    blocking_session_id,
    session_id as blocked_session_id,
    wait_type,
    wait_time,
    wait_resource,
    
    -- Blocking Session Details
    bs.login_name as blocking_login,
    bs.host_name as blocking_host,
    bs.program_name as blocking_program,
    
    -- Blocked Session Details  
    s.login_name as blocked_login,
    s.host_name as blocked_host,
    s.program_name as blocked_program,
    
    -- Commands
    r.command,
    r.status,
    
    -- Duration
    DATEDIFF(SECOND, r.start_time, GETDATE()) as blocked_duration_seconds,
    
    -- Impact Assessment
    CASE 
        WHEN wait_time > 30000 THEN 'CRITICAL'  -- > 30 seconds
        WHEN wait_time > 10000 THEN 'HIGH'      -- > 10 seconds
        WHEN wait_time > 5000 THEN 'MEDIUM'     -- > 5 seconds
        ELSE 'LOW'
    END as impact_level

FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
LEFT JOIN sys.dm_exec_sessions bs ON r.blocking_session_id = bs.session_id
WHERE r.blocking_session_id != 0
ORDER BY wait_time DESC;

-- ========================================
-- CONNECTIVITY AND CONFIGURATION CHECKS
-- ========================================

PRINT '';
PRINT '--- Connectivity and Configuration Checks ---';
PRINT 'Verify database configuration for optimal mirroring.';
PRINT '';

-- Database Configuration
PRINT '12. Database Configuration:';
SELECT 
    database_name = DB_NAME(),
    collation_name = DATABASEPROPERTYEX(DB_NAME(), 'Collation'),
    user_access = DATABASEPROPERTYEX(DB_NAME(), 'UserAccess'),
    is_read_only = DATABASEPROPERTYEX(DB_NAME(), 'IsReadOnly'),
    is_auto_close_on = DATABASEPROPERTYEX(DB_NAME(), 'IsAutoClose'),
    is_auto_shrink_on = DATABASEPROPERTYEX(DB_NAME(), 'IsAutoShrink'),
    state_desc = DATABASEPROPERTYEX(DB_NAME(), 'Status'),
    recovery_model_desc = DATABASEPROPERTYEX(DB_NAME(), 'Recovery'),
    
    -- Service Tier Information (Azure SQL Database)
    service_objective = DATABASEPROPERTYEX(DB_NAME(), 'ServiceObjective'),
    edition = DATABASEPROPERTYEX(DB_NAME(), 'Edition'),
    
    -- Mirroring Prerequisites Check
    mirroring_ready = CASE 
        WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsReadOnly') = 0 
         AND DATABASEPROPERTYEX(DB_NAME(), 'UserAccess') = 'MULTI_USER'
         AND DATABASEPROPERTYEX(DB_NAME(), 'Status') = 'ONLINE'
        THEN 'YES'
        ELSE 'NO - Check prerequisites'
    END;

-- Server-Level Configuration
PRINT '';
PRINT '13. Server-Level Configuration:';
SELECT 
    server_name = @@SERVERNAME,
    product_version = @@VERSION,
    
    -- Check for System Assigned Managed Identity (Azure SQL)
    -- This would need to be checked in Azure Portal
    
    -- Connection Information
    current_user = USER_NAME(),
    is_sysadmin = IS_SRVROLEMEMBER('sysadmin'),
    is_db_owner = IS_MEMBER('db_owner'),
    
    -- Required Permissions Check
    has_alter_any_external_mirror = CASE 
        WHEN IS_SRVROLEMEMBER('sysadmin') = 1 OR IS_MEMBER('db_owner') = 1 
        THEN 'YES (via role membership)'
        ELSE 'CHECK MANUALLY'
    END;

-- Network Connectivity Test (for diagnostics)
PRINT '';
PRINT '14. Recent Connection Activity:';
SELECT TOP 10
    login_name,
    host_name,
    program_name,
    login_time,
    last_request_start_time,
    last_request_end_time,
    status,
    
    -- Session Duration
    DATEDIFF(MINUTE, login_time, ISNULL(last_request_end_time, GETDATE())) as session_duration_minutes,
    
    -- Activity Level
    CASE 
        WHEN last_request_end_time >= DATEADD(MINUTE, -5, GETDATE()) THEN 'ACTIVE'
        WHEN last_request_end_time >= DATEADD(MINUTE, -30, GETDATE()) THEN 'RECENT'
        ELSE 'IDLE'
    END as activity_status

FROM sys.dm_exec_sessions
WHERE login_time >= DATEADD(HOUR, -2, GETDATE())  -- Last 2 hours
  AND is_user_process = 1
ORDER BY login_time DESC;

-- ========================================
-- MIRRORING HEALTH SUMMARY
-- ========================================

PRINT '';
PRINT '--- Mirroring Health Summary ---';
PRINT 'Overall health assessment of mirroring configuration.';
PRINT '';

-- Health Score Calculation
PRINT '15. Mirroring Health Score:';
WITH HealthMetrics AS (
    SELECT 
        -- Change Feed Status (40 points)
        CASE WHEN EXISTS (SELECT 1 FROM sys.change_feed_databases WHERE database_id = DB_ID()) 
             THEN 40 ELSE 0 END as change_feed_score,
        
        -- Table Coverage (30 points)
        (SELECT COUNT(*) * 30 / NULLIF((SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID('SalesLT')), 0)
         FROM sys.change_feed_tables 
         WHERE is_change_feed_enabled = 1) as table_coverage_score,
        
        -- Error Status (20 points)
        CASE WHEN NOT EXISTS (
            SELECT 1 FROM sys.change_feed_tables WHERE has_change_feed_exception = 1
        ) THEN 20 ELSE 0 END as error_status_score,
        
        -- Performance Status (10 points)  
        CASE WHEN (
            SELECT log_space_used_percent 
            FROM (
                SELECT CAST(FILEPROPERTY(name, 'SpaceUsed') AS FLOAT) / CAST(FILEPROPERTY(name, 'Size') AS FLOAT) * 100 as log_space_used_percent
                FROM sys.database_files WHERE type_desc = 'LOG'
            ) x
        ) < 75 THEN 10 ELSE 0 END as performance_score
),
HealthCalculation AS (
    SELECT 
        change_feed_score,
        table_coverage_score,
        error_status_score,
        performance_score,
        (change_feed_score + table_coverage_score + error_status_score + performance_score) as total_health_score
    FROM HealthMetrics
)
SELECT 
    total_health_score,
    change_feed_score,
    table_coverage_score,
    error_status_score,
    performance_score,
    
    -- Health Classification
    CASE 
        WHEN total_health_score >= 90 THEN 'EXCELLENT'
        WHEN total_health_score >= 75 THEN 'GOOD'
        WHEN total_health_score >= 60 THEN 'FAIR'
        WHEN total_health_score >= 40 THEN 'POOR'
        ELSE 'CRITICAL'
    END as health_status,
    
    -- Recommendations
    CASE 
        WHEN change_feed_score = 0 THEN 'Enable Change Feed for mirroring'
        WHEN table_coverage_score < 30 THEN 'Configure more tables for mirroring'
        WHEN error_status_score = 0 THEN 'Resolve Change Feed exceptions'
        WHEN performance_score = 0 THEN 'Monitor transaction log space'
        ELSE 'Mirroring is healthy'
    END as primary_recommendation

FROM HealthCalculation;

-- ========================================
-- RECOMMENDED ACTIONS
-- ========================================

PRINT '';
PRINT '--- Recommended Actions ---';
PRINT 'Based on the monitoring results, here are recommended actions:';
PRINT '';

-- Generate Dynamic Recommendations
DECLARE @recommendations TABLE (
    priority INT,
    category VARCHAR(50),
    recommendation VARCHAR(500)
);

-- Check Change Feed Status
IF NOT EXISTS (SELECT 1 FROM sys.change_feed_databases WHERE database_id = DB_ID())
    INSERT INTO @recommendations VALUES (1, 'CRITICAL', 'Change Feed is not enabled. Configure mirroring in Fabric portal.');

-- Check for exceptions
IF EXISTS (SELECT 1 FROM sys.change_feed_tables WHERE has_change_feed_exception = 1)
    INSERT INTO @recommendations VALUES (2, 'HIGH', 'Some tables have Change Feed exceptions. Review table compatibility.');

-- Check log space
IF EXISTS (
    SELECT 1 FROM sys.database_files 
    WHERE type_desc = 'LOG' 
    AND CAST(FILEPROPERTY(name, 'SpaceUsed') AS FLOAT) / CAST(FILEPROPERTY(name, 'Size') AS FLOAT) * 100 > 75
)
    INSERT INTO @recommendations VALUES (3, 'MEDIUM', 'Transaction log space usage is high. Monitor for long-running transactions.');

-- Check for long-running transactions
IF EXISTS (
    SELECT 1 FROM sys.dm_tran_active_transactions 
    WHERE DATEDIFF(MINUTE, transaction_begin_time, GETDATE()) > 30
)
    INSERT INTO @recommendations VALUES (4, 'MEDIUM', 'Long-running transactions detected. May impact mirroring performance.');

-- Check for blocking
IF EXISTS (SELECT 1 FROM sys.dm_exec_requests WHERE blocking_session_id != 0)
    INSERT INTO @recommendations VALUES (5, 'LOW', 'Blocking sessions detected. May cause mirroring delays.');

-- Default recommendation if no issues
IF NOT EXISTS (SELECT 1 FROM @recommendations)
    INSERT INTO @recommendations VALUES (1, 'INFO', 'Mirroring appears to be healthy. Continue regular monitoring.');

-- Display recommendations
SELECT 
    priority,
    category,
    recommendation,
    
    -- Action Items
    CASE category
        WHEN 'CRITICAL' THEN 'Immediate action required'
        WHEN 'HIGH' THEN 'Address within 24 hours'
        WHEN 'MEDIUM' THEN 'Address within a week'
        WHEN 'LOW' THEN 'Monitor and address as needed'
        ELSE 'For information only'
    END as action_timeline
    
FROM @recommendations
ORDER BY priority;

-- ========================================
-- SUMMARY
-- ========================================

PRINT '';
PRINT '=== MONITORING SUMMARY ===';
PRINT '';
PRINT '📊 Monitoring Complete!';
PRINT '';
PRINT '✅ What was checked:';
PRINT '   🔍 Change Feed status and configuration';
PRINT '   📈 Database performance and resource usage';
PRINT '   📋 Transaction log health';
PRINT '   🔄 Data change activity';
PRINT '   ❌ Error detection and diagnostics';
PRINT '   🔧 Configuration verification';
PRINT '   💊 Health score calculation';
PRINT '';
PRINT '📋 Use these queries to:';
PRINT '   • Monitor mirroring performance in real-time';
PRINT '   • Troubleshoot mirroring issues';
PRINT '   • Optimize database performance for mirroring';
PRINT '   • Ensure data consistency between source and Fabric';
PRINT '   • Plan maintenance windows';
PRINT '';
PRINT '⚡ Pro Tips:';
PRINT '   • Run health checks before and after major changes';
PRINT '   • Monitor transaction log space during high-volume operations';
PRINT '   • Set up alerts for long-running transactions';
PRINT '   • Regular review of Change Feed exceptions';
PRINT '   • Coordinate with Fabric team on performance issues';
PRINT '';
PRINT '📁 Repository: https://github.com/stuba83/fabric-mirroring-demo';
PRINT '🐛 Issues or questions? https://github.com/stuba83/fabric-mirroring-demo/issues';
PRINT '';
PRINT '📧 For production support:';
PRINT '   • Azure SQL Database: Azure Support Portal';
PRINT '   • Microsoft Fabric: Fabric Support or Microsoft Support';
PRINT '   • Community: Microsoft Tech Community forums';

-- ========================================
-- AUTOMATION SUGGESTIONS
-- ========================================

/*
AUTOMATION RECOMMENDATIONS:
============================

1. SCHEDULED MONITORING:
   - Create SQL Agent Jobs (if available) to run key monitoring queries
   - Set up Azure Monitor alerts for critical metrics
   - Use Azure Automation for regular health checks

2. ALERTING THRESHOLDS:
   - Transaction log space > 75%: WARNING
   - Transaction log space > 90%: CRITICAL  
   - Long-running transactions > 30 minutes: WARNING
   - Change Feed exceptions: CRITICAL
   - Blocking sessions > 30 seconds: WARNING

3. DASHBOARD INTEGRATION:
   - Integrate key metrics into operational dashboards
   - Use Power BI for real-time monitoring visualization
   - Set up mobile alerts for critical issues

4. RUNBOOK PROCEDURES:
   - Document standard operating procedures for common issues
   - Create escalation procedures for critical alerts
   - Maintain contact information for Fabric and Azure SQL support

5. PERFORMANCE BASELINES:
   - Establish baseline metrics for normal operation
   - Monitor trends over time
   - Adjust thresholds based on historical data

EXAMPLE ALERT QUERY:
===================

-- Use this in Azure Monitor or custom alerting solution
SELECT 
    'CRITICAL' as alert_level,
    'Transaction Log Full' as alert_type,
    log_space_used_percent,
    'Immediate action required' as message
FROM (
    SELECT 
        CAST(FILEPROPERTY(name, 'SpaceUsed') AS FLOAT) / CAST(FILEPROPERTY(name, 'Size') AS FLOAT) * 100 as log_space_used_percent
    FROM sys.database_files 
    WHERE type_desc = 'LOG'
) x
WHERE log_space_used_percent > 90;

*/