part of 'package:desk_sdui_demo/screens/counter_burst.dart';

ScreenBinding get counter_burstBinding => ScreenBinding(
  name: 'counter_burst',
  ir: IrTree(
    name: 'counter_burst',
    version: 1,
    root: WidgetNode(
      name: 'Stack',
      args: {
        'alignment': RefNode(['Alignment', 'center']),
        'children': ListNode([
          ForNode(
            variable: 'i',
            source: RefNode(['data', 'chips']),
            body: WidgetNode(
              name: 'Cue.onMount',
              args: {
                'motion': WidgetNode(name: 'CueMotion.smooth', args: {}),
                'acts': ListNode([
                  WidgetNode(name: 'Act.fadeIn', args: {}),
                  WidgetNode(
                    name: 'Act.slideY',
                    args: {'from': ConstNode(0.3)},
                  ),
                  WidgetNode(name: 'Act.scale', args: {'from': ConstNode(0.5)}),
                ]),
                'child': WidgetNode(
                  name: 'Padding',
                  args: {
                    'padding': WidgetNode(
                      name: 'EdgeInsets.only',
                      args: {
                        'left': ArithOpNode(
                          op: ArithOp.mul,
                          left: ConstNode(6.0),
                          right: RefNode(['i']),
                        ),
                        'top': ArithOpNode(
                          op: ArithOp.mul,
                          left: ConstNode(4.0),
                          right: RefNode(['i']),
                        ),
                      },
                    ),
                    'child': WidgetNode(
                      name: 'Icon',
                      args: {
                        'icon': RefNode(['Icons', 'star']),
                        'size': ConstNode(24),
                        'color': RefNode(['Colors', 'amber']),
                      },
                    ),
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
                WidgetNode(name: 'Act.scale', args: {'from': ConstNode(0.7)}),
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
        ]),
      },
    ),
  ),
  inputs: [InputBinding(name: 'data', read: (v) => v as dynamic)],
  methods: const [],
  reactives: const [],
);
