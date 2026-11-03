# SQLGarden — atualização visual

## Pedido para o Codex

Integre os arquivos deste pacote ao projeto existente do SQLGarden. Atualize o ícone do aplicativo e a logo utilizada dentro da interface, respeitando as variantes clara e escura. Preserve as funcionalidades, a conexão com SQL Server, a arquitetura e o layout atual, salvo os ajustes de tamanho necessários para acomodar a logo. Inspecione primeiro o projeto e use seu mecanismo real de build e recursos. Não recrie as artes e não acrescente efeitos por cima delas.

## Conteúdo

- `Icons/SQLGarden-Light-1024.png`: ícone claro, RGBA, 1024 × 1024.
- `Icons/SQLGarden-Dark-1024.png`: ícone escuro, RGBA, 1024 × 1024.
- `Icons/SQLGarden-Light.icns` e `SQLGarden-Dark.icns`: versões multirresolução para macOS.
- `Assets.xcassets/AppIcon.appiconset`: ícone claro nos tamanhos tradicionais do macOS.
- `Assets.xcassets/AppIconDark.appiconset`: alternativa escura nos mesmos tamanhos.
- `Assets.xcassets/SQLGardenLogo.imageset`: logo interna com variantes Any/Dark, em 1x, 2x e 3x. Any corresponde ao tema claro.
- `Logos/`: logos transparentes em resolução original, letras escuras para interface clara e letras claras para interface escura.
- `Preview-Light-Dark.png`: comparação visual; não utilizar como recurso na interface.
- `Reference/`: logo beta original fornecida pelo usuário, apenas como referência.

## Integração no Xcode

1. Faça a integração no catálogo existente; não sobrescreva todo o `Assets.xcassets` do projeto. Mescle apenas os conjuntos pertinentes e remova referências antigas duplicadas.
2. Se o projeto usa catálogo tradicional de ícones, defina o conjunto `AppIcon` como ícone principal do target. A alternativa `AppIconDark` é um conjunto separado: sua existência NÃO ativa automaticamente a troca de aparência do ícone do sistema.
3. Se o projeto usa `.icns` via recursos/Info.plist, mantenha essa estratégia e use o arquivo claro como padrão persistente. Adicione o escuro como recurso quando necessário.
4. Se já existir uma integração com Icon Composer, preserve-a. Este pacote contém imagens rasterizadas, não um projeto `.icon` com camadas editáveis. Não renomeie PNGs para `.icon`, não invente arquivos de configuração e não aplique novamente vidro/sombra sobre a arte pronta. Para variantes nativas do sistema, valide no Xcode instalado o suporte do pipeline atual; uma integração que exija reconstruir camadas deve ser explicitamente reportada.
5. Para a logo interna, use `Image("SQLGardenLogo")`, preservando as cores originais e a proporção. O catálogo seleciona a variante escura conforme a aparência efetiva. Não utilize renderização `.template`, pois ela eliminaria os verdes.

Exemplo SwiftUI, ajustando a largura ao espaço disponível:

```swift
Image("SQLGardenLogo")
    .renderingMode(.original)
    .resizable()
    .scaledToFit()
    .frame(maxWidth: 280)
    .accessibilityLabel("SQLGarden")
```

As logos têm proporção 3:1, fundo transparente e margem própria. Não adicionar uma placa branca atrás da logo na interface escura. Não cortar a arte com `.scaledToFill()`.

## Troca claro/escuro do ícone

A troca da logo interna e a troca do ícone do aplicativo são mecanismos diferentes. Os dois `.icns` e os dois appiconsets são alternativas visuais completas; não são, por si só, um ícone nativo com aparências automáticas.

Implemente a troca usando a solução compatível com o projeto e o macOS alvo. Se for adotado `NSApplication.shared.applicationIconImage` como alternativa, carregue o PNG/ICNS apropriado na inicialização e atualize ao mudar a aparência efetiva. Esse mecanismo afeta o ícone do aplicativo em execução/Dock; não equivale a substituir permanentemente o ícone do bundle no Finder. Mantenha o ícone claro corretamente configurado no bundle e informe essa diferença no resultado. Não modifique o próprio bundle instalado durante a execução.

## Design e limites

- Manter os verdes, o banco e o broto com duas folhas de vidro: traseira mais escura e frontal mais clara.
- A aparência Liquid Glass já está incorporada nos pixels; não há refração dinâmica nem camadas separadas neste pacote.
- Os PNGs de ícone têm margem transparente para uso macOS tradicional; não somar margem adicional automaticamente nem aplicar outra máscara arredondada.
- As variantes foram refinadas como imagens separadas; podem existir diferenças mínimas entre seus pixels. Não são vetores e não pressupõem fonte tipográfica instalada.
- Não usar a logo horizontal como ícone do Dock e não usar a placa arredondada como logo horizontal dentro do app.

## Verificação após integrar

Compile o target real. Verifique ícone no Dock/Finder e logo em interface clara e escura, inclusive durante alternância de tema. Confira tamanhos pequenos e Retina, ausência de distorção e inclusão dos recursos no bundle. Relate o que foi validado e eventuais limitações do pipeline de ícones. Os arquivos deste pacote foram conferidos visualmente e validados estruturalmente; a compilação do aplicativo depende do projeto local do usuário.

## Referências oficiais

- https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer
- https://developer.apple.com/documentation/xcode/configuring-your-app-icon
- https://help.apple.com/xcode/mac/current/en.lproj/dev7a4aebe73.html

As artes foram geradas/refinadas com geração de imagens; as versões de tamanho e os contêineres ICNS foram exportados a partir dos PNGs finais. Nenhum arquivo do aplicativo foi modificado neste pacote.
