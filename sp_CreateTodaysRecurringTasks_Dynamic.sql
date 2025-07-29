USE [TT TimeUpdated]
GO

CREATE OR ALTER PROCEDURE sp_CreateTodaysRecurringTasks_Dynamic
    @ProcessDate DATE = NULL,  -- Optional parameter to process specific date (defaults to today)
    @TenantId INT = NULL,      -- Optional parameter to process specific tenant (defaults to all)
    @DryRun BIT = 0           -- Set to 1 to see what would be processed without making changes
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentTenantId INT;
    DECLARE @SchemaName NVARCHAR(100);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @TargetDate DATE = ISNULL(@ProcessDate, CAST(GETDATE() AS DATE));
    DECLARE @ProcessedCount INT = 0;
    DECLARE @ErrorCount INT = 0;
    DECLARE @TotalCandidates INT = 0;
    DECLARE @ColumnList NVARCHAR(MAX);
    DECLARE @SelectList NVARCHAR(MAX);
    
    -- Validate input
    IF @TargetDate > GETDATE()
    BEGIN
        RAISERROR('Cannot process future dates', 16, 1);
        RETURN;
    END
    
    PRINT '=== STARTING RECURRING TASK PROCESSING ===';
    PRINT 'Target Date: ' + CAST(@TargetDate AS NVARCHAR);
    PRINT 'Dry Run Mode: ' + CASE WHEN @DryRun = 1 THEN 'YES' ELSE 'NO' END;
    PRINT '';
    
    -- Cursor to iterate through tenants
    DECLARE tenant_cursor CURSOR FOR
    SELECT DISTINCT TenantId, SchemaName
    FROM Tenant
    WHERE SchemaName IS NOT NULL
        AND (@TenantId IS NULL OR TenantId = @TenantId);
    
    OPEN tenant_cursor;
    FETCH NEXT FROM tenant_cursor INTO @CurrentTenantId, @SchemaName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            PRINT 'Processing Schema: [' + @SchemaName + '] - Tenant ID: ' + CAST(@CurrentTenantId AS NVARCHAR);
            
            -- First, get the actual column structure for this schema's Task table
            SET @SQL = '
            DECLARE @Columns TABLE (ColumnName NVARCHAR(128), DataType NVARCHAR(128));
            
            INSERT INTO @Columns (ColumnName, DataType)
            SELECT COLUMN_NAME, DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = ''Task''
                AND TABLE_SCHEMA = ''' + @SchemaName + '''
                AND COLUMN_NAME IN (''TaskName'', ''TaskDescription'', ''StartDate'', ''EndDate'', 
                                   ''CompletionPercentage'', ''IsCompleted'', ''EmployeeId'', 
                                   ''ProjectId'', ''TotalPlannedWorkHours'', ''IsBillable'', 
                                   ''IsRecurring'', ''TaskId'');
            
            DECLARE @ColumnList NVARCHAR(MAX) = '''';
            DECLARE @SelectList NVARCHAR(MAX) = '''';
            
            -- Build dynamic column list based on what actually exists
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''TaskName'')
                SET @ColumnList = @ColumnList + ''TaskName, '';
            
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''TaskDescription'')
                SET @ColumnList = @ColumnList + ''TaskDescription, '';
            
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''StartDate'')
                SET @ColumnList = @ColumnList + ''StartDate, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''EndDate'')
                SET @ColumnList = @ColumnList + ''EndDate, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''CompletionPercentage'')
                SET @ColumnList = @ColumnList + ''CompletionPercentage, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''IsCompleted'')
                SET @ColumnList = @ColumnList + ''IsCompleted, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''EmployeeId'')
                SET @ColumnList = @ColumnList + ''EmployeeId, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''ProjectId'')
                SET @ColumnList = @ColumnList + ''ProjectId, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''TotalPlannedWorkHours'')
                SET @ColumnList = @ColumnList + ''TotalPlannedWorkHours, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''IsBillable'')
                SET @ColumnList = @ColumnList + ''IsBillable, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''IsRecurring'')
                SET @ColumnList = @ColumnList + ''IsRecurring'';
            
            -- Remove trailing comma
            IF RIGHT(@ColumnList, 2) = '', ''
                SET @ColumnList = LEFT(@ColumnList, LEN(@ColumnList) - 2);
            
            -- Build SELECT list with appropriate values
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''TaskName'')
                SET @SelectList = @SelectList + ''CAST(t.TaskName AS NVARCHAR(MAX)) + '''' - '''' + FORMAT(@TargetDate, ''''yyyy-MM-dd'''') as TaskName, '';
            
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''TaskDescription'')
                SET @SelectList = @SelectList + ''CASE WHEN t.TaskDescription IS NULL THEN ''''Auto-created '''' + FORMAT(GETDATE(), ''''yyyy-MM-dd HH:mm'''') ELSE CAST(t.TaskDescription AS NVARCHAR(MAX)) + '''' (Auto-created '''' + FORMAT(GETDATE(), ''''yyyy-MM-dd HH:mm'''') + '''')''''  END as TaskDescription, '';
            
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''StartDate'')
                SET @SelectList = @SelectList + ''@TargetDate as StartDate, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''EndDate'')
                SET @SelectList = @SelectList + ''CASE WHEN DATEDIFF(DAY, t.StartDate, t.EndDate) = 0 THEN @TargetDate ELSE DATEADD(DAY, DATEDIFF(DAY, t.StartDate, t.EndDate), @TargetDate) END as EndDate, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''CompletionPercentage'')
                SET @SelectList = @SelectList + ''0.00 as CompletionPercentage, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''IsCompleted'')
                SET @SelectList = @SelectList + ''0 as IsCompleted, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''EmployeeId'')
                SET @SelectList = @SelectList + ''t.EmployeeId, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''ProjectId'')
                SET @SelectList = @SelectList + ''t.ProjectId, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''TotalPlannedWorkHours'')
                SET @SelectList = @SelectList + ''t.TotalPlannedWorkHours, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''IsBillable'')
                SET @SelectList = @SelectList + ''t.IsBillable, '';
                
            IF EXISTS (SELECT 1 FROM @Columns WHERE ColumnName = ''IsRecurring'')
                SET @SelectList = @SelectList + ''0 as IsRecurring'';
            
            -- Remove trailing comma
            IF RIGHT(@SelectList, 2) = '', ''
                SET @SelectList = LEFT(@SelectList, LEN(@SelectList) - 2);
            
            SELECT @ColumnList as AvailableColumns, @SelectList as SelectClause;
            ';
            
            -- Get column information for this schema
            DECLARE @ColumnInfo TABLE (AvailableColumns NVARCHAR(MAX), SelectClause NVARCHAR(MAX));
            INSERT INTO @ColumnInfo
            EXEC sp_executesql @SQL, N'@TargetDate DATE', @TargetDate = @TargetDate;
            
            SELECT @ColumnList = AvailableColumns, @SelectList = SelectClause FROM @ColumnInfo;
            
            -- Now build the actual processing SQL
            SET @SQL = '
            DECLARE @CurrentProcessedCount INT = 0;
            DECLARE @CurrentCandidateCount INT = 0;
            
            -- First, count candidates for this schema
            SELECT @CurrentCandidateCount = COUNT(*)
            FROM [' + @SchemaName + '].Task t
            INNER JOIN [' + @SchemaName + '].RecurringTaskDates rtd 
                ON t.TaskId = rtd.TaskId 
            WHERE rtd.TaskDate = @TargetDate
                AND rtd.TenantId = ' + CAST(@CurrentTenantId AS NVARCHAR) + '
                AND t.IsRecurring = 1
                AND NOT EXISTS (
                    SELECT 1 FROM [' + @SchemaName + '].Task existing
                    WHERE CAST(existing.TaskName AS NVARCHAR(MAX)) LIKE CAST(t.TaskName AS NVARCHAR(MAX)) + ''%'' + FORMAT(@TargetDate, ''yyyy-MM-dd'') + ''%''
                        AND existing.StartDate = @TargetDate
                        AND existing.ProjectId = t.ProjectId
                );
            ';
            
            IF @DryRun = 1
            BEGIN
                SET @SQL = @SQL + '
                -- DRY RUN: Show what would be created
                SELECT 
                    t.TaskId,
                    CAST(t.TaskName AS NVARCHAR(MAX)) + '' - '' + FORMAT(@TargetDate, ''yyyy-MM-dd'') as ProposedTaskName,
                    rtd.TaskDate as ScheduledDate,
                    ''DRY RUN - Would Create'' as Status
                FROM [' + @SchemaName + '].Task t
                INNER JOIN [' + @SchemaName + '].RecurringTaskDates rtd ON t.TaskId = rtd.TaskId 
                WHERE rtd.TaskDate = @TargetDate
                    AND rtd.TenantId = ' + CAST(@CurrentTenantId AS NVARCHAR) + '
                    AND t.IsRecurring = 1
                    AND NOT EXISTS (
                        SELECT 1 FROM [' + @SchemaName + '].Task existing
                        WHERE CAST(existing.TaskName AS NVARCHAR(MAX)) LIKE CAST(t.TaskName AS NVARCHAR(MAX)) + ''%'' + FORMAT(@TargetDate, ''yyyy-MM-dd'') + ''%''
                            AND existing.StartDate = @TargetDate
                            AND existing.ProjectId = t.ProjectId
                    );
                ';
            END
            ELSE
            BEGIN
                SET @SQL = @SQL + '
                -- ACTUAL PROCESSING: Create new tasks
                INSERT INTO [' + @SchemaName + '].Task (' + @ColumnList + ')
                SELECT ' + @SelectList + '
                FROM [' + @SchemaName + '].Task t
                INNER JOIN [' + @SchemaName + '].RecurringTaskDates rtd ON t.TaskId = rtd.TaskId 
                WHERE rtd.TaskDate = @TargetDate
                    AND rtd.TenantId = ' + CAST(@CurrentTenantId AS NVARCHAR) + '
                    AND t.IsRecurring = 1
                    AND NOT EXISTS (
                        SELECT 1 FROM [' + @SchemaName + '].Task existing
                        WHERE CAST(existing.TaskName AS NVARCHAR(MAX)) LIKE CAST(t.TaskName AS NVARCHAR(MAX)) + ''%'' + FORMAT(@TargetDate, ''yyyy-MM-dd'') + ''%''
                            AND existing.StartDate = @TargetDate
                            AND existing.ProjectId = t.ProjectId
                    );
                
                SET @CurrentProcessedCount = @@ROWCOUNT;
                ';
            END
            
            SET @SQL = @SQL + '
            SELECT @CurrentProcessedCount as ProcessedCount, @CurrentCandidateCount as CandidateCount;
            ';
            
            -- Execute dynamic SQL and capture results
            DECLARE @Results TABLE (ProcessedCount INT, CandidateCount INT);
            INSERT INTO @Results
            EXEC sp_executesql @SQL, N'@TargetDate DATE', @TargetDate = @TargetDate;
            
            DECLARE @CurrentCount INT, @CurrentCandidates INT;
            SELECT @CurrentCount = ProcessedCount, @CurrentCandidates = CandidateCount FROM @Results;
            
            SET @ProcessedCount = @ProcessedCount + ISNULL(@CurrentCount, 0);
            SET @TotalCandidates = @TotalCandidates + ISNULL(@CurrentCandidates, 0);
            
            PRINT '  - Candidates Found: ' + CAST(ISNULL(@CurrentCandidates, 0) AS NVARCHAR);
            PRINT '  - Tasks ' + CASE WHEN @DryRun = 1 THEN 'Would Be Created' ELSE 'Created' END + ': ' + CAST(ISNULL(@CurrentCount, 0) AS NVARCHAR);
            PRINT '  - Columns Available: ' + ISNULL(@ColumnList, 'None detected');
            PRINT '';
            
        END TRY
        BEGIN CATCH
            SET @ErrorCount = @ErrorCount + 1;
            PRINT '  *** ERROR: ' + ERROR_MESSAGE();
            PRINT '  *** Error Details: Line ' + CAST(ERROR_LINE() AS NVARCHAR) + ', Number ' + CAST(ERROR_NUMBER() AS NVARCHAR);
            PRINT '';
        END CATCH
        
        FETCH NEXT FROM tenant_cursor INTO @CurrentTenantId, @SchemaName;
    END
    
    CLOSE tenant_cursor;
    DEALLOCATE tenant_cursor;
    
    -- Final summary report
    PRINT '=== FINAL SUMMARY ===';
    PRINT 'Date Processed: ' + CAST(@TargetDate AS NVARCHAR);
    PRINT 'Mode: ' + CASE WHEN @DryRun = 1 THEN 'DRY RUN' ELSE 'ACTUAL PROCESSING' END;
    PRINT 'Total Candidates Found: ' + CAST(@TotalCandidates AS NVARCHAR);
    PRINT 'Total Tasks ' + CASE WHEN @DryRun = 1 THEN 'That Would Be Created' ELSE 'Created' END + ': ' + CAST(@ProcessedCount AS NVARCHAR);
    PRINT 'Schemas with Errors: ' + CAST(@ErrorCount AS NVARCHAR);
    PRINT 'Process Completed at: ' + CAST(GETDATE() AS NVARCHAR);
    
    -- Return summary for external monitoring/logging
    SELECT 
        @TargetDate as ProcessDate,
        @TotalCandidates as TotalCandidates,
        @ProcessedCount as TotalTasksProcessed,
        @ErrorCount as ErrorCount,
        @DryRun as WasDryRun,
        GETDATE() as ProcessedAt;
END

GO

-- Usage Examples:

-- 1. Test with dry run first (RECOMMENDED)
-- EXEC sp_CreateTodaysRecurringTasks_Dynamic @DryRun = 1;

-- 2. Process today's recurring tasks (actual execution)
-- EXEC sp_CreateTodaysRecurringTasks_Dynamic;