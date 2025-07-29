-- =============================================
-- Diagnostic Script: Schema Analysis for Task Tables
-- This script analyzes the structure of Task tables across all schemas
-- to identify data types and potential compatibility issues
-- =============================================

USE [TT TimeUpdated]
GO

DECLARE @SchemaName NVARCHAR(100);
DECLARE @SQL NVARCHAR(MAX);
DECLARE @Results TABLE (
    SchemaName NVARCHAR(100),
    ColumnName NVARCHAR(128),
    DataType NVARCHAR(128),
    MaxLength INT,
    IsNullable BIT
);

PRINT '=== TASK TABLE STRUCTURE ANALYSIS ===';
PRINT 'Analyzing Task table structure across all schemas...';
PRINT '';

-- Cursor to iterate through all schemas
DECLARE schema_cursor CURSOR FOR
SELECT DISTINCT SchemaName
FROM Tenant
WHERE SchemaName IS NOT NULL;

OPEN schema_cursor;
FETCH NEXT FROM schema_cursor INTO @SchemaName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        PRINT 'Analyzing Schema: [' + @SchemaName + ']';
        
        -- Build dynamic SQL to get column information
        SET @SQL = '
        SELECT 
            ''' + @SchemaName + ''' as SchemaName,
            c.COLUMN_NAME,
            c.DATA_TYPE + 
            CASE 
                WHEN c.DATA_TYPE IN (''varchar'', ''nvarchar'', ''char'', ''nchar'') 
                THEN ''('' + CASE WHEN c.CHARACTER_MAXIMUM_LENGTH = -1 THEN ''MAX'' ELSE CAST(c.CHARACTER_MAXIMUM_LENGTH AS VARCHAR) END + '')''
                WHEN c.DATA_TYPE IN (''decimal'', ''numeric'') 
                THEN ''('' + CAST(c.NUMERIC_PRECISION AS VARCHAR) + '','' + CAST(c.NUMERIC_SCALE AS VARCHAR) + '')''
                ELSE ''''
            END as DataType,
            ISNULL(c.CHARACTER_MAXIMUM_LENGTH, 0) as MaxLength,
            CASE WHEN c.IS_NULLABLE = ''YES'' THEN 1 ELSE 0 END as IsNullable
        FROM INFORMATION_SCHEMA.COLUMNS c
        WHERE c.TABLE_NAME = ''Task''
            AND c.TABLE_SCHEMA = ''' + @SchemaName + '''
            AND c.COLUMN_NAME IN (''TaskName'', ''TaskDescription'', ''TaskId'', ''StartDate'', ''EndDate'', 
                                 ''IsRecurring'', ''ProjectId'', ''EmployeeId'', ''IsCompleted'', 
                                 ''CompletionPercentage'', ''TotalPlannedWorkHours'', ''IsBillable'')
        ORDER BY c.ORDINAL_POSITION;
        ';
        
        INSERT INTO @Results
        EXEC sp_executesql @SQL;
        
    END TRY
    BEGIN CATCH
        PRINT '  *** ERROR: ' + ERROR_MESSAGE();
    END CATCH
    
    FETCH NEXT FROM schema_cursor INTO @SchemaName;
END

CLOSE schema_cursor;
DEALLOCATE schema_cursor;

-- Display results grouped by column name
PRINT '';
PRINT '=== COLUMN DATA TYPE ANALYSIS ===';

SELECT 
    ColumnName,
    DataType,
    COUNT(*) as SchemaCount,
    STRING_AGG(SchemaName, ', ') as SchemasWithThisType
FROM @Results
GROUP BY ColumnName, DataType
ORDER BY ColumnName, SchemaCount DESC;

PRINT '';
PRINT '=== POTENTIAL ISSUES ===';

-- Check for TEXT data types (problematic for concatenation)
IF EXISTS (SELECT 1 FROM @Results WHERE DataType = 'text')
BEGIN
    PRINT 'WARNING: TEXT data type found in the following columns:';
    SELECT DISTINCT ColumnName, STRING_AGG(SchemaName, ', ') as AffectedSchemas
    FROM @Results 
    WHERE DataType = 'text'
    GROUP BY ColumnName;
    PRINT '';
END

-- Check for inconsistent data types across schemas
PRINT 'Columns with inconsistent data types across schemas:';
SELECT 
    ColumnName,
    COUNT(DISTINCT DataType) as DifferentDataTypes,
    STRING_AGG(DataType + ' (' + STRING_AGG(SchemaName, ',') + ')', ' | ') as TypesAndSchemas
FROM @Results
GROUP BY ColumnName
HAVING COUNT(DISTINCT DataType) > 1
ORDER BY ColumnName;

PRINT '';
PRINT '=== RECOMMENDED FIXES ===';
PRINT '1. If TEXT columns are found, they should be converted to NVARCHAR(MAX) for better compatibility';
PRINT '2. All schemas should have consistent data types for the same columns';
PRINT '3. The fixed stored procedure uses CAST operations to handle TEXT columns safely';

PRINT '';
PRINT '=== RECURRING TASK DATES TABLE ANALYSIS ===';

-- Reset for RecurringTaskDates analysis
DELETE FROM @Results;

OPEN schema_cursor;
FETCH NEXT FROM schema_cursor INTO @SchemaName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY        
        SET @SQL = '
        IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''RecurringTaskDates'' AND TABLE_SCHEMA = ''' + @SchemaName + ''')
        BEGIN
            SELECT 
                ''' + @SchemaName + ''' as SchemaName,
                c.COLUMN_NAME,
                c.DATA_TYPE as DataType,
                0 as MaxLength,
                CASE WHEN c.IS_NULLABLE = ''YES'' THEN 1 ELSE 0 END as IsNullable
            FROM INFORMATION_SCHEMA.COLUMNS c
            WHERE c.TABLE_NAME = ''RecurringTaskDates''
                AND c.TABLE_SCHEMA = ''' + @SchemaName + '''
            ORDER BY c.ORDINAL_POSITION;
        END
        ';
        
        INSERT INTO @Results
        EXEC sp_executesql @SQL;
        
    END TRY
    BEGIN CATCH
        PRINT '  Error analyzing RecurringTaskDates in schema [' + @SchemaName + ']: ' + ERROR_MESSAGE();
    END CATCH
    
    FETCH NEXT FROM schema_cursor INTO @SchemaName;
END

CLOSE schema_cursor;
DEALLOCATE schema_cursor;

SELECT 
    SchemaName,
    ColumnName,
    DataType
FROM @Results
ORDER BY SchemaName, ColumnName;

PRINT '';
PRINT 'Analysis Complete!';
PRINT 'Use the fixed stored procedure: sp_CreateTodaysRecurringTasks_Enhanced_Fixed';

GO