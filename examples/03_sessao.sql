-- Pode executar em master: a única tabela criada é temporária, na sessão.
-- Execute o bloco inteiro. Depois execute separadamente os SELECTs finais.
CREATE TABLE #SG_Sessao (Codigo INT, Texto NVARCHAR(100));
INSERT INTO #SG_Sessao VALUES (1, N'Primeiro lote');
GO
INSERT INTO #SG_Sessao VALUES (2, N'Segundo lote, mesma sessão');
GO
BEGIN TRANSACTION;
UPDATE #SG_Sessao SET Texto=N'Alteração que será desfeita' WHERE Codigo=1;
SELECT N'Durante a transação' AS Etapa, * FROM #SG_Sessao;
ROLLBACK;
GO
SELECT N'Após ROLLBACK' AS Etapa, * FROM #SG_Sessao;
SELECT @@SPID AS MesmaSessao, @@TRANCOUNT AS TransacoesAbertas;
-- A tabela permanece disponível entre execuções até desconectar.
-- Para remover apenas a tabela temporária: DROP TABLE #SG_Sessao;
