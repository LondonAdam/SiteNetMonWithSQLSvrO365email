USE siteMon
GO
/****** Object:  StoredProcedure [dbo].[usp_XYMon]    Script Date: 05/23/2019 16:16:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*******************************************************************
* Purpose:  Generates emails to report on the status of the _XY network

* Overview: 
If network is detected as down an alert is sent . Then a second email once the network is detected as back up.   
If it goes down again in the @Interval period (default 3 hours), an 'intermitent' alert is sent, and there will be no further emails for the @Interval period. 

* Inputs:	 none

* Affects: email, + records result of check for each run in tbl_XYlog

* Output:  email only

* Usage:	exec usp_XYMonO365email

* Dev:

select * from tbl_XYlog order by chkDate desc


* Modification History:
	Created:   Adam Bartlett 09 Nov 2017
	

* PRE-CREATION SETUP  Please read!

Before creating this SP,  please modify as below.

1) Do a 'Find & Replace'   (Ctrl + H)  to replace all occureances  of the string _XY with an identifier for the site (or IP subnet) you are monitoring.  E.g. ,  if you are monitoring a connecting to Calgary,  you might replace '_XY' with '_Calgary'

2) In the section below labelled 'set your Site  specific variables here' , ammeend values for the top 3 variable so they match what you are trying to monitor.  

3) Run the code in the commented out section at the bottom of the SP, which is labelled 'Start of site specific table setup'   (Once you've done the 'Find & Replace' in step 1,  this will create the site specific tables needed for your monitoring.)

	
	
*******************************************************************/
create  procedure [dbo].[usp_XYMonO365email]
as

declare @pingCheck   varchar (3000)
declare @cnt smallint 
declare @Mcnt smallint 
declare @lineI varchar (300)
declare @Wlalert bit
declare @Interval smallint
declare @qEmail varchar (33)
Declare @emailCity varchar (3000)
declare @dySQL varchar (3330)
declare @esub varchar (300)
declare @eFrom varchar (300)
declare @eTo varchar (300)
declare @emsg varchar (2000)
declare @IPtoMonitor varchar (15)
declare @IPorSiteName varchar (30)
declare @tmpEnCmdShell bit = 0
declare @tmpEnAdvOptions bit = 0



--set your Site  specific variables here
set @eTo = 'Adam.Bartlett@aoitgroup.com'
set @IPtoMonitor = '5.148.9.20'
set @IPorSiteName = 'Test Site'

-- Default 180 minutes value should be fine.  Lower or raise to get more or less emails if intermitent issues develop.
set @Interval = 180


-- temp Enable CmdShell & advanced options if needed 
if (SELECT CONVERT(INT, ISNULL(value, value_in_use)) AS config_value
FROM  sys.configurations
WHERE  name = 'xp_cmdshell' ) = 0
set @tmpEnCmdShell = 1

if (SELECT CONVERT(INT, ISNULL(value, value_in_use)) AS config_value
FROM  sys.configurations
WHERE  name = 'show advanced options' ) = 0
set @tmpEnAdvOptions = 1


if (select @tmpEnAdvOptions) = 1 
begin
EXEC master.dbo.sp_configure 'show advanced options', 1
RECONFIGURE WITH OVERRIDE;
end


if (select @tmpEnCmdShell) = 1 
begin
EXEC master.dbo.sp_configure 'xp_cmdshell', 1
RECONFIGURE WITH OVERRIDE;
end


if 
( select stat from  tbl_XYcontrol where citem = 'currentStat') = 'intermittent' and 
( SELECT datediff (minute, actDate, getdate() ) from tbl_XYcontrol where  citem =  'errorEmail' ) > @Interval
update tbl_XYcontrol set stat = 'clear' where  citem =  'currentStat'


if 
( select stat from  tbl_XYcontrol where citem = 'currentStat') = 'down' and 
( SELECT datediff (minute, actDate, getdate() ) from tbl_XYcontrol where  citem =  'errorEmail' ) > @Interval
update tbl_XYcontrol set stat = 'clear' where  citem =  'currentStat'




set @Mcnt =0
recheck:
set @pingCheck  = 'Diagnostic trace  taken at  ' +  (select  CONVERT ( varchar (20),getdate(), 120) )
set @Wlalert = 0


-- testNet
truncate table tbl_XYMon
truncate table  tbl_XYMonbase
select @dySQL =  'insert into  tbl_XYMonbase (pingCheck) exec master.dbo.xp_cmdshell "ping -n 3 ' + @IPtoMonitor + ' "'
exec (@dySQL)

delete from tbl_XYMonbase where pingCheck is null
insert into tbl_XYMon (pingCheck) (select pingCheck from tbl_XYMonbase)

set @cnt = 1

