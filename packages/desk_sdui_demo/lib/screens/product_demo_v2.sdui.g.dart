part of 'package:desk_sdui_demo/screens/product_demo_v2.dart';

ScreenBinding get product_demo_v2Binding => ScreenBinding(
  name: 'product_demo_v2',
  ir: IrTree(
    name: 'product_demo_v2',
    version: 1,
    root: ScreenWithFunctionsNode(
      functions: [],
      screenBody: LetNode(
        name: 'vm',
        value: MethodCallNode(
          receiver: null,
          name: 'ProductViewModelProvider.of',
          args: [
            RefNode(['context']),
          ],
        ),
        body: WidgetNode(
          name: 'Container',
          args: {
            'color': GetterNode(
              receiver: MethodCallNode(
                receiver: null,
                name: 'Theme.of',
                args: [
                  RefNode(['context']),
                ],
              ),
              name: 'ThemeData.scaffoldBackgroundColor',
            ),
            'child': WidgetNode(
              name: 'Column',
              args: {
                'crossAxisAlignment': RefNode(['CrossAxisAlignment', 'start']),
                'children': ListNode([
                  WidgetNode(
                    name: 'Padding',
                    args: {
                      'padding': WidgetNode(
                        name: 'EdgeInsets.fromLTRB',
                        args: {
                          'arg0': ConstNode(24.0),
                          'arg1': ConstNode(32.0),
                          'arg2': ConstNode(24.0),
                          'arg3': ConstNode(16.0),
                        },
                      ),
                      'child': WidgetNode(
                        name: 'Column',
                        args: {
                          'crossAxisAlignment': RefNode([
                            'CrossAxisAlignment',
                            'start',
                          ]),
                          'children': ListNode([
                            WidgetNode(
                              name: 'Text',
                              args: {
                                'data': ConstNode('THE COLLECTION'),
                                'style': WidgetNode(
                                  name: 'TextStyle',
                                  args: {
                                    'color': WidgetNode(
                                      name: 'Color',
                                      args: {'arg0': ConstNode(4278255564)},
                                    ),
                                    'fontSize': ConstNode(12.0),
                                    'fontWeight': RefNode([
                                      'FontWeight',
                                      'w900',
                                    ]),
                                    'letterSpacing': ConstNode(2.0),
                                  },
                                ),
                              },
                            ),
                            WidgetNode(
                              name: 'SizedBox',
                              args: {'height': ConstNode(8.0)},
                            ),
                            WidgetNode(
                              name: 'Text',
                              args: {
                                'data': ConstNode('Featured'),
                                'style': WidgetNode(
                                  name: 'TextStyle',
                                  args: {
                                    'color': RefNode(['Colors', 'white']),
                                    'fontSize': ConstNode(32.0),
                                    'fontWeight': RefNode([
                                      'FontWeight',
                                      'w300',
                                    ]),
                                    'letterSpacing': ArithOpNode(
                                      op: ArithOp.sub,
                                      left: ConstNode(0),
                                      right: ConstNode(1.0),
                                    ),
                                  },
                                ),
                              },
                            ),
                          ]),
                        },
                      ),
                    },
                  ),
                  WidgetNode(
                    name: 'Expanded',
                    args: {
                      'child': WidgetNode(
                        name: 'ListView',
                        args: {
                          'padding': WidgetNode(
                            name: 'EdgeInsets.symmetric',
                            args: {'horizontal': ConstNode(16.0)},
                          ),
                          'children': ListNode([
                            ForNode(
                              variable: 'p',
                              source: GetterNode(
                                receiver: RefNode(['vm']),
                                name: 'ProductViewModel.products',
                              ),
                              body: WidgetNode(
                                name: 'ProductCard',
                                args: {
                                  'p': RefNode(['p']),
                                  'onAddToCart': LambdaNode(
                                    params: [],
                                    body: BlockNode(
                                      statements: [
                                        MethodCallNode(
                                          receiver: RefNode(['vm']),
                                          name: 'addToCart',
                                          args: [
                                            RefNode(['context']),
                                            RefNode(['p']),
                                          ],
                                        ),
                                        MethodCallNode(
                                          receiver: null,
                                          name: 'demoShowSuccess',
                                          args: [
                                            RefNode(['context']),
                                            GetterNode(
                                              receiver: RefNode(['p']),
                                              name: 'Product.title',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                },
                              ),
                            ),
                          ]),
                        },
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
  ),
  inputs: [InputBinding(name: 'context', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
