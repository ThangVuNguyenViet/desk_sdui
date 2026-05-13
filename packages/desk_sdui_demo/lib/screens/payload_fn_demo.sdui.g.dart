part of 'package:desk_sdui_demo/screens/payload_fn_demo.dart';

ScreenBinding get payload_fn_demoBinding => ScreenBinding(
  name: 'payload_fn_demo',
  ir: IrTree(
    name: 'payload_fn_demo',
    version: 1,
    root: ScreenWithFunctionsNode(
      functions: [
        PayloadFunctionNode(
          name: 'describe',
          params: ['count'],
          body: BlockNode(
            statements: [
              IfStatementNode(
                cond: CompareOpNode(
                  op: CompareOp.eq,
                  left: RefNode(['count']),
                  right: ConstNode(0),
                ),
                then: ReturnNode(value: ConstNode('No items')),
              ),
              IfStatementNode(
                cond: CompareOpNode(
                  op: CompareOp.eq,
                  left: RefNode(['count']),
                  right: ConstNode(1),
                ),
                then: ReturnNode(value: ConstNode('1 item')),
              ),
              ReturnNode(
                value: StringInterpNode([
                  RefNode(['count']),
                  ' items',
                ]),
              ),
            ],
          ),
        ),
      ],
      screenBody: WidgetNode(
        name: 'Text',
        args: {
          'data': PayloadFunctionCallNode(
            name: 'describe',
            args: [
              GetterNode(
                receiver: RefNode(['vm', 'items']),
                name: 'List.length',
              ),
            ],
          ),
        },
      ),
    ),
  ),
  inputs: [InputBinding(name: 'vm', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
