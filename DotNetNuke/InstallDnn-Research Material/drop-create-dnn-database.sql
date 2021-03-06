SET NOCOUNT ON
GO
USE master
GO
-- DROP
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'dnn800'
GO
ALTER DATABASE [dnn800] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE [dnn800]
GO

-- CREATE
SET NOCOUNT ON
GO
CREATE DATABASE [dnn800]
 CONTAINMENT = NONE
 ON  PRIMARY ( NAME = N'dnn800', FILENAME = N'C:\SqlData\dnn800.mdf' , SIZE = 5120KB , FILEGROWTH = 1024KB )
 LOG ON ( NAME = N'dnn800_log', FILENAME = N'C:\SqlData\dnn800_log.ldf' , SIZE = 2048KB , FILEGROWTH = 10%)
GO
--ALTER DATABASE [dnn800] SET COMPATIBILITY_LEVEL = 120
GO
ALTER DATABASE [dnn800] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [dnn800] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [dnn800] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [dnn800] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [dnn800] SET ARITHABORT OFF 
GO
ALTER DATABASE [dnn800] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [dnn800] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [dnn800] SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF)
GO
ALTER DATABASE [dnn800] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [dnn800] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [dnn800] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [dnn800] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [dnn800] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [dnn800] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [dnn800] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [dnn800] SET  DISABLE_BROKER 
GO
ALTER DATABASE [dnn800] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [dnn800] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [dnn800] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [dnn800] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [dnn800] SET  READ_WRITE 
GO
ALTER DATABASE [dnn800] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [dnn800] SET  MULTI_USER 
GO
ALTER DATABASE [dnn800] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [dnn800] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
ALTER DATABASE [dnn800] SET DELAYED_DURABILITY = DISABLED 
GO
USE [dnn800]
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [dnn800] MODIFY FILEGROUP [PRIMARY] DEFAULT
GO

USE master
GO