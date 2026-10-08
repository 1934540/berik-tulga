# Установка «Берік Тұлға» на iPhone

Это Flutter-проект с iOS-частью, рассчитанной на iOS 15+. Шагомер использует Apple Core Motion (`CMPedometer`), карта и история работают локально. Разрешения на движение, геолокацию и background location включены. Поддержка iOS в исходниках не означает, что сборка на устройстве уже проверена: текущий компьютер работает под Windows, готового подписанного `.ipa` пока нет.

## Запуск на своём iPhone с Mac

1. Распакуйте `berik-tulga-ios-source.zip` на Mac. Установите Xcode с iOS SDK и Flutter, совместимый с ограничением Dart в `pubspec.yaml` (в текущем Windows-проекте Flutter 3.47.6 / Dart 3.13.5).
2. В Terminal перейдите в распакованный `berik-tulga-ios` и выполните `bash scripts/ios.sh prepare`. Скрипт получает зависимости, генерирует конфигурацию для Mac и открывает `ios/Runner.xcworkspace`.
3. В Xcode → Runner → Signing & Capabilities выберите свою Team и включите Automatically manage signing. Текущий Bundle Identifier — `kz.beriktulga.berikTulga`; если он занят, задайте уникальный идентификатор своего приложения. Apple Account добавляется в настройках Xcode, пароль не записывается в проект.
4. Подключите iPhone, подтвердите доверие компьютеру и включите Developer Mode, если устройство этого требует. Выберите iPhone в Xcode и запустите Runner. Для запуска с личным Apple Account используйте этот способ установки; TestFlight требует учётную запись Apple Developer Program.
5. Разрешите доступ к геолокации и «Движение и фитнес». Запустите реальную прогулку в офлайн-режиме. Шагомер нельзя проверить в iOS Simulator — нужен iPhone.

Для повторного запуска из Terminal получите ID через `flutter devices` и выполните `bash scripts/ios.sh device <ID>`. `bash scripts/ios.sh check` проверяет анализатор, Dart-тесты и компиляцию iOS без подписи; такой неподписанный результат не устанавливается на iPhone.

## TestFlight без личного Mac

Сборку может выполнить доступный Mac или облачный macOS runner. Для доставки через TestFlight нужны Apple Developer Program, запись приложения в App Store Connect и настроенная подпись. На Mac после настройки Team выполните `bash scripts/ios.sh ipa app-store`; архив и IPA появятся в `build/ios/archive` и `build/ios/ipa`. Загружайте архив через Xcode Organizer или IPA через Transporter, затем назначьте сборку для тестирования в App Store Connect. Скрипт самостоятельно ничего не публикует.

## Windows, без Mac и без подписки Apple Developer

Предусмотрен другой путь: GitHub Actions компилирует приложение на облачном macOS runner без Apple-подписи; Sideloadly на Windows подписывает готовый IPA обычным Apple ID и устанавливает его на подключённый iPhone. Создана конфигурация `.github/workflows/iphone.yml`. Она запускается только вручную, использует Flutter 3.47.6, выполняет анализатор и тесты, затем `bash scripts/ios.sh sideload` создаёт IPA с `Payload/Runner.app` и SHA-256. Apple ID, сертификаты и пароли в облачной сборке не нужны.

1. Разместите исходники и workflow в своём закрытом GitHub-репозитории. Проверьте доступный лимит GitHub Actions: macOS runner в приватном репозитории расходует минуты аккаунта; если бесплатного лимита не хватает, сборку не запускайте с платным перерасходом без отдельного решения.
2. Откройте Actions → Build iPhone IPA → Run workflow. После успешного запуска скачайте артефакт `berik-tulga-iphone` и извлеките `berik-tulga-unsigned.ipa`.
3. Установите [Sideloadly с официального сайта](https://sideloadly.io/). Выполните требования его Windows-инструкции к iTunes/iCloud и подключите iPhone по USB, подтвердив доверие компьютеру.
4. Добавьте наш IPA в Sideloadly, выберите iPhone и подпишите своим Apple ID. Apple ID и пароль вводятся в программе установки на вашем компьютере; проект и GitHub workflow их не запрашивают.
5. При необходимости подтвердите доверие профилю в настройках iPhone и включите Developer Mode. Запустите «Берік Тұлға», разрешите движение и геолокацию, проверьте прогулку.

[По FAQ Sideloadly](https://sideloadly.io/faq.html), обычный бесплатный Apple ID даёт подпись на 7 дней; её нужно регулярно обновлять, вручную или функцией auto-refresh. При обновлении используйте тот же Apple ID и Bundle ID, устанавливая поверх приложения, чтобы сохранить локальную историю. Этот способ пока не проверен на физическом iPhone; готового IPA ещё нет, пока облачная сборка не выполнена.

Исходники пока не отправлены в GitHub: нужно согласовать размещение проекта в подключённом аккаунте и запуск сборки. Подготовка workflow сама по себе не означает, что iOS успешно скомпилирован.

Исходный ZIP не является устанавливаемым приложением. Для получения готового iPhone-приложения остаются компиляция на macOS, подпись и проверка на физическом устройстве.

Официальные инструкции: [Flutter — сборка iOS](https://docs.flutter.dev/deployment/ios), [Apple — запуск на устройстве](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices), [Apple — TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).