WHILE @cnt < 12
BEGIN
set @lineI = (select pingCheck from tbl_XYMon   where   rowID = @cnt)
if @lineI is null set @lineI = ''
if len (@lineI) > 1	set @pingCheck = @pingCheck + CHAR (10) + CHAR (13) + CHAR (10)
set @pingCheck = @pingCheck + @lineI

SET @cnt = @cnt + 1;
END;


if (SELECT CHARINDEX  ('bytes' , @pingCheck) ) = 0 set @Wlalert =1
if (SELECT CHARINDEX  ('Destination' , @pingCheck) ) > 0 set @Wlalert =1
if (SELECT CHARINDEX  ('timed' , @pingCheck) ) > 0 set @Wlalert =1

insert into tbl_XYlog (alert) values (@Wlalert)
set @Mcnt = @Mcnt + 1

-- prevent a possible blip causing an alert
if @Mcnt < 3 and @Wlalert =1 goto recheck


-- Email Logic
If 
( select stat from  tbl_XYcontrol where citem = 'currentStat') = 'down' and @Wlalert = 0
Begin -- backup
	set @qEmail = 'backup'
	update tbl_XYcontrol set actDate = getdate() where  citem =  'fixEmail'
	update tbl_XYcontrol set actDate = getdate() , stat = 'clear' where  citem =  'currentStat'
End -- backup


If 
( select stat from  tbl_XYcontrol where citem = 'currentStat') = 'clear' and @Wlalert = 1
Begin -- issue

if
( SELECT datediff (minute, actDate, getdate() ) from tbl_XYcontrol where  citem =  'fixEmail' ) > @Interval
	begin -- down
	set @qEmail = 'down'
	update tbl_XYcontrol set actDate = getdate() where  citem =  'errorEmail'
	update tbl_XYcontrol set actDate = getdate() , stat = 'down' where  citem =  'currentStat'
	end -- down 
else
	begin -- intermittent
	set @qEmail = 'intermittent'
	update tbl_XYcontrol set actDate = getdate() where  citem =  'errorEmail'
	update tbl_XYcontrol set actDate = getdate() , stat = 'intermittent' where  citem =  'currentStat'
	end -- intermittent 
End -- issue


if @qEmail = 'backup'
Begin
set @esub  = @IPorSiteName + ' network back up'
set @emsg = 'No major  issues currently detected on the ' + @IPorSiteName + ' network.'
Endcurrently 

if @qEmail = 'down'
Begin
set @esub = @IPorSiteName + ' network may be  down'
set @emsg = 'Issues detected with the ' + @IPorSiteName + ' network:' + char (10) + char (13) + char (10) + char (13) + @pingCheck
End

if @qEmail = 'intermittent'
Begin
set @esub = @IPorSiteName + ' network experiencing intermitent issues.'
set @emsg = 'Intermitent issues detected with the ' + @IPorSiteName + ' network. No further emails from this monitoring system for the next ' + CAST ( @Interval as varchar (9)) + ' minutes.' + char (10) + char (13) + char (10) + char (13) + @pingCheck
End



if @qEmail is not null 
begin
update tbl_emailMsg set msgStat = 1
insert into tbl_emailMsg (msg, msgSub) values (@emsg , @esub )

select @dySQL =  'exec master.dbo.xp_cmdshell "C:\code\emailO365LongMsg.exe  ' + ' To:' + @eTo + ' "'
	exec (@dySQL)

update tbl_emailMsg set msgStat = 1
end


-- disable cmdShell if it was like this before this proc was called
if (select @tmpEnCmdShell) = 1 
begin

EXEC master.dbo.sp_configure 'xp_cmdshell', 0
RECONFIGURE WITH OVERRIDE;

end

if (select @tmpEnAdvOptions) = 1 
begin

EXEC master.dbo.sp_configure 'show advanced options', 0
RECONFIGURE WITH OVERRIDE;
end



/****

-- Start of site specific table setup

USE siteMon

create table tbl_XYlog
(
chkDate datetime default getdate(),
alert bit
)


create  table tbl_XYcontrol
(
actDate datetime default getdate()
,citem varchar (33)
,stat varchar (33)
)

-- add starter values
insert into tbl_XYcontrol (citem) values ('errorEmail')
insert into tbl_XYcontrol (citem , actDate) values ('fixEmail' , Getdate() - 3)
insert into tbl_XYcontrol (citem) values ('IntEmail')
insert into tbl_XYcontrol (citem) values ('currentStat')
update tbl_XYcontrol set stat = 'clear' where citem = 'currentStat'


CREATE TABLE [dbo].[tbl_XYMon](
	[rowID] [smallint] IDENTITY(1,1) NOT NULL,
	[pingCheck] [varchar](300) NULL
) 


CREATE TABLE [dbo].[tbl_XYMonbase](
	[pingCheck] [varchar](300) NULL
) 


--  end of site specific table setup


*****/
