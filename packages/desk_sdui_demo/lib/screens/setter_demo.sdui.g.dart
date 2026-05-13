part of 'package:desk_sdui_demo/screens/setter_demo.dart';

ScreenBinding get setter_demoBinding => ScreenBinding(
  name: 'setter_demo',
  ir: IrTree(
    name: 'setter_demo',
    version: 1,
    root: WidgetNode(
      name: 'Column',
      args: {
        'children': ListNode([
          WidgetNode(
            name: 'Text',
            args: {
              'data': StringInterpNode([
                'Count: ',
                RefNode(['vm', 'count']),
              ]),
            },
          ),
          WidgetNode(
            name: 'Text',
            args: {
              'data': StringInterpNode([
                'Message: ',
                RefNode(['vm', 'message']),
              ]),
            },
          ),
          WidgetNode(
            name: 'ElevatedButton',
            args: {
              'onPressed': LambdaNode(
                params: [],
                body: BlockNode(
                  statements: [
                    SetterCallNode(
                      target: RefNode(['vm']),
                      setterKey: 'SetterDemoController.count',
                      value: ArithOpNode(
                        op: ArithOp.add,
                        left: RefNode(['vm', 'count']),
                        right: LiteralNode(1),
                      ),
                    ),
                  ],
                ),
              ),
              'child': WidgetNode(
                name: 'Text',
                args: {'data': ConstNode('Increment')},
              ),
            },
          ),
        ]),
      },
    ),
  ),
  inputs: [InputBinding(name: 'vm', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
