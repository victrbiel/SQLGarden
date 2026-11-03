# Contribuir com SQLGarden

Autoria: Victor. Licença: MIT. Preserve os créditos e as artes do kit visual.

1. Trabalhe numa cópia/branch e mantenha SwiftUI/AppKit e T-SQL real.
2. Rode `bash scripts/test.sh`. Para a distribuição, gere o app universal e o DMG.
3. Para testar SQL real, use uma base exclusiva `SQLGarden_Validacao_…` nova.
   Não faça testes de criação/exclusão em bancos de aula ou pessoais.
4. Preserve sessão, GO, Unicode, NULL, erros parciais, cancelamento e ausência de retry.
5. Não coloque senhas em código, logs, arquivos SQL, .env ou issues. O app usa Chaves.
6. Inspecione logos e ícones em claro/escuro e confira recursos dentro do bundle.
7. Registre exatamente arquitetura/macOS/testes executados. Compilação cruzada
   e execução sob tradução não comprovam execução física em Intel.
8. Não altere containers/volumes existentes para corrigir um teste. Preserve seus dados.

O script opcional de Express pede consentimento e uma senha local ao usuário.
Não acrescente credenciais padrão, telemetria, instalação silenciosa ou exclusão
automática de dados. Ao reportar falhas, use exemplos mínimos sem dados pessoais.

Para distribuir publicamente com Developer ID/notarização, o mantenedor precisa
de sua própria conta/certificado Apple e deve validar assinatura e carregamento
das bibliotecas externas. Não publique o pacote ad hoc como se fosse notarizado.
