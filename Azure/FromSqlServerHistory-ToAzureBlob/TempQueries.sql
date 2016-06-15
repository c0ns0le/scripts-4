--SELECT COUNT(*) FROM Historial.LogsTransacciones
--DEV: 4,657
--TEST: 156,350 [6 sec. locally | 24 sec. azure-test]
--PROD: 1,860,848 [20 sec. locally | 217 sec. azure-test]

--USE RepExt_Trunk_APP
--GO
--SELECT TOP 1 id_LogTransaccion, ds_MensajeEntrada, dt_Creado FROM Historial.LogsTransacciones WHERE ds_MensajeEntrada IS NOT NULL
SELECT TOP 1 * FROM Historial.LogsTransacciones
SELECT TOP 1 * FROM Historial.LogsTransacciones_PendingBlob WITH (NOLOCK)

/*
BEGIN TRANSACTION
SET ROWCOUNT 1
DELETE Historial.LogsTransacciones_PendingBlob WITH (READPAST, READCOMMITTEDLOCK)
	OUTPUT deleted.id_LogTransaccion
SET ROWCOUNT 0
COMMIT
*/

--SELECT COUNT(*) FROM Historial.LogsTransacciones
--4657

--SELECT TOP 1 * FROM Historial.LogsTransacciones WHERE ds_MensajeEntrada IS NOT NULL

DECLARE @min int, @max int;
SELECT @min = MIN(id_LogTransaccion), @max = MAX(id_LogTransaccion) FROM Historial.LogsTransacciones;



/*
	INSERT INTO Historial.LogsTransacciones_PendingBlob (id_LogTransaccion)
	SELECT id_LogTransaccion 
		FROM Historial.LogsTransacciones
		WHERE id_LogTransaccion BETWEEN @lastID+1 AND @lastID + @batchSize
			AND (ds_MensajeEntrada IS NOT NULL OR ds_MensajeSalida IS NOT NULL)


*/