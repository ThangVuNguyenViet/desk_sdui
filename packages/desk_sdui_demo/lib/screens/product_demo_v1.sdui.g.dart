part of 'package:desk_sdui_demo/screens/product_demo_v1.dart';

ScreenBinding get product_demoBinding => ScreenBinding(
  name: 'product_demo',
  ir: IrTree(
    name: 'product_demo',
    version: 1,
    root: ScreenWithFunctionsNode(
      functions: [],
      classes: [
        PayloadClassNode(
          name: 'Product',
          mixinNames: [],
          fields: [
            PayloadFieldDeclNode(name: 'id', isFinal: true),
            PayloadFieldDeclNode(name: 'title', isFinal: true),
            PayloadFieldDeclNode(name: 'price', isFinal: true),
            PayloadFieldDeclNode(name: 'description', isFinal: true),
          ],
          ctors: [
            PayloadCtorNode(
              name: '',
              params: ['id', 'title', 'price', 'description'],
              fieldInits: [
                PayloadFieldInitNode(fieldName: 'id', value: RefNode(['id'])),
                PayloadFieldInitNode(
                  fieldName: 'title',
                  value: RefNode(['title']),
                ),
                PayloadFieldInitNode(
                  fieldName: 'price',
                  value: RefNode(['price']),
                ),
                PayloadFieldInitNode(
                  fieldName: 'description',
                  value: RefNode(['description']),
                ),
              ],
            ),
          ],
          methods: [],
        ),
      ],
      screenBody: LetNode(
        name: 'vm',
        value: MethodCallNode(
          receiver: null,
          name: 'ProductViewModelProvider.of',
          args: [
            RefNode(['context']),
          ],
        ),
        body: LetNode(
          name: 'theme',
          value: MethodCallNode(
            receiver: null,
            name: 'Theme.of',
            args: [
              RefNode(['context']),
            ],
          ),
          body: WidgetNode(
            name: 'ListView',
            args: {
              'children': ListNode([
                ForNode(
                  variable: 'p',
                  source: GetterNode(
                    receiver: RefNode(['vm']),
                    name: 'ProductViewModel.products',
                  ),
                  body: WidgetNode(
                    name: 'Card',
                    args: {
                      'margin': WidgetNode(
                        name: 'EdgeInsets.all',
                        args: {'arg0': ConstNode(8.0)},
                      ),
                      'child': WidgetNode(
                        name: 'ListTile',
                        args: {
                          'title': WidgetNode(
                            name: 'Text',
                            args: {
                              'data': GetterNode(
                                receiver: RefNode(['p']),
                                name: 'Product.title',
                              ),
                            },
                          ),
                          'subtitle': WidgetNode(
                            name: 'Text',
                            args: {
                              'data': GetterNode(
                                receiver: RefNode(['p']),
                                name: 'Product.description',
                              ),
                            },
                          ),
                          'trailing': WidgetNode(
                            name: 'ElevatedButton',
                            args: {
                              'onPressed': LambdaNode(
                                params: [],
                                body: BlockNode(
                                  statements: [
                                    PayloadMethodCallNode(
                                      receiver: RefNode(['vm']),
                                      methodName: 'addToCart',
                                      args: {
                                        'arg0': RefNode(['context']),
                                        'arg1': RefNode(['p']),
                                      },
                                    ),
                                    MethodCallNode(
                                      receiver: null,
                                      name: 'demoShowSnackBar',
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
                              'child': WidgetNode(
                                name: 'Text',
                                args: {'data': ConstNode('Add to Cart')},
                              ),
                            },
                          ),
                        },
                      ),
                    },
                  ),
                ),
              ]),
            },
          ),
        ),
      ),
    ),
  ),
  inputs: [InputBinding(name: 'context', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
