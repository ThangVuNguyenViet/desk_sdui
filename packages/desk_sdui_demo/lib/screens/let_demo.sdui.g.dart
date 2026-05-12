part of 'package:desk_sdui_demo/screens/let_demo.dart';

ScreenBinding get let_demoBinding => ScreenBinding(
  name: 'let_demo',
  ir: IrTree(
    name: 'let_demo',
    version: 1,
    root: LetNode(
      name: 'title',
      value: RefNode(['data', 'title']),
      body: LetNode(
        name: 'greeting',
        value: StringInterpNode([
          'Hello, ',
          RefNode(['title']),
          '!',
        ]),
        body: WidgetNode(
          name: 'Center',
          args: {
            'child': WidgetNode(
              name: 'Text',
              args: {
                'data': RefNode(['greeting']),
              },
            ),
          },
        ),
      ),
    ),
  ),
  inputs: [InputBinding(name: 'data', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
