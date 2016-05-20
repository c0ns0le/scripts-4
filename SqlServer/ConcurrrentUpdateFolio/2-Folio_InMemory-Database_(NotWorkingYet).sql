/* Setup */
if DB_ID('Folio_InMemory') IS NULL
	CREATE DATABASE Folio_InMemory
	 CONTAINMENT = NONE
	 ON  PRIMARY 
	( NAME = N'Folio_InMemory', FILENAME = N'C:\SqlData\Folio_InMemory.mdf' , SIZE = 5120KB , FILEGROWTH = 1024KB )
	 LOG ON 
	( NAME = N'Folio_InMemory_log', FILENAME = N'C:\SqlData\Folio_InMemory_log.ldf' , SIZE = 2048KB , FILEGROWTH = 10%)

	/*
	CREATE DATABASE Folio_InMemory
	ON
	PRIMARY (NAME = Folio_InMemory_Data,  FILENAME = 'c:\data\MemoryOptimizedTableDemoDB_data.mdf', SIZE = 1024MB), 
	FILEGROUP Folio_InMemory_MOTdata 
		CONTAINS MEMORY_OPTIMIZED_DATA
		(NAME = Folio_InMemory_folder1, FILENAME = 'c:\data\MemoryOptimizedTableDemoDB_folder1'), 
		(NAME = Folio_InMemory_folder2, FILENAME = 'c:\data\MemoryOptimizedTableDemoDB_folder2') 
	LOG ON (NAME = Folio_InMemory_log, FILENAME = 'C:\log\MemoryOptimizedTableDemoDB_log.ldf', SIZE = 500MB);
	GO
	*/
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
GO
USE [Folio_InMemory]
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') 
	ALTER DATABASE [Folio_InMemory] MODIFY FILEGROUP [PRIMARY] DEFAULT
GO

if OBJECT_ID('folio') IS NOT NULL
    drop table folio;
go
 
create table folio
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
go

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
	UPDATE TOP(1) folio
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

--EXEC Folio_Stress 1000
GO
SELECT lastnumber, seconds, cast(lastnumber/seconds as int) as updates_per_sec, seconds/lastnumber AS average_msec_row, dt_first_updated, dt_last_updated FROM (SELECT lastnumber, seconds = DATEDIFF(millisecond, dt_first_updated, dt_last_updated)/1000.0, dt_first_updated, dt_last_updated FROM folio) a

