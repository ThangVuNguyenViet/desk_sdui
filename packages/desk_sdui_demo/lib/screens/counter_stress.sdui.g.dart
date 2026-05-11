part of 'package:desk_sdui_demo/screens/counter_stress.dart';

ScreenBinding get counter_stressBinding => ScreenBinding(
  name: 'counter_stress',
  ir: IrTree(
    name: 'counter_stress',
    version: 1,
    root: WidgetNode(
      name: 'Stack',
      args: {
        'alignment': RefNode(['Alignment', 'center']),
        'children': ListNode([
          ForNode(
            variable: '_',
            source: RefNode(['data', 'chips']),
            body: WidgetNode(
              name: 'Cue.onMount',
              args: {
                'motion': WidgetNode(name: 'CueMotion.smooth', args: {}),
                'acts': ListNode([
                  WidgetNode(name: 'Act.fadeIn', args: {}),
                  WidgetNode(
                    name: 'Act.slideY',
                    args: {'from': ConstNode(0.2)},
                  ),
                  WidgetNode(name: 'Act.scale', args: {'from': ConstNode(0.4)}),
                  WidgetNode(name: 'Act.rotate', args: {'to': ConstNode(360)}),
                ]),
                'child': WidgetNode(
                  name: 'Icon',
                  args: {
                    'icon': RefNode(['Icons', 'circle']),
                    'size': ConstNode(10),
                    'color': RefNode(['Colors', 'deepPurple']),
                  },
                ),
              },
            ),
          ),
          WidgetNode(
            name: 'Cue.onChange',
            args: {
              'value': RefNode(['data', 'value']),
              'motion': WidgetNode(name: 'CueMotion.bouncy', args: {}),
              'acts': ListNode([
                WidgetNode(name: 'Act.scale', args: {'from': ConstNode(0.6)}),
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
                      'fontSize': ConstNode(144),
                      'fontWeight': RefNode(['FontWeight', 'w900']),
                    },
                  ),
                },
              ),
            },
          ),
        ]),
      },
    ),
  ),
  inputs: [InputBinding(name: 'data', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
