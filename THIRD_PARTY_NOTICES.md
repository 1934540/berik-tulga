# Карта, GPS и шагомер: источники

Зависимости Flutter сохраняют свои лицензии в реестре лицензий приложения. Ниже указаны проекты, использованные при доработке карты, GPS и шагомера.

## Pedometer / CARP Flutter plugins — MIT

- Репозиторий: https://github.com/carp-dk/flutter-plugins/tree/master/packages/pedometer (прежний адрес: `cph-cachet/flutter-plugins`).
- Подключена опубликованная версия `pedometer 4.2.0`; версия и SHA-256 пакета зафиксированы в `pubspec.lock`.
- Изучены Android `SensorStreamHandler.kt`, `SensorEventListenerFactory.kt` и iOS `PedometerPlugin.swift`. Пакет используется как зависимость без изменения его исходников: Android `TYPE_STEP_COUNTER`, iOS `CMPedometer`, подписка только на время прогулки.
- Наши `WalkStepCounter` и обработчик событий в контроллере вычитают начальное показание, сохраняют прирост, отбрасывают дубли и регрессии; Health-сводки больше не читаются.
- Оригинальная лицензия пакета: [Pedometer-MIT.txt](docs/licenses/Pedometer-MIT.txt).

## RootStep — MIT

- Репозиторий: https://github.com/Galimba03/rootstep
- Проверенный commit: `d12c34e72240998f69095935dff63de3b3084048`.
- Источник: `lib/screens/map_screen.dart`, `_setupLocation`.
- Адаптированы настройки Android LocationManager, foreground notification/wake lock и iOS fitness/background indicator в `lib/features/activity/data/tracking_services.dart`. Контроллер и UI проекта не копируются целиком.
- Полный текст исходной лицензии: [RootStep-MIT.txt](docs/licenses/RootStep-MIT.txt).

## RunFlutterRun — MIT

- Репозиторий: https://github.com/BenjaminCanape/RunFlutterRun
- Проверенный commit: `5b06027a75292e19b66c0b39a171ff2f1016c2e4`.
- Изучен `lib/presentation/common/location/view_model/location_view_model.dart`: отдельная подписка GPS, запись только при запущенной активности, отмена подписки и обновление камеры. Эти принципы применены в наших независимых Riverpod-контроллере и карте; исходный view model не включён.
- Исходная лицензия: [RunFlutterRun-MIT.txt](docs/licenses/RunFlutterRun-MIT.txt).

## MapLibre / OpenFreeMap / OpenStreetMap

Рендерер: [`maplibre_gl`](https://github.com/maplibre/flutter-maplibre-gl), BSD-3-Clause. Начиная с 0.1.1, карта — встроенная выгрузка [OpenStreetMap](https://www.openstreetmap.org/copyright) под ODbL 1.0. Данные, исходный запрос, координаты области, дата и контрольные суммы доступны в `assets/maps/kyzylorda.geojson` и `assets/maps/metadata.json`. Полный текст ODbL входит в APK: `assets/maps/LICENSE-ODbL.txt`. Производная база остаётся под ODbL. Наш картографический стиль находится в `assets/maps/style.json`. Атрибуция сохраняется в стандартной кнопке карты и панели слоёв.

Noto Sans Regular glyphs получены при подготовке APK с `https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf`; источник шрифта — [OpenMapTiles/fonts](https://github.com/openmaptiles/fonts/tree/master/noto-sans), SIL Open Font License 1.1. Лицензия сохранена в `docs/licenses/Noto-Sans-LICENSE.txt` и `assets/maps/LICENSE-Noto-Sans.txt`. В процессе использования приложение читает карту и glyphs локально, не запрашивает область у провайдера тайлов.

Выгрузка воспроизводится `python tools/build_offline_map.py --get`; для повторной конвертации без сети — `--input artifacts/kyzylorda-overpass.json`. Скрипт также предусматривает кэшируемый fallback к Map API. Сеть нужна только автору при подготовке нового набора данных, не пользователю APK.

Для веб-превью включён MapLibre GL JS 6.4.1 из официального npm-пакета `maplibre-gl`: модуль, shared-модуль, worker и CSS в `web/vendor/maplibre/`. Оригинальная лицензия BSD-3-Clause и уведомления о стороннем коде находятся рядом в `LICENSE.txt`. Превью не загружает движок из CDN.
