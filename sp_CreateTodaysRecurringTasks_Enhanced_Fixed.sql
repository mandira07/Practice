USE [TT TimeUpdated]
GO

CREATE OR ALTER PROCEDURE sp_CreateTodaysRecurringTasks_Enhanced_Fixed
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
            
            -- Build dynamic SQL for each schema
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
                AND t.IsRecurring = 1  -- Original task should be recurring
                AND NOT EXISTS (
                    -- Check if task already created for this date
                    SELECT 1 FROM [' + @SchemaName + '].Task existing
                    WHERE CAST(existing.TaskName AS NVARCHAR(MAX)) LIKE CAST(t.TaskName AS NVARCHAR(MAX)) + ''%'' + FORMAT(@TargetDate, ''yyyy-MM-dd'') + ''%''
                        AND existing.StartDate = @TargetDate
                        AND existing.ProjectId = t.ProjectId
                );
            
            SELECT @CurrentCandidateCount as CandidateCount;
            ';
            
            -- Check candidates first
            IF @DryRun = 1
            BEGIN
                SET @SQL = @SQL + '
                -- DRY RUN: Show what would be created
                SELECT 
                    t.TaskId,
                    CAST(t.TaskName AS NVARCHAR(MAX)) + '' - '' + FORMAT(@TargetDate, ''yyyy-MM-dd'') as ProposedTaskName,
                    CASE 
                        WHEN t.TaskDescription IS NULL THEN NULL
                        ELSE CAST(t.TaskDescription AS NVARCHAR(MAX))
                    END as TaskDescription,
                    @TargetDate as ProposedStartDate,
                    CASE 
                        WHEN DATEDIFF(DAY, t.StartDate, t.EndDate) = 0 
                        THEN @TargetDate 
                        ELSE DATEADD(DAY, DATEDIFF(DAY, t.StartDate, t.EndDate), @TargetDate)
                    END as ProposedEndDate,
                    t.EmployeeId,
                    t.ProjectId,
                    rtd.TaskDate as ScheduledDate,
                    ''DRY RUN - Would Create'' as Status
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
            END
            ELSE
            BEGIN
                SET @SQL = @SQL + '
                -- ACTUAL PROCESSING: Create new tasks
                INSERT INTO [' + @SchemaName + '].Task (
                    TaskName,
                    TaskDescription, 
                    StartDate,
                    EndDate,
                    CompletionPercentage,
                    IsCompleted,
                    EmployeeId,
                    ProjectId,
                    TotalPlannedWorkHours,
                    IsBillable,
                    IsRecurring
                )
                SELECT 
                    CAST(t.TaskName AS NVARCHAR(MAX)) + '' - '' + FORMAT(@TargetDate, ''yyyy-MM-dd'') as TaskName,
                    CASE 
                        WHEN t.TaskDescription IS NULL THEN ''Auto-created '' + FORMAT(GETDATE(), ''yyyy-MM-dd HH:mm'')
                        ELSE CAST(t.TaskDescription AS NVARCHAR(MAX)) + '' (Auto-created '' + FORMAT(GETDATE(), ''yyyy-MM-dd HH:mm'') + '')''
                    END as TaskDescription,
                    @TargetDate as StartDate,
                    CASE 
                        WHEN DATEDIFF(DAY, t.StartDate, t.EndDate) = 0 
                        THEN @TargetDate 
                        ELSE DATEADD(DAY, DATEDIFF(DAY, t.StartDate, t.EndDate), @TargetDate)
                    END as EndDate,
                    0.00 as CompletionPercentage,
                    0 as IsCompleted,
                    t.EmployeeId,
                    t.ProjectId,
                    t.TotalPlannedWorkHours,
                    t.IsBillable,
                    0 as IsRecurring  -- New task is not recurring
                FROM [' + @SchemaName + '].Task t
                INNER JOIN [' + @SchemaName + '].RecurringTaskDates rtd 
                    ON t.TaskId = rtd.TaskId 
                WHERE rtd.TaskDate = @TargetDate
                    AND rtd.TenantId = ' + CAST(@CurrentTenantId AS NVARCHAR) + '
                    AND t.IsRecurring = 1  -- Original task should be recurring
                    AND NOT EXISTS (
                        -- Prevent duplicate task creation
                        SELECT 1 FROM [' + @SchemaName + '].Task existing
                        WHERE CAST(existing.TaskName AS NVARCHAR(MAX)) LIKE CAST(t.TaskName AS NVARCHAR(MAX)) + ''%'' + FORMAT(@TargetDate, ''yyyy-MM-dd'') + ''%''
                            AND existing.StartDate = @TargetDate
                            AND existing.ProjectId = t.ProjectId
                    );
                
                SET @CurrentProcessedCount = @@ROWCOUNT;
                
                -- Optional: Mark recurring task dates as processed
                -- Add a ProcessedDate column to RecurringTaskDates table for better tracking
                -- UPDATE [' + @SchemaName + '].RecurringTaskDates 
                -- SET ProcessedDate = GETDATE()
                -- WHERE TaskDate = @TargetDate 
                --     AND TenantId = ' + CAST(@CurrentTenantId AS NVARCHAR) + ';
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
-- EXEC sp_CreateTodaysRecurringTasks_Enhanced_Fixed @DryRun = 1;

-- 2. Process today's recurring tasks (actual execution)
-- EXEC sp_CreateTodaysRecurringTasks_Enhanced_Fixed;

-- 3. Process specific date for all tenants
-- EXEC sp_CreateTodaysRecurringTasks_Enhanced_Fixed @ProcessDate = '2025-01-20';

-- 4. Process specific tenant only
-- EXEC sp_CreateTodaysRecurringTasks_Enhanced_Fixed @TenantId = 10;

-- 5. Dry run for specific date and tenant
-- EXEC sp_CreateTodaysRecurringTasks_Enhanced_Fixed @ProcessDate = '2025-01-20', @TenantId = 10, @DryRun = 1;