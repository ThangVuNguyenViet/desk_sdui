part of 'package:desk_sdui_demo/screens/lambda_demo.dart';

ScreenBinding get lambda_demoBinding => ScreenBinding(
  name: 'lambda_demo',
  ir: IrTree(
    name: 'lambda_demo',
    version: 1,
    root: LetNode(
      name: 'nonEmpty',
      value: MethodCallNode(
        receiver: MethodCallNode(
          receiver: RefNode(['data', 'items']),
          name: 'List.where',
          args: [
            LambdaNode(
              params: ['x'],
              body: GetterNode(
                receiver: RefNode(['x']),
                name: 'String.isNotEmpty',
              ),
            ),
          ],
        ),
        name: 'Iterable.toList',
        args: [],
      ),
      body: WidgetNode(
        name: 'Column',
        args: {
          'children': ListNode([
            ForNode(
              variable: 'item',
              source: RefNode(['nonEmpty']),
              body: WidgetNode(
                name: 'Text',
                args: {
                  'data': RefNode(['item']),
                },
              ),
            ),
          ]),
        },
      ),
    ),
  ),
  inputs: [InputBinding(name: 'data', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
