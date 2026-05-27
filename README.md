# desk_sdui

Server-driven UI for Flutter. Author screens as `@Screen` Dart-subset, ship layouts as data, render on device by composing registered native widgets.

This is a melos workspace with three packages:

- **`desk_sdui_annotation`** — `@Screen` annotation and IR types. Pure Dart.
- **`desk_sdui`** — runtime that renders IR into a Flutter widget tree.
- **`desk_sdui_generator`** — `build_runner` codegen + analyzer plugin.

Design spec: see `dart_desk/docs/superpowers/specs/2026-05-10-desk-sdui-design.md` in the sibling `dart_desk` repo.

## Status

Currently highly capable of rendering full-fledged interactive UIs driven entirely by an Server-Driven JSON payload.

## Demo

![Demo Video](assets/demo.mp4)

## Language feature support

`desk_sdui` parses your `@Screen` Dart code and converts it into a safe, executable JSON payload. The following Dart language features are natively supported inside the UI sandbox:

| Feature | Support level | Description |
| :--- | :---: | :--- |
| **Flutter Widgets** | ✅ | Compiles directly to native Flutter widgets. No webviews or HTML rendering. |
| **Functions & Methods** | ✅ | Native method calls on view models or registered functions. |
| **Closures / Callbacks** | ✅ | Full support for lambdas, closures, and local state bindings. |
| **Classes & Mixins** | ✅ | Send entire custom Classes, Mixins, and Extensions over the wire. Manage `this` securely. |
| **If statements** | ✅ | Includes ternary operators (`?:`) and null coalescing (`??`). |
| **Loops** | ✅ | Supports `for`, `while`, `do-while`, `break`, and `continue`. |
| **Try-catch** | ✅ | Native error handling with `tryStep`. |
| **Collections** | ✅ | Native handling of Lists, Maps, Records, and spread operators (`...`). |
| **Type tests** | ✅ | Full support for `is`, `as`, and `runtimeType` checks. |
| **String interpolation** | ✅ | Fully supported. |
| **Raw String Evaluation** | ❌ | Intentionally unsupported. You cannot pass a raw Dart string (e.g. `"print(1);"`) and execute it at runtime. |

## Comparison: `desk_sdui` vs `genui` (Official Flutter Labs Package)

While both packages enable Server-Driven / Generative UI, they take fundamentally different architectural approaches.

| Aspect | `desk_sdui` | `genui` (labs.flutter.dev) |
| :--- | :--- | :--- |
| **Registration** | Expose standard Flutter widgets or functions to the backend simply by adding a `@Register` annotation. | Requires wrapping UI components inside specific `CatalogItem` definitions. |
| **What you write** | Developers (or AI agents) write **real, perfectly-typed Dart code** (`@Screen` classes). This code can contain full UI layouts, loops, state, and business logic. | Developers write tool definitions. The LLM is restricted to providing simple data arguments to those pre-compiled tools. |
| **How JSON is generated** | The AI agent writes standard Dart code on the server. The `build_runner` automatically compiles that Dart code into the JSON payload. | The AI agent generates the JSON directly (conforming to a2ui schemas) to trigger the tool on the client. |
