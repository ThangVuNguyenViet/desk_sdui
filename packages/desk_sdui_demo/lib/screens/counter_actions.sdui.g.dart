part of 'package:desk_sdui_demo/screens/counter_actions.dart';

ScreenBinding get counter_actionsBinding => ScreenBinding(
  name: 'counter_actions',
  ir: IrTree(
    name: 'counter_actions',
    version: 1,
    root: WidgetNode(
      name: 'Center',
      args: {
        'child': WidgetNode(
          name: 'Column',
          args: {
            'mainAxisAlignment': RefNode(['MainAxisAlignment', 'center']),
            'children': ListNode([
              WidgetNode(
                name: 'Text',
                args: {
                  'data': StringInterpNode([
                    RefNode(['vm', 'value']),
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
              WidgetNode(
                name: 'Row',
                args: {
                  'mainAxisAlignment': RefNode(['MainAxisAlignment', 'center']),
                  'children': ListNode([
                    WidgetNode(
                      name: 'ElevatedButton',
                      args: {
                        'onPressed': EventNode(['vm', 'decrement']),
                        'child': WidgetNode(
                          name: 'Text',
                          args: {'data': ConstNode('-')},
                        ),
                      },
                    ),
                    WidgetNode(
                      name: 'SizedBox',
                      args: {'width': ConstNode(16)},
                    ),
                    WidgetNode(
                      name: 'ElevatedButton',
                      args: {
                        'onPressed': EventNode(['vm', 'increment']),
                        'child': WidgetNode(
                          name: 'Text',
                          args: {'data': ConstNode('+')},
                        ),
                      },
                    ),
                  ]),
                },
              ),
            ]),
          },
        ),
      },
    ),
  ),
  inputs: [InputBinding(name: 'vm', read: (v) => v as dynamic)],
  methodRefs: {
    'vm': ['decrement', 'increment'],
  },
  reactives: const [],
);
