# Identidade visual Vanguard

## Imagem

- Caminho original encontrado: `Vanguard/Patch-Vanguard.png`
- Extensao: `.png`
- Dimensoes originais: `256x256`
- Transparencia: sim, `Format32bppArgb`
- Hash SHA-256 original: `F61CE872882469067249E26C6DC7BD18D069A62BD015333A5FF75B35F4B1610A`
- Caminho definitivo da copia: `assets/logos/patch_vanguard.png`
- Hash SHA-256 da copia: `F61CE872882469067249E26C6DC7BD18D069A62BD015333A5FF75B35F4B1610A`

## Variante para icones

Foi criada a variante `assets/logos/patch_vanguard_icon.png`.

Motivo: a arte opaca do arquivo original ocupa `231x231` dentro de `256x256`, com margem aproximada de 12-13 px. Para reduzir risco de corte em launcher icons e icones maskable, a variante usa canvas `512x512`, logo centralizado e margem transparente.

## Flutter

- `lib/main.dart`: `MaterialApp.title` alterado para `Vanguard`.
- `lib/screens/login.dart`: imagem antiga `assets/logos/logo.jpg` substituida por `assets/logos/patch_vanguard.png`, com `fit: BoxFit.contain`.
- `lib/screens/register.dart`: a mesma imagem da tela de autenticacao foi alinhada para `assets/logos/patch_vanguard.png`, com `fit: BoxFit.contain`.
- `pubspec.yaml`: nao alterado; `assets/logos/` ja estava declarado.

## Android

- `android/app/src/main/AndroidManifest.xml`: `android:label` alterado para `Vanguard`.
- `applicationId`, `namespace`, package e `MainActivity` foram preservados.
- O projeto nao possuia configuracao de `flutter_launcher_icons` em `pubspec.yaml` ou `pubspec.lock`.
- Os launcher icons foram gerados a partir de `assets/logos/patch_vanguard_icon.png`.

Arquivos atualizados:

- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (`48x48`)
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (`72x72`)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (`96x96`)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (`144x144`)
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (`192x192`)

## Web

- `web/index.html`: `title`, `description` e `apple-mobile-web-app-title` alterados para `Vanguard`.
- `web/manifest.json`: `name`, `short_name` e `description` alterados para `Vanguard`; demais propriedades preservadas.

Arquivos de icone atualizados:

- `web/favicon.png` (`32x32`)
- `web/icons/Icon-192.png` (`192x192`)
- `web/icons/Icon-512.png` (`512x512`)
- `web/icons/Icon-maskable-192.png` (`192x192`)
- `web/icons/Icon-maskable-512.png` (`512x512`)

## Plataformas

O projeto possui suporte ativo a Android e Web. Nao foram encontrados diretorios `ios`, `windows`, `linux` ou `macos`.

## Comandos executados

- `git status --short`
- Inspecoes de arquivos e imagem com PowerShell
- `dart format lib\main.dart lib\screens\login.dart lib\screens\register.dart`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build web`
- `git diff --check`
- `git status --short`
- `rg -n "Vanguard/|Patch-Vanguard|firebased" lib pubspec.yaml android web`

## Resultados

- `flutter pub get`: sucesso.
- `flutter analyze`: falhou com 64 issues de lint/configuracao existentes, principalmente dependencias runtime declaradas em `dev_dependencies` e avisos de estilo. Nao foram corrigidos por estarem fora do escopo.
- `flutter test`: sucesso, todos os testes passaram.
- `flutter build apk --debug`: sucesso, APK gerado em `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build web`: sucesso, build gerado em `build/web`.
- `git diff --check`: sucesso.

## Cache de icone

Em Android, o launcher pode manter icones em cache. Para testar a troca visual, pode ser necessario executar:

```bash
flutter clean
flutter pub get
flutter run
```

Tambem pode ser necessario desinstalar a versao antiga do app, reinstalar ou reiniciar o launcher do dispositivo. O `applicationId` nao foi alterado para contornar cache.

## Confirmacoes

- `Vanguard/Patch-Vanguard.png` continua existindo.
- O arquivo original nao foi alterado; a copia definitiva tem o mesmo hash SHA-256.
- A pasta `Vanguard` nao foi removida.
- O app usa somente arquivos em `assets/logos/`, `android/` e `web/` para a identidade visual.
- A busca funcional por `Vanguard/|Patch-Vanguard` em `lib`, `pubspec.yaml`, `android` e `web` nao encontrou referencias.
- `firestore.rules` nao foi alterado nesta tarefa.
- `firebase.json` nao foi alterado nesta tarefa.
- `.env` nao foi alterado nesta tarefa.
- Nenhum deploy foi executado.
- Nenhum commit foi executado.
