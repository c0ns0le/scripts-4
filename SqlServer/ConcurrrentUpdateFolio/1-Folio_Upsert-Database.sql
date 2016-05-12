USE [master]
GO
IF DB_ID('Folio_InMemory') IS NOT NULL
BEGIN
	EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'Folio_InMemory'
	ALTER DATABASE [Folio_InMemory] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE [Folio_InMemory];
END
GO

/* Setup */
if DB_ID('Folio_InMemory') IS NULL
BEGIN
	CREATE DATABASE Folio_InMemory 
	-- BEGIN: RAMDisk
	CONTAINMENT = NONE ON
	PRIMARY (NAME = N'Folio_InMemory', FILENAME = N'R:\Folio_InMemory.mdf' , SIZE = 5120KB , FILEGROWTH = 1024KB)
	LOG ON  (NAME = N'Folio_InMemory_log', FILENAME = N'R:\Folio_InMemory_log.ldf' , SIZE = 2048KB , FILEGROWTH = 10%)
	-- END: RAMDisk

	ALTER DATABASE [Folio_InMemory] SET COMPATIBILITY_LEVEL = 120
	ALTER DATABASE [Folio_InMemory] SET ANSI_NULL_DEFAULT OFF 
	ALTER DATABASE [Folio_InMemory] SET ANSI_NULLS OFF 
	ALTER DATABASE [Folio_InMemory] SET ANSI_PADDING OFF 
	ALTER DATABASE [Folio_InMemory] SET ANSI_WARNINGS OFF 
	ALTER DATABASE [Folio_InMemory] SET ARITHABORT OFF 
	ALTER DATABASE [Folio_InMemory] SET AUTO_CLOSE OFF 
	ALTER DATABASE [Folio_InMemory] SET AUTO_SHRINK OFF 
	ALTER DATABASE [Folio_InMemory] SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF)
	ALTER DATABASE [Folio_InMemory] SET AUTO_UPDATE_STATISTICS ON 
	ALTER DATABASE [Folio_InMemory] SET CURSOR_CLOSE_ON_COMMIT OFF 
	ALTER DATABASE [Folio_InMemory] SET CURSOR_DEFAULT  GLOBAL 
	ALTER DATABASE [Folio_InMemory] SET CONCAT_NULL_YIELDS_NULL OFF 
	ALTER DATABASE [Folio_InMemory] SET NUMERIC_ROUNDABORT OFF 
	ALTER DATABASE [Folio_InMemory] SET QUOTED_IDENTIFIER OFF 
	ALTER DATABASE [Folio_InMemory] SET RECURSIVE_TRIGGERS OFF 
	ALTER DATABASE [Folio_InMemory] SET  DISABLE_BROKER 
	ALTER DATABASE [Folio_InMemory] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
	ALTER DATABASE [Folio_InMemory] SET DATE_CORRELATION_OPTIMIZATION OFF 
	ALTER DATABASE [Folio_InMemory] SET PARAMETERIZATION SIMPLE 
	ALTER DATABASE [Folio_InMemory] SET READ_COMMITTED_SNAPSHOT OFF 
	ALTER DATABASE [Folio_InMemory] SET  READ_WRITE 
	ALTER DATABASE [Folio_InMemory] SET RECOVERY SIMPLE 
	ALTER DATABASE [Folio_InMemory] SET  MULTI_USER 
	ALTER DATABASE [Folio_InMemory] SET PAGE_VERIFY CHECKSUM  
	ALTER DATABASE [Folio_InMemory] SET TARGET_RECOVERY_TIME = 0 SECONDS 
	ALTER DATABASE [Folio_InMemory] SET DELAYED_DURABILITY = DISABLED 
END
GO
USE Folio_InMemory
GO

if OBJECT_ID('folio') IS NOT NULL
    DROP TABLE folio;
go
CREATE TABLE folio
(
    id int,
    name varchar(30),
    lastnumber int,
	dt_first_updated datetime,
	dt_last_updated datetime,
	--
    primary key (id),
    unique (name)
);
GO

SET NOCOUNT ON
INSERT INTO folio (id, name, lastnumber) VALUES (1, 'Customer 1', 0);
SET NOCOUNT OFF
GO

if OBJECT_ID('Folio_Next') IS NOT NULL
	drop procedure Folio_Next;
GO
CREATE PROCEDURE Folio_Next(@id int, @nextnumber int OUTPUT)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @myfolio table (nextnumber int NOT NULL);

	--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
	UPDATE folio
		SET lastnumber = lastnumber + 1,
			dt_first_updated = IsNull(dt_first_updated, GetDate()),
			dt_last_updated = GetDate()
			OUTPUT inserted.lastnumber INTO @myfolio
		FROM folio 
		WHERE id = @id;

	SELECT @nextnumber = nextnumber FROM @myfolio
END
GO

if OBJECT_ID('Folio_Stress') IS NOT NULL
	drop procedure Folio_Stress;
GO
CREATE PROCEDURE Folio_Stress(@iterations int = 10)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @i int = 0;
	DECLARE @nextnumber int;

	WHILE @i < @iterations
	BEGIN
		SET @i += 1;
		EXEC Folio_Next 1, @nextnumber OUTPUT
	END
	Print 'Last Next Number: '+Convert(varchar(20), @nextnumber)
END
GO

--EXEC Folio_Stress 5000
GO
SELECT lastnumber, seconds, cast(lastnumber/seconds as int) as updates_per_sec, seconds/lastnumber AS average_msec_row, dt_first_updated, dt_last_updated FROM (SELECT lastnumber, seconds = DATEDIFF(millisecond, dt_first_updated, dt_last_updated)/1000.0, dt_first_updated, dt_last_updated FROM folio) a
