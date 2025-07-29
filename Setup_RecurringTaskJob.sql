-- =============================================
-- SQL Agent Job Setup for Automatic Recurring Task Creation
-- This script creates a SQL Agent Job that runs daily to create recurring tasks
-- =============================================

USE [msdb]
GO

-- Step 1: Delete existing job if it exists
IF EXISTS (SELECT job_id FROM dbo.sysjobs WHERE name = N'Daily Recurring Task Creation')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'Daily Recurring Task Creation', @delete_unused_schedule = 1
    PRINT 'Existing job deleted.'
END

-- Step 2: Create the job
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

-- Create Job Category if it doesn't exist
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name = N'[Uncategorized (Local)]' AND category_class = 1)
BEGIN
    EXEC @ReturnCode = msdb.dbo.sp_add_category @class = N'JOB', @type = N'LOCAL', @name = N'[Uncategorized (Local)]'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

-- Create the job
EXEC @ReturnCode = msdb.dbo.sp_add_job 
    @job_name = N'Daily Recurring Task Creation', 
    @enabled = 1, 
    @notify_level_eventlog = 0, 
    @notify_level_email = 2, 
    @notify_level_netsend = 0, 
    @notify_level_page = 0, 
    @delete_level = 0, 
    @description = N'Automatically creates daily tasks based on recurring task schedules across all tenants and schemas.', 
    @category_name = N'[Uncategorized (Local)]', 
    @owner_login_name = N'sa'  -- Change to appropriate login

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

-- Step 3: Add job step
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep 
    @job_name = N'Daily Recurring Task Creation', 
    @step_name = N'Execute Recurring Task Creation', 
    @step_id = 1, 
    @cmdexec_success_code = 0, 
    @on_success_action = 1, 
    @on_success_step_id = 0, 
    @on_fail_action = 2, 
    @on_fail_step_id = 0, 
    @retry_attempts = 3, 
    @retry_interval = 5, 
    @os_run_priority = 0, 
    @subsystem = N'TSQL', 
    @command = N'
    -- Execute the recurring task creation procedure
    EXEC [TT TimeUpdated].dbo.sp_CreateTodaysRecurringTasks_Enhanced;
    
    -- Log the execution for audit purposes
    INSERT INTO [TT TimeUpdated].dbo.JobExecutionLog (
        JobName, 
        ExecutionDate, 
        Status, 
        Message
    )
    VALUES (
        ''Daily Recurring Task Creation'', 
        GETDATE(), 
        ''Success'', 
        ''Recurring tasks processed successfully''
    );
    ', 
    @database_name = N'TT TimeUpdated', 
    @flags = 0

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

-- Step 4: Create schedule to run daily at 6:00 AM
EXEC @ReturnCode = msdb.dbo.sp_add_schedule 
    @schedule_name = N'Daily at 6 AM', 
    @enabled = 1, 
    @freq_type = 4,  -- Daily
    @freq_interval = 1, 
    @freq_subday_type = 1, 
    @freq_subday_interval = 0, 
    @freq_relative_interval = 0, 
    @freq_recurrence_factor = 1, 
    @active_start_date = 20250120,  -- Change to current date (YYYYMMDD)
    @active_end_date = 99991231, 
    @active_start_time = 060000,  -- 6:00 AM
    @active_end_time = 235959

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

-- Step 5: Attach schedule to job
EXEC @ReturnCode = msdb.dbo.sp_attach_schedule 
    @job_name = N'Daily Recurring Task Creation', 
    @schedule_name = N'Daily at 6 AM'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

-- Step 6: Add the job to the local server
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver 
    @job_name = N'Daily Recurring Task Creation', 
    @server_name = N'(LOCAL)'

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION
PRINT 'Job "Daily Recurring Task Creation" created successfully!'
PRINT 'Schedule: Daily at 6:00 AM'
PRINT 'The job will create recurring tasks automatically each day.'
GOTO EndSave

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
    PRINT 'Error occurred. Job creation rolled back.'

EndSave:
GO

-- =============================================
-- Optional: Create Job Execution Log Table
-- This table will track job executions for monitoring
-- =============================================

USE [TT TimeUpdated]
GO

-- Create log table if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[JobExecutionLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[JobExecutionLog](
        [LogId] [int] IDENTITY(1,1) NOT NULL,
        [JobName] [nvarchar](100) NOT NULL,
        [ExecutionDate] [datetime] NOT NULL,
        [Status] [nvarchar](20) NOT NULL,
        [Message] [nvarchar](500) NULL,
        [TasksCreated] [int] NULL,
        [ErrorCount] [int] NULL,
    CONSTRAINT [PK_JobExecutionLog] PRIMARY KEY CLUSTERED ([LogId] ASC)
    ) ON [PRIMARY]
    
    PRINT 'JobExecutionLog table created successfully!'
END
ELSE
BEGIN
    PRINT 'JobExecutionLog table already exists.'
END

GO

-- =============================================
-- Test the job (Optional - uncomment to test)
-- =============================================

-- To test the job immediately, uncomment this line:
-- EXEC msdb.dbo.sp_start_job N'Daily Recurring Task Creation';

-- To view job history:
-- SELECT 
--     j.name AS JobName,
--     h.step_name,
--     h.run_date,
--     h.run_time,
--     h.run_duration,
--     CASE h.run_status
--         WHEN 0 THEN 'Failed'
--         WHEN 1 THEN 'Succeeded'
--         WHEN 2 THEN 'Retry'
--         WHEN 3 THEN 'Canceled'
--     END AS Status,
--     h.message
-- FROM msdb.dbo.sysjobs j
-- INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
-- WHERE j.name = 'Daily Recurring Task Creation'
-- ORDER BY h.run_date DESC, h.run_time DESC;

PRINT 'Setup complete! The job will run daily at 6:00 AM to create recurring tasks.'