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
