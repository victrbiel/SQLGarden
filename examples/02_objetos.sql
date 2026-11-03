-- Execute somente numa base exclusiva de teste que você criou e selecionou.
-- Não cria nem troca automaticamente o banco e não remove objetos existentes.
-- Há proteções para não executar em master/model/msdb/tempdb.
-- Se algum nome já existir, a execução é interrompida antes de criar objetos.
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50000, N'Selecione uma base exclusiva de teste antes de executar.', 1;
IF OBJECT_ID(N'dbo.SG_Produto') IS NOT NULL
   OR OBJECT_ID(N'dbo.SG_Auditoria') IS NOT NULL
   OR OBJECT_ID(N'dbo.SG_ProdutosResumo') IS NOT NULL
   OR OBJECT_ID(N'dbo.SG_CadastrarProduto') IS NOT NULL
   OR OBJECT_ID(N'dbo.SG_AuditarPreco') IS NOT NULL
    THROW 50001, N'Já existem objetos SG_ nesta base. Use outra base exclusiva de teste.', 1;
GO
CREATE TABLE dbo.SG_Produto (
    Codigo INT IDENTITY(1,1) PRIMARY KEY,
    Nome NVARCHAR(100) NOT NULL,
    Preco DECIMAL(10,2) NOT NULL
);
CREATE TABLE dbo.SG_Auditoria (
    Codigo INT IDENTITY(1,1) PRIMARY KEY,
    ProdutoCodigo INT NOT NULL,
    PrecoAnterior DECIMAL(10,2) NOT NULL,
    PrecoNovo DECIMAL(10,2) NOT NULL,
    DataAlteracao DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO
CREATE VIEW dbo.SG_ProdutosResumo AS
    SELECT Codigo, Nome, Preco FROM dbo.SG_Produto;
GO
CREATE PROCEDURE dbo.SG_CadastrarProduto
    @Nome NVARCHAR(100), @Preco DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.SG_Produto (Nome, Preco) VALUES (@Nome, @Preco);
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS CodigoCriado;
END;
GO
CREATE TRIGGER dbo.SG_AuditarPreco
ON dbo.SG_Produto AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.SG_Auditoria (ProdutoCodigo, PrecoAnterior, PrecoNovo)
    SELECT i.Codigo, d.Preco, i.Preco
    FROM inserted AS i
    JOIN deleted AS d ON d.Codigo = i.Codigo
    WHERE i.Preco <> d.Preco;
END;
GO
EXEC dbo.SG_CadastrarProduto @Nome=N'Caderno de programação', @Preco=25.00;
UPDATE dbo.SG_Produto SET Preco=30.00 WHERE Codigo=1;
SELECT * FROM dbo.SG_ProdutosResumo;
SELECT * FROM dbo.SG_Auditoria;
PRINT N'Atualize o explorador para ver os objetos SG_.';
