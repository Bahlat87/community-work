/******************************************************
 *
 * Name:         job-user-databases-optimize-indexes.sql
 *     
 * Design Phase:
 *     Author:   John Miner
 *     Date:     07-31-2014
 *     Purpose:  Maintenance job to optimize indexes weekly.
 * 
 ******************************************************/

/*  
	Which database to use.
*/

USE msdb
GO


/*  
	Remove existing job
*/

IF EXISTS (SELECT * FROM dbo.sysjobs WHERE name = N'User Databases:  Optimize Indexes')
EXEC msdb.dbo.sp_delete_job @job_name = N'User Databases:  Optimize Indexes'
GO


/*  
	Create new job
*/


/****** Object:  Job [User Databases:  Optimize Indexes]    Script Date: 03/26/2014 14:05:32 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0


/****** Object:  JobCategory [Database Maintenance]    Script Date: 03/26/2014 14:05:32 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END


DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'User Databases:  Optimize Indexes', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Maintenance Jobs', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'Basic Monitoring', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


/****** Object:  Step [Step 1]    Script Date: 03/26/2014 14:05:33 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step 1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--
-- User databases - Reorganize or Rebuild indexes - (1 x week)
--

EXECUTE msdb.dbo.IndexOptimize
    @Databases = ''USER_DATABASES'',
    @FragmentationLow = NULL,
    @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
    @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
    @FragmentationLevel1 = 10,
    @FragmentationLevel2 = 30,
    @UpdateStatistics = ''ALL'',
    @OnlyModifiedStatistics = ''Y'',
    @LogToTable = ''Y'';
', 
		@database_name=N'msdb', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'schUserDbOptimizeIndexes', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20140213, 
		@active_end_date=99991231, 
		@active_start_time=211500, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
