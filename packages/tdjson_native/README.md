# tdjson_native

Тонкая обёртка `dart:ffi` над JSON-интерфейсом TDLib (`td_create_client_id`,
`td_send`, `td_receive`, `td_execute`) и упаковка нативной библиотеки:

- **Linux** — `prebuilt/linux/libtdjson.so` копируется в `bundle/lib`.
- **iOS** — `ios/Frameworks/tdjson.xcframework` встраивается через CocoaPods.

Обе сборки создаются скриптами из `scripts/` в корне репозитория.
