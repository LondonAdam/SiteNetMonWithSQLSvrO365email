*** Remote site or VPN network monitoring With SQLserver & O365email ***


Say you have remote site(s) with an unreliable network connection – whether that be due to a challenging ISP,  or perhaps a VPN that is sometimes overloaded.
A continuous ping to an IP at the remote site is a good way to verify connectivity. You find the times when the issue becomes user effecting  matches the times when you get multiple ‘time outs’ on the ping.   So you want a quick & free way to get email alerts when this happens.
If you have an SQL server, this code should do the job.  It may take 20 mins or so to setup the first time, then should take only 2 mins or so to start monitoring a new site.
This Repository is what you should use if you have an Office 365 email account,  but don’t control an SMTP relay server.  If you have an SMTP relay and can amend it so it relays emails that originate from your SQL servers IP, then it’s quicker for you to use the code in the  siteMonitorWithSQLserver&SMTPrelay  repository instead.

*** Warning about xp_cmdshell ***
The stored procedure used here uses xp_cmdshell, and if it is currently disabled on server, it will temporarily enable it. If you have other code running on the same server doing this temporary enablement 8& disablement, it may cause issues if two different processes run at about the same time.
This has never been the case at anywhere I've worked, but I've seen on the web that a few people think it's a major security risk to enable xp_cmdshell even temporarily.


*** Set up needed the first time you use these alerts ***
Create emailO365LongMsg.exe
1)	Using Visual Studio, start a new ‘Visual c#’ console application project, with the ‘Name:’ (& ‘Solution name’ ) amended to be emailO365LongMsg 
2)	Copy the code from c#O365EmailLongMsg.txt, and replace what’s already present in ‘Program.cs.’
3)	Near the top of the new Program.cs code, amend the values assigned to ‘msgFrom’  & ‘EMpassword’ to match your office 365 email.   ( msgFrom should = your actual email address.)  More typically apps read these sorts of values from a config file, but in this case it seemed more secure to hard code them.
4)	Select ‘Build Solution’  from the Build menu of Visual studio.
5)	Create a C:\code folder on your SQL server, if one doesn’t already existt.
6)	Copy emailO365LongMsg.exe from  ..\emailO365LongMsg\emailO365LongMsg\bin\Debug on the client you use for Visual Studio,  to the c:\code folder on your SQL server.

Create the monitoring DB & SQL login
1)	Run setupMonitorDB.SQL on your SQL server using SQL studio.

*** Set up needed  every time you set these alerts for a new site.
1)	Copy CreateSTtoredProc.SQL into SQLstudio
2)	Carry out the 3 steps in the ‘PRE-CREATION SETUP’  sub section, in the commented out block at the top of the SP.
3)	Create the SP.
4)	If this is the first time you have set up one of these email alerts, create a new SQL agent job called pingMonitoring,  schedule it to run every 5 mins, and have it call the Stored Procedure you have just created.

If you already have an SQL job for the ping monitoring,  don’t create a new one,  instead add the new Stored Procedure to the existing job, so that the sprocs for different sits run sequentially, i.e.  ‘step 1’ of your pingMonitoring job might read:

exec usp_CalgaryMonO365email
exec usp_CapeTownMonO365email
exec usp_10VPNMonO365email


