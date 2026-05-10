// ExpressionNode and all expression subclasses are defined in ir_node.dart
// because sealed classes must be in the same library.
// This file is kept for backward compatibility and re-exports from ir_node.dart.
export 'ir_node.dart'
    show
        ExpressionNode,
        CompareOpNode,
        ArithOpNode,
        LogicOpNode,
        NotOpNode,
        CoalesceOpNode,
        MemberAccessNode,
        IndexAccessNode,
        LengthOfNode,
        IsNullCheckNode,
        StringInterpNode;
