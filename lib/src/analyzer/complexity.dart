import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Cyclomatic complexity. The count starts at 1 and increases for each
/// decision point. Nested functions are included in the enclosing node.
int cyclomaticComplexity(AstNode node) {
  final counter = _ComplexityCounter();
  node.accept(counter);
  return counter.count;
}

final class _ComplexityCounter extends RecursiveAstVisitor<void> {
  int count = 1;

  @override
  void visitIfStatement(IfStatement node) {
    count += 1;
    super.visitIfStatement(node);
  }

  @override
  void visitIfElement(IfElement node) {
    count += 1;
    super.visitIfElement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    count += 1;
    super.visitForStatement(node);
  }

  @override
  void visitForElement(ForElement node) {
    count += 1;
    super.visitForElement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    count += 1;
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    count += 1;
    super.visitDoStatement(node);
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    count += 1;
    super.visitSwitchCase(node);
  }

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    count += 1;
    super.visitSwitchPatternCase(node);
  }

  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    count += 1;
    super.visitSwitchExpressionCase(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    count += 1;
    super.visitCatchClause(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    count += 1;
    super.visitConditionalExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final operator = node.operator.lexeme;
    if (operator == '&&' || operator == '||') {
      count += 1;
    }
    super.visitBinaryExpression(node);
  }
}

int lineSpan(AstNode node, int Function(int offset) lineOf) {
  final start = lineOf(node.offset);
  final end = lineOf(node.end - 1 < node.offset ? node.offset : node.end - 1);
  final span = end - start + 1;
  return span < 1 ? 1 : span;
}
