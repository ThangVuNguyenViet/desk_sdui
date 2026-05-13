part of 'package:desk_sdui_demo/screens/imperative_demo.dart';

ScreenBinding get imperative_demoBinding => ScreenBinding(
  name: 'imperative_demo',
  ir: IrTree(
    name: 'imperative_demo',
    version: 1,
    root: BlockNode(
      statements: [
        IfStatementNode(
          cond: GetterNode(
            receiver: RefNode(['vm', 'items']),
            name: 'List.isEmpty',
          ),
          then: BlockNode(
            statements: [
              ReturnNode(
                value: WidgetNode(
                  name: 'Text',
                  args: {'data': ConstNode('No items')},
                ),
              ),
            ],
          ),
        ),
        LetStatementNode(
          name: 'summary',
          value: StringInterpNode([
            LengthOfNode(RefNode(['vm', 'items'])),
            ' items',
          ]),
          isFinal: true,
        ),
        ReturnNode(
          value: WidgetNode(
            name: 'Text',
            args: {
              'data': RefNode(['summary']),
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
