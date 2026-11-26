part of 'conversation_tree.dart';

/// A node of a [ConversationTree]. Read-only for callers: change the tree
/// through the tree's methods.
class TreeNode<T> {
  TreeNode._(this.id, this.parentId, this.value);

  /// Stable id of this node, unique inside its tree.
  final String id;

  /// Id of the parent, or `null` for the root.
  final String? parentId;

  /// The payload, or `null` for the root.
  final T? value;

  final List<String> _childIds = <String>[];
  int _activeChildIndex = 0;

  /// Ids of the children in creation order.
  List<String> get childIds => List<String>.unmodifiable(_childIds);

  /// Index into [childIds] of the child on the active path (0 when there are
  /// no children). Kept even when a sibling branch is selected elsewhere, so
  /// coming back lands on the leaf you last looked at.
  int get activeChildIndex => _activeChildIndex;

  @override
  String toString() => 'TreeNode($id, children: $_childIds)';
}
