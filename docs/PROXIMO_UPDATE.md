# Situação após 0.4.0

Os cinco itens da auditoria de aula foram tratados nesta versão.
Aspas/composição: destaque por atributos temporários e preservação de texto marcado.
Transporte: conexão invalidada sem repetir comandos.
Transações: aviso explícito sem SELECT/ROLLBACK escondidos.
CSV: sheets assíncronas, exportação pela interface conferida.
TRY/CATCH: SQL_NO_DATA inicial não encerra resultados posteriores; 19/19 casos passaram.

A auditoria original está preservada em AUDITORIA_0.3.1_AULA.md.
Limites de validação e evidências atuais estão em VALIDACAO_MAC.md.
