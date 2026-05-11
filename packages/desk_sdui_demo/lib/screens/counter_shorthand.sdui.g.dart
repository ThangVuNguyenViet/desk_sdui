part of 'package:desk_sdui_demo/screens/counter_shorthand.dart';

ScreenBinding get counter_shorthandBinding => ScreenBinding(
  name: 'counter_shorthand',
  ir: IrTree(
    name: 'counter_shorthand',
    version: 1,
    root: WidgetNode(
      name: 'Padding',
      args: {
        'padding': WidgetNode(
          name: 'EdgeInsets.all',
          args: {'arg0': ConstNode(16)},
        ),
        'child': WidgetNode(
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
      },
    ),
  ),
  inputs: [InputBinding(name: 'data', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
