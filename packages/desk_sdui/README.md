# desk_sdui

Runtime that renders desk_sdui IR into a Flutter widget tree.

## Input contract

`SduiScreen.inputs` accepts `Map<String, Object?>`. Map keys are the Dart field
names referenced inside your `@Screen` function body. Values may be primitives,
nested maps, lists, or computed-on-access functions (see `__getters__` below).

If your domain models already produce JSON-shaped maps (via `freezed`,
`dart_mappable`, `json_serializable`, or hand-rolled `toJson` methods), pass the
output of those directly:

    SduiScreen(name: 'chef', runtime: rt, inputs: {'data': chefData.toJson()})

### Key naming

Map keys must match the Dart field names your `@Screen` references. If your
serializer renames keys (e.g. `@JsonKey(name: 'chef_name')` → snake_case),
adapt at the call site:

    SduiScreen(
      name: 'chef',
      runtime: rt,
      inputs: {
        'data': chefData.toJson().map(
          (k, v) => MapEntry(_camelCase(k), v),
        ),
      },
    )

### Lazy / computed fields

For expensive fields you don't want to eagerly serialize, use the `__getters__`
escape hatch:

    SduiScreen(
      name: 'chef',
      runtime: rt,
      inputs: {
        'data': {
          'headline': chefData.headline,
          'dishes': chefData.dishes.map((d) => d.toJson()).toList(),
          '__getters__': {
            'expensiveStats': () => chefData.computeStats(),
          },
        },
      },
    )

## Registering widgets

desk_sdui uses an **explicit-registration** model: the widgets available to
network-driven screens are exactly the ones you list in `@Register`.
At build time the generator checks every `@Screen` body and **fails the build**
if it references a widget that isn't listed — so gaps are caught at compile time,
not at runtime when a remote payload arrives.

### Common case — drop in the bundles

`package:desk_sdui/widget_bundles.dart` ships three curated lists:

| Constant | Source | What's inside |
|---|---|---|
| `kCommonWidgets` | `flutter/widgets.dart` | Align, Column, Container, Row, Stack, Text, … |
| `kCommonMaterialWidgets` | `flutter/material.dart` | AppBar, Card, ElevatedButton, Scaffold, … |
| `kCommonCupertinoWidgets` | `flutter/cupertino.dart` | CupertinoButton, CupertinoPageScaffold, … |

Spread one or more bundles into a `@Register` annotation on any class in
your package (typically a dedicated `sdui_coverage.dart` file):

```dart
import 'package:desk_sdui/widget_bundles.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@Register([...kCommonWidgets, ...kCommonMaterialWidgets])
class _Core {}
```

### Third-party design systems

If your screens use components from a design system like `shadcn_ui`, list them
alongside the bundles:

```dart
@Register([
  ...kCommonWidgets,
  ShadButton, ShadCard, ShadInput, ShadSelect,
])
class _ShadcnRegistrations {}
```

### What happens if you forget

If a `@Screen` body references a widget not covered by any `@Register`
annotation, `dart run build_runner build` fails with a clear error:

```
E desk_sdui_generator:registry_builder on $package$:
  Bad state: desk_sdui registration diagnostic failed.
  The following widget types are referenced in @Screen bodies but are not
  listed in any @Register annotation.
  Add them to a @Register list or import one of the bundles from
  package:desk_sdui/widget_bundles.dart.
    Screen "chef" references unregistered widget(s): Stack
```

Add the missing type to your `@Register` list and re-run the build.

For the full type list exported by each bundle, see the API documentation for
[`kCommonWidgets`](lib/widget_bundles.dart).
