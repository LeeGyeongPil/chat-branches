/// Thrown when a node id is not part of the tree.
class NodeNotFoundException implements Exception {
  /// Creates the exception for the missing [id].
  const NodeNotFoundException(this.id);

  /// The id that was looked up.
  final String id;

  @override
  String toString() => 'NodeNotFoundException: no node with id "$id" in this '
      'tree. Ids come from TreeNode.id of nodes returned by the same tree.';
}

/// Thrown by `ConversationTree.fromJson` when the input is not a valid
/// `chat_branches` document. The message names the offending field.
class TreeFormatException extends FormatException {
  /// Creates the exception; [field] is the JSON path that is wrong.
  TreeFormatException(String field, String problem)
      : field = field,
        super('Invalid chat_branches JSON at "$field": $problem');

  /// The JSON path of the offending field, for example `nodes[3].active`.
  final String field;
}
