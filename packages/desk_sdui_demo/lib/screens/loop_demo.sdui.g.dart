part of 'package:desk_sdui_demo/screens/loop_demo.dart';

ScreenBinding get loop_demoBinding => ScreenBinding(
  name: 'loop_demo',
  ir: IrTree(
    name: 'loop_demo',
    version: 1,
    root: BlockNode(
      statements: [
        LetStatementNode(
          name: 'positives',
          value: ConstNode(0),
          isFinal: false,
        ),
        ImperativeForNode(
          init: LetStatementNode(
            name: 'i',
            value: ConstNode(0),
            isFinal: false,
          ),
          condition: CompareOpNode(
            op: CompareOp.lt,
            left: RefNode(['i']),
            right: LengthOfNode(RefNode(['vm', 'numbers'])),
          ),
          update: AssignNode(
            name: 'i',
            value: ArithOpNode(
              op: ArithOp.add,
              left: RefNode(['i']),
              right: ConstNode(1),
            ),
          ),
          body: BlockNode(
            statements: [
              IfStatementNode(
                cond: CompareOpNode(
                  op: CompareOp.gt,
                  left: IndexAccessNode(
                    target: RefNode(['vm', 'numbers']),
                    key: RefNode(['i']),
                  ),
                  right: ConstNode(0),
                ),
                then: BlockNode(
                  statements: [
                    AssignNode(
                      name: 'positives',
                      value: ArithOpNode(
                        op: ArithOp.add,
                        left: RefNode(['positives']),
                        right: ConstNode(1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ReturnNode(
          value: WidgetNode(
            name: 'Text',
            args: {
              'data': StringInterpNode([
                'Positives: ',
                RefNode(['positives']),
              ]),
            },
          ),
        ),
      ],
    ),
  ),
  inputs: [InputBinding(name: 'vm', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
