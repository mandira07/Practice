USE [TT TimeUpdated]
GO

CREATE OR ALTER PROCEDURE sp_CreateTodaysRecurringTasks
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TenantId INT;
    DECLARE @SchemaName NVARCHAR(100);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @TodaysDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @ProcessedCount INT = 0;
    DECLARE @ErrorCount INT = 0;
    
    -- Cursor to iterate through all tenants
    DECLARE tenant_cursor CURSOR FOR
    SELECT DISTINCT TenantId, SchemaName
    FROM Tenant
    WHERE SchemaName IS NOT NULL;
    
    OPEN tenant_cursor;
    FETCH NEXT FROM tenant_cursor INTO @TenantId, @SchemaName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            -- Build dynamic SQL for each schema
            SET @SQL = '
            DECLARE @CurrentProcessedCount INT = 0;
            
            -- Create tasks for today''s recurring tasks
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
                t.TaskName + '' - '' + FORMAT(@TodaysDate, ''yyyy-MM-dd'') as TaskName,
                t.TaskDescription + '' (Auto-created from recurring task)'',
                @TodaysDate as StartDate,
                CASE 
                    WHEN DATEDIFF(DAY, t.StartDate, t.EndDate) = 0 
                    THEN @TodaysDate 
                    ELSE DATEADD(DAY, DATEDIFF(DAY, t.StartDate, t.EndDate), @TodaysDate)
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
                AND t.IsRecurring = 1
            WHERE rtd.TaskDate = @TodaysDate
                AND rtd.TenantId = ' + CAST(@TenantId AS NVARCHAR) + '
                AND NOT EXISTS (
                    -- Prevent duplicate task creation
                    SELECT 1 FROM [' + @SchemaName + '].Task existing
                    WHERE existing.TaskName = t.TaskName + '' - '' + FORMAT(@TodaysDate, ''yyyy-MM-dd'')
                        AND existing.StartDate = @TodaysDate
                        AND existing.ProjectId = t.ProjectId
                );
            
            SET @CurrentProcessedCount = @@ROWCOUNT;
            
            -- Mark the recurring task dates as processed (optional - depends on your business logic)
            -- You might want to keep them or mark them differently
            UPDATE [' + @SchemaName + '].RecurringTaskDates 
            SET TaskDate = TaskDate  -- Placeholder - you might want to add a ProcessedDate column
            WHERE TaskDate = @TodaysDate 
                AND TenantId = ' + CAST(@TenantId AS NVARCHAR) + ';
            
            SELECT @CurrentProcessedCount as ProcessedCount;
            ';
            
            -- Execute dynamic SQL and capture results
            DECLARE @TempTable TABLE (ProcessedCount INT);
            INSERT INTO @TempTable
            EXEC sp_executesql @SQL, N'@TodaysDate DATE', @TodaysDate = @TodaysDate;
            
            DECLARE @CurrentCount INT;
            SELECT @CurrentCount = ProcessedCount FROM @TempTable;
            SET @ProcessedCount = @ProcessedCount + ISNULL(@CurrentCount, 0);
            
            PRINT 'Schema [' + @SchemaName + '] - Tenant ID: ' + CAST(@TenantId AS NVARCHAR) + ' - Tasks Created: ' + CAST(ISNULL(@CurrentCount, 0) AS NVARCHAR);
            
        END TRY
        BEGIN CATCH
            SET @ErrorCount = @ErrorCount + 1;
            PRINT 'ERROR in Schema [' + @SchemaName + '] - Tenant ID: ' + CAST(@TenantId AS NVARCHAR) + ' - ' + ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM tenant_cursor INTO @TenantId, @SchemaName;
    END
    
    CLOSE tenant_cursor;
    DEALLOCATE tenant_cursor;
    
    -- Summary report
    PRINT '=== SUMMARY ===';
    PRINT 'Date Processed: ' + CAST(@TodaysDate AS NVARCHAR);
    PRINT 'Total Tasks Created: ' + CAST(@ProcessedCount AS NVARCHAR);
    PRINT 'Schemas with Errors: ' + CAST(@ErrorCount AS NVARCHAR);
    PRINT 'Process Completed at: ' + CAST(GETDATE() AS NVARCHAR);
    
    -- Return summary for external monitoring
    SELECT 
        @TodaysDate as ProcessDate,
        @ProcessedCount as TotalTasksCreated,
        @ErrorCount as ErrorCount,
        GETDATE() as ProcessedAt;
END

GO

-- Example execution
-- EXEC sp_CreateTodaysRecurringTasks;