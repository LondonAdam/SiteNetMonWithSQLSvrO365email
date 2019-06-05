use master
CREATE DATABASE siteMon;
go
use siteMon;
go

CREATE Login emailRead
WITH PASSWORD = 'Dani!G!H', CHECK_POLICY = OFF ;

CREATE USER emailRead FOR LOGIN emailRead;

exec sp_addrolemember db_datareader, emailRead


create table tbl_emailMsg
(
msgID int identity (1,1)
,mssgDate datetime default (getdate())
,msgStat tinyInt default (0)
,msg varchar (3000)
,msgSub varchar (300)
)