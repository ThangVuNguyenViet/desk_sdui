// ExpressionNode and all expression subclasses are defined in ir_node.dart
// because sealed classes must be in the same library.
// This file re-exports them for backward compatibility.
export 'ir_node.dart'
    show
        ArithOpNode,
        CoalesceOpNode,
        CompareOpNode,
        ExpressionNode,
        IndexAccessNode,
        IsNullCheckNode,
        LengthOfNode,
        LogicOpNode,
        MemberAccessNode,
        NotOpNode,
        StringInterpNode;
