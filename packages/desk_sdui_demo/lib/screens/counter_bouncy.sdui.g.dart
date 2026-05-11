part of 'package:desk_sdui_demo/screens/counter_bouncy.dart';

ScreenBinding get counter_bouncyBinding => ScreenBinding(
  name: 'counter_bouncy',
  ir: IrTree(
    name: 'counter_bouncy',
    version: 1,
    root: WidgetNode(
      name: 'Center',
      args: {
        'child': WidgetNode(
          name: 'Cue.onChange',
          args: {
            'value': RefNode(['data', 'value']),
            'motion': WidgetNode(name: 'CueMotion.bouncy', args: {}),
            'acts': ListNode([
              WidgetNode(name: 'Act.scale', args: {'from': ConstNode(0.6)}),
              WidgetNode(name: 'Act.fadeIn', args: {}),
            ]),
            'child': WidgetNode(
              name: 'Text',
              args: {
                'data': StringInterpNode([
                  RefNode(['data', 'value']),
                ]),
                'style': WidgetNode(
                  name: 'TextStyle',
                  args: {
                    'fontSize': ConstNode(128),
                    'fontWeight': RefNode(['FontWeight', 'w900']),
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
  methods: const [],
  reactives: const [],
);
