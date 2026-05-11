part of 'package:desk_sdui_demo/screens/counter_minimal.dart';

ScreenBinding get counter_minimalBinding => ScreenBinding(
  name: 'counter_minimal',
  ir: IrTree(
    name: 'counter_minimal',
    version: 1,
    root: WidgetNode(
      name: 'Center',
      args: {
        'child': WidgetNode(
          name: 'Text',
          args: {
            'data': StringInterpNode([
              RefNode(['data', 'value']),
            ]),
            'style': WidgetNode(
              name: 'TextStyle',
              args: {
                'fontSize': ConstNode(96),
                'fontWeight': RefNode(['FontWeight', 'w800']),
              },
            ),
          },
        ),
      },
    ),
  ),
  inputs: [InputBinding(name: 'data', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
