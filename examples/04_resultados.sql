-- Unicode e diversos tipos de resultado, sem modificar tabelas persistentes.
PRINT N'Início do teste';
SELECT N'Nome, com vírgula' AS Nome,
       N'Texto com "aspas"' AS Observacao,
       CAST(NULL AS INT) AS SemValor,
       N'' AS TextoVazio,
       CAST(0x0001FF10 AS VARBINARY(4)) AS Binario;
SELECT REPLICATE(CAST(N'ação ' AS NVARCHAR(MAX)), 3000) AS TextoLongo;
GO
-- GO dentro de uma string não deve dividir o lote.
SELECT N'Primeira linha
GO
Terceira linha' AS TextoComGO;
GO
-- Repetição explícita de lote: dois conjuntos de resultado.
SELECT N'Lote repetido' AS Teste;
GO 2
-- Execute as linhas seguintes separadamente para testar erro e cancelamento.
-- SELECT * FROM dbo.SG_TabelaQueNaoExiste;
-- WAITFOR DELAY '00:00:20'; SELECT N'Terminou' AS Estado;
