-- Leitura apenas. Pode executar no banco master ou no banco da aula.
SELECT @@VERSION AS VersaoCompleta,
       SERVERPROPERTY('Edition') AS Edicao,
       SERVERPROPERTY('ProductVersion') AS Versao;
GO
SELECT DB_NAME() AS BancoAtual, SUSER_SNAME() AS Usuario,
       @@SPID AS SessaoDoEditor;
GO
PRINT N'Conexão com SQLGarden funcionando.';
SELECT N'ação, coração e São Paulo 🎓' AS Unicode,
       CAST(NULL AS NVARCHAR(20)) AS ValorNull,
       N'' AS TextoVazio,
       N'NULL' AS TextoLiteral;
