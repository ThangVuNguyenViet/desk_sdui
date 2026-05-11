part of 'package:desk_sdui_demo/screens/counter_record.dart';

ScreenBinding get counter_recordBinding => ScreenBinding(
  name: 'counter_record',
  ir: IrTree(
    name: 'counter_record',
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
  methods: const [],
  reactives: const [],
);
