part of 'package:desk_sdui_demo/screens/cascade_demo.dart';

ScreenBinding get cascade_demoBinding => ScreenBinding(
  name: 'cascade_demo',
  ir: IrTree(
    name: 'cascade_demo',
    version: 1,
    root: WidgetNode(
      name: 'TextField',
      args: {
        'controller': LetNode(
          name: '__cas0__',
          value: RefNode(['vm', 'controller']),
          body: SequenceNode(
            steps: [
              MethodCallNode(
                receiver: RefNode(['__cas0__']),
                name: 'text=',
                args: [ConstNode('initial')],
              ),
            ],
            returnExpr: RefNode(['__cas0__']),
          ),
        ),
      },
    ),
  ),
  inputs: [InputBinding(name: 'vm', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
