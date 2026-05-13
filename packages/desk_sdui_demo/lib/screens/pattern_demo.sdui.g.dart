part of 'package:desk_sdui_demo/screens/pattern_demo.dart';

ScreenBinding get pattern_demoBinding => ScreenBinding(
  name: 'pattern_demo',
  ir: IrTree(
    name: 'pattern_demo',
    version: 1,
    root: LetNode(
      name: '__scrut0__',
      value: RefNode(['vm', 'state']),
      body: ConditionalNode(
        condition: IsTypeNode(
          receiver: RefNode(['__scrut0__']),
          typeName: 'PatternLoading',
        ),
        thenBranch: WidgetNode(name: 'CircularProgressIndicator', args: {}),
        elseBranch: ConditionalNode(
          condition: IsTypeNode(
            receiver: RefNode(['__scrut0__']),
            typeName: 'PatternLoaded',
          ),
          thenBranch: LetNode(
            name: 'items',
            value: MemberAccessNode(
              target: RefNode(['__scrut0__']),
              name: 'items',
            ),
            body: WidgetNode(
              name: 'Text',
              args: {
                'data': StringInterpNode([
                  'Got ',
                  LengthOfNode(RefNode(['items'])),
                  ' items',
                ]),
              },
            ),
          ),
          elseBranch: WidgetNode(name: 'SizedBox.shrink', args: {}),
        ),
      ),
    ),
  ),
  inputs: [InputBinding(name: 'vm', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
