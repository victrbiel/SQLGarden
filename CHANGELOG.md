# Histórico

## 0.4.0 — 28/10/2026

- Corrige entrada de aspas/acentos, leitura de resultados após DML vazio e estado de conexão perdida.
- Aviso sobre transações pendentes, preferência de senha persistida e painéis de arquivos assíncronos.
- Explorador agrupado por tipo/esquema com seletor de banco, busca e ações por objeto.
- Mantém correções anteriores e não altera autocomplete.


## 0.3.1 — 21/10/2026

- Preserva CRLF/CR e linhas originais ao reconhecer GO.
- Analisa delimitadores por escalares Unicode, inclusive junto a marcas combinantes.
- Rejeita NUL no documento inteiro antes de enviar qualquer lote e nos campos ODBC.
- Preserva NUL interno/final em resultados e entre blocos de leitura JSON/ODBC.
- Usa comprimento real em binários mesmo com SQL_SUCCESS_WITH_INFO.
- Move leitura, gravação e remoção do Chaves para fora da thread da interface.
- Expõe espera/digitação manual e invalida leituras duplicadas, antigas ou de outro perfil.
- Não sobrescreve arquivo externo ilegível e reconhece diferenças de bytes Unicode.
- Ignora respostas de metadados após desconectar e captura parâmetros da tentativa de conexão.
- Corrige orientação dos scripts de instalação: ficam no ZIP completo.
- Acrescenta regressões de integridade, Chaves e preservação de arquivos.


## 0.3.0 — 19/10/2026

- Recuperação local de abas, rascunhos, seleção e aba ativa; backup de geração anterior.
- Histórico pesquisável com contexto, duração e estado; exclusão e desativação.
- Editor com régua de linhas, busca/substituição, navegação, comentários e indentação.
- Grade com seleção de células, intervalos, cópia tabular, busca local e conteúdo longo.
- Contexto do servidor/banco e verificação explícita de SPID, transações e XACT_STATE.
- Feedback/bugs com diagnóstico técnico opcional, revisão editável, TXT e composição
  de e-mail para sqlgarden@publicvictor.com; nenhum envio automático.
- Preserva sessão compartilhada, GO, limites, erros parciais e cancelamento.
- Sem autocomplete, IA, modo estudo, edição inline ou novas sessões por aba.
- Distribuição universal e DMG visual com o fundo original.

## 0.2.0 — 19/10/2026

- Autoria e copyright corrigidos para Victor; licença MIT e documentação pública.
- Ícone e logo do kit original integrados, com logo clara/escura e Dock por aparência.
- App universal arm64/x86_64 e scripts de build/DMG reproduzíveis.
- Guia para instalação, dependências, servidor da faculdade e Express local opcional.
- Instaladores com confirmação local, senha silenciosa e preservação de dados existentes.
- Menu de aparência e guia dentro do app; aviso de dependências ausentes.
- Encerramento usa confirmação em sheet e não bloqueia o loop principal.
- Consulta inicial gerada não é tratada como alteração pessoal não salva.
- Provisionamento específico do Mac de desenvolvimento removido da distribuição.

## 0.1.0

Primeira implementação nativa e validação do cliente SQL Server no Mac.
