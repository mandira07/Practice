# Recurring Task Automation Solution

## Overview
This solution provides automatic task creation for recurring tasks across multiple schemas and tenants. It processes the `RecurringTaskDates` table daily to create new task instances based on scheduled recurring tasks.

## Requirements Analysis

### **Primary Requirements Met:**

✅ **Multi-Schema Support**: Works dynamically across all schemas for all tenants  
✅ **Daily Execution**: Processes tasks scheduled for today's date  
✅ **Recurring Task Processing**: Processes tasks from RecurringTaskDates table  
✅ **Dynamic Task Creation**: Creates actual tasks in Task table based on templates  
✅ **Date-Based Filtering**: Only processes tasks for today's date  
✅ **Tenant-Aware**: Handles multiple tenants across different schemas  

### **Technical Requirements Met:**

✅ **Schema Resolution**: Dynamically determines schema names for each tenant  
✅ **Task Template Replication**: Copies properties from original recurring task  
✅ **Date Management**: Updates task dates appropriately for new instances  
✅ **Status Management**: Ensures new tasks are not marked as recurring  
✅ **Error Handling**: Handles invalid tenants, missing schemas, and edge cases  
✅ **Transaction Safety**: Ensures data consistency during operations  

## Solution Components

### 1. **sp_CreateTodaysRecurringTasks.sql**
Basic stored procedure that:
- Iterates through all tenants and schemas
- Creates new tasks for today's recurring task dates
- Provides basic error handling and reporting

### 2. **sp_CreateTodaysRecurringTasks_Enhanced.sql** ⭐ **RECOMMENDED**
Enhanced stored procedure with advanced features:
- **Dry Run Mode**: Test what would be created without making changes
- **Flexible Date Processing**: Process specific dates, not just today
- **Tenant Filtering**: Process specific tenants only
- **Duplicate Prevention**: Prevents creating duplicate tasks
- **Comprehensive Logging**: Detailed progress and error reporting
- **Result Monitoring**: Returns summary data for external monitoring

### 3. **Setup_RecurringTaskJob.sql**
SQL Agent Job automation:
- Creates scheduled job to run daily at 6:00 AM
- Includes error handling and retry logic
- Creates execution log table for monitoring
- Provides job history tracking

## Key Features

### **Intelligent Task Creation Logic**
```sql
-- Only processes tasks where:
-- 1. Original task is recurring (IsRecurring = 1)
-- 2. Scheduled for target date in RecurringTaskDates
-- 3. No duplicate task already exists for that date
-- 4. Tenant and schema are valid
```

### **Dynamic Date Calculation**
- Preserves task duration from original task
- Sets appropriate start and end dates for new instances
- Handles single-day and multi-day tasks correctly

### **Comprehensive Error Prevention**
- Checks for duplicate tasks before creation
- Validates tenant and schema existence
- Handles missing data gracefully
- Provides detailed error reporting

## Usage Examples

### **Basic Daily Execution (Automated)**
```sql
-- This runs automatically via SQL Agent Job
EXEC sp_CreateTodaysRecurringTasks_Enhanced;
```

### **Test Mode (Dry Run)**
```sql
-- See what would be created without making changes
EXEC sp_CreateTodaysRecurringTasks_Enhanced @DryRun = 1;
```

### **Process Specific Date**
```sql
-- Process recurring tasks for a specific date
EXEC sp_CreateTodaysRecurringTasks_Enhanced @ProcessDate = '2025-01-20';
```

### **Process Specific Tenant**
```sql
-- Process only one tenant
EXEC sp_CreateTodaysRecurringTasks_Enhanced @TenantId = 10;
```

### **Combined Options**
```sql
-- Dry run for specific tenant and date
EXEC sp_CreateTodaysRecurringTasks_Enhanced 
    @ProcessDate = '2025-01-20', 
    @TenantId = 10, 
    @DryRun = 1;
```

## Database Structure Assumptions

