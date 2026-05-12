part of 'package:desk_sdui_demo/screens/stateful_counter_demo.dart';

ScreenBinding get stateful_counter_demoBinding => ScreenBinding(
  name: 'stateful_counter_demo',
  ir: IrTree(
    name: 'stateful_counter_demo',
    version: 1,
    root: IrStatefulNode(
      fields: [
        IrStatefulFieldNode(
          name: 'count',
          initializer: ConstNode(0),
          isFinal: false,
        ),
      ],
      body: WidgetNode(
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
                      'Count: ',
                      RefNode(['count']),
                    ]),
                    'style': WidgetNode(
                      name: 'TextStyle',
                      args: {'fontSize': ConstNode(32)},
                    ),
                  },
                ),
                WidgetNode(name: 'SizedBox', args: {'height': ConstNode(16)}),
                WidgetNode(
                  name: 'ElevatedButton',
                  args: {
                    'onPressed': LambdaNode(
                      params: [],
                      body: BlockNode(
                        statements: [
                          AssignNode(
                            name: 'count',
                            value: ArithOpNode(
                              op: ArithOp.add,
                              left: RefNode(['count']),
                              right: LiteralNode(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    'child': WidgetNode(
                      name: 'Text',
                      args: {'data': ConstNode('+')},
                    ),
                  },
                ),
              ]),
            },
          ),
        },
      ),
    ),
  ),
  inputs: const [],
  methodRefs: const {},
  reactives: const [],
);
