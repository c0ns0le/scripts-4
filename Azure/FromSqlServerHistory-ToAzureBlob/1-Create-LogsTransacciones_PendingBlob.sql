/*
SELECT COUNT(*) FROM Historial.LogsTransacciones
--DEV: 4,657
--TEST: 156,350 [6 sec. locally | 24 sec. azure-test]
--PROD: 1,860,848 [20 sec. locally | 217 sec. azure-test]

--DROP TABLE Historial.LogsTransacciones_PendingBlob
DROP TABLE dbo.LogsTransacciones_PendingBlob
*/
PRINT '[' + CAST(CONVERT(Time, GetDate()) AS varchar)+'] ' + 'Started'
GO

IF OBJECT_ID('dbo.LogsTransacciones_PendingBlob') IS NULL
BEGIN
	CREATE TABLE dbo.LogsTransacciones_PendingBlob (id_LogTransaccion bigint NOT NULL PRIMARY KEY);

	--TODO: Change Manually ******************
	DECLARE @min int = 1, @max int = 156350;

	--DECLARE @lastID int, @batchSize int = 100
	--SELECT @lastID = IsNull(Max(id_LogTransaccion), 0) FROM Historial.LogsTransacciones_PendingBlob;
	--
	--PRINT '[' + CAST(CONVERT(Time, GetDate()) AS varchar)+'] ' + 'Getting Stats'
	--DECLARE @min int, @max int;
	--SELECT @min = MIN(id_LogTransaccion), @max = MAX(id_LogTransaccion) FROM Historial.LogsTransacciones;
	

	DECLARE @rows int = @max - @min + 1;
	PRINT '[' + CAST(CONVERT(Time, GetDate()) AS varchar)+'] ' + 'Min: '+CAST(@min AS varchar)+', Max: '+CAST(@max AS varchar)


	PRINT '[' + CAST(CONVERT(Time, GetDate()) AS varchar)+'] ' + 'Tabla: Historial.LogsTransacciones_PendingBlob'
	;WITH x AS 
	(
	  SELECT TOP (10000) [object_id] FROM sys.all_objects
	)
	INSERT INTO dbo.LogsTransacciones_PendingBlob (id_LogTransaccion)
		SELECT TOP (@rows) 
				n = ROW_NUMBER() OVER (ORDER BY x.[object_id]) + @min - 1
			FROM x CROSS JOIN x AS y
			ORDER BY n;
END
GO

--Done
PRINT '['+CAST(CONVERT(Time, GetDate()) AS varchar)+'] ' + 'Completado'