### **Required Tables:**
1. **Tenant**: Contains TenantId and SchemaName mappings
2. **RecurringTaskDates**: Contains scheduled task dates with TaskId, TenantId, TaskDate
3. **Task**: Contains task templates and stores new task instances

### **Key Columns:**
- `Task.IsRecurring`: Identifies original recurring tasks (1) vs instances (0)
- `RecurringTaskDates.TaskDate`: Date when task should be created
- `Tenant.SchemaName`: Dynamic schema for each tenant

## Installation Steps

### **Step 1: Create Stored Procedures**
```sql
-- Execute sp_CreateTodaysRecurringTasks_Enhanced.sql
-- This creates the main processing procedure
```

### **Step 2: Set Up Automation (Optional)**
```sql
-- Execute Setup_RecurringTaskJob.sql
-- This creates the daily SQL Agent Job
```

### **Step 3: Test the Solution**
```sql
-- Test with dry run first
EXEC sp_CreateTodaysRecurringTasks_Enhanced @DryRun = 1;

-- Then run actual processing
EXEC sp_CreateTodaysRecurringTasks_Enhanced;
```

## Monitoring and Maintenance

### **Check Job Status**
```sql
-- View recent job executions
SELECT 
    j.name AS JobName,
    h.run_date,
    h.run_time,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
    END AS Status,
    h.message
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
WHERE j.name = 'Daily Recurring Task Creation'
ORDER BY h.run_date DESC, h.run_time DESC;
```

### **Check Processing Results**
```sql
-- View execution log
SELECT * FROM [TT TimeUpdated].dbo.JobExecutionLog 
ORDER BY ExecutionDate DESC;
```

### **Verify Created Tasks**
```sql
-- Check today's auto-created tasks
SELECT * FROM [SchemaName].Task 
WHERE StartDate = CAST(GETDATE() AS DATE)
    AND TaskName LIKE '% - ' + FORMAT(GETDATE(), 'yyyy-MM-dd')
    AND IsRecurring = 0;
```

## Customization Options

### **Modify Schedule**
- Edit the SQL Agent Job schedule to run at different times
- Add multiple schedules for different processing needs

### **Add Business Logic**
- Modify the task creation logic in the stored procedure
- Add custom validation rules
- Include additional task properties

### **Enhanced Logging**
- Add more detailed logging to JobExecutionLog table
- Create custom alerts for failures
- Implement email notifications

### **Performance Optimization**
- Add indexes on RecurringTaskDates (TaskDate, TenantId)
- Implement batch processing for large datasets
- Add parallel processing for multiple schemas

## Troubleshooting

### **Common Issues:**

**No tasks created despite having recurring task dates:**
- Verify IsRecurring = 1 on original tasks
- Check that RecurringTaskDates has entries for today
- Ensure tenant/schema mapping is correct

**Duplicate tasks being created:**
- Check the duplicate prevention logic
- Verify task naming convention is consistent
- Review existing tasks for the target date

**SQL Agent Job not running:**
- Verify SQL Agent service is running
- Check job owner has appropriate permissions
- Review job history for error details

**Permission errors:**
- Ensure job owner has access to all schemas
- Grant necessary permissions on target databases
- Verify dynamic SQL execution permissions

## Future Enhancements

### **Potential Improvements:**
1. **Web-based Monitoring Dashboard**
2. **Email Notifications for Success/Failure**
3. **Task Template Versioning**
4. **Advanced Scheduling Rules**
5. **Bulk Processing APIs**
6. **Integration with External Calendar Systems**

## Security Considerations

- Use service accounts with minimal required permissions
- Implement schema-level security for multi-tenant access
- Audit task creation activities
- Encrypt sensitive task data if required
- Regular security reviews of job permissions

---

**Note**: This solution assumes the IsRecurring condition logic is already handled by your existing recurring task setup procedures (like the referenced `sp_HandleRecurringTaskWeek`). This automation focuses on creating actual task instances from the scheduled dates in the RecurringTaskDates table.