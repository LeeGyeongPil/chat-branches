import 'errors.dart';

part 'tree_json.dart';
part 'tree_node.dart';

/// A conversation stored as a tree: every edit or regeneration adds a sibling
/// instead of replacing the old version.
///
/// The root is an empty node (`rootId`); real messages hang below it. The
/// *active path* follows each node's active child from the root down. Pure
/// Dart: this file and its parts do not import Flutter.
class ConversationTree<T> {
  /// Creates an empty tree. [newId] generates node ids; the default yields
  /// `n1`, `n2`, ... (the root is `n0`). Generated ids must be unique.
  ConversationTree({String Function()? newId}) : _customId = newId {
    _addRoot();
  }

  /// Builds a single branch (a chain) from a flat list of messages.
  factory ConversationTree.fromLinear(
    Iterable<T> messages, {
    String Function()? newId,
  }) {
    final tree = ConversationTree<T>(newId: newId);
    var parent = tree.rootId;
    for (final message in messages) {
      parent = tree.append(parent, message).id;
    }
    return tree;
  }

  /// Restores a tree written by [toJson]. [decode] turns a stored value back
  /// into a `T`. Throws [TreeFormatException] for invalid documents.
  factory ConversationTree.fromJson(
    Map<String, Object?> json, {
    required T Function(Object? json) decode,
    String Function()? newId,
  }) =>
      _treeFromJson<T>(json, decode: decode, newId: newId);

  ConversationTree._empty(this._customId);

  final String Function()? _customId;
  final Map<String, TreeNode<T>> _nodes = <String, TreeNode<T>>{};
  late String _rootId;
  int _counter = 0;

  void _addRoot() {
    _rootId = _customId?.call() ?? 'n0';
    _nodes[_rootId] = TreeNode<T>._(_rootId, null, null);
  }

  String _generateId() {
    if (_customId != null) {
      final id = _customId();
      if (_nodes.containsKey(id)) {
        throw ArgumentError.value(
          id,
          'newId',
          'The id generator returned an id that is already in use. '
              'Return a unique id on every call.',
        );
      }
      return id;
    }
    String id;
    do {
      id = 'n${++_counter}';
    } while (_nodes.containsKey(id));
    return id;
  }

  /// Id of the empty root node.
  String get rootId => _rootId;

  /// Number of nodes, not counting the root.
  int get length => _nodes.length - 1;

  /// All nodes except the root, in no particular order.
  Iterable<TreeNode<T>> get nodes =>
      _nodes.values.where((n) => n.id != _rootId);

  /// Looks a node up. Throws [NodeNotFoundException] for unknown ids.
  TreeNode<T> operator [](String id) {
    final node = _nodes[id];
    if (node == null) throw NodeNotFoundException(id);
    return node;
  }

  /// The active path from the first message to the active leaf (root left out).
  List<TreeNode<T>> get activePath {
    final out = <TreeNode<T>>[];
    var node = _nodes[_rootId]!;
    while (node._childIds.isNotEmpty) {
      node = _nodes[node._childIds[node._activeChildIndex]]!;
      out.add(node);
    }
    return out;
  }

  /// The values along [activePath].
  List<T> get activeValues => [for (final n in activePath) n.value as T];

  /// Path from the first message down to [id] (root left out).
  List<TreeNode<T>> pathTo(String id) {
    final out = <TreeNode<T>>[];
    String? current = this[id].id;
    while (current != null && current != _rootId) {
      final node = _nodes[current]!;
      out.add(node);
      current = node.parentId;
    }
    return out.reversed.toList();
  }

  /// Adds [value] as a new last child of [parentId] and makes it the active
  /// child (so it joins the active path if the parent is on it).
  TreeNode<T> append(String parentId, T value) {
    final parent = this[parentId];
    final node = TreeNode<T>._(_generateId(), parentId, value);
    _nodes[node.id] = node;
    parent._childIds.add(node.id);
    parent._activeChildIndex = parent._childIds.length - 1;
    return node;
  }

  /// The children of [id]'s parent, including [id], in creation order.
  List<TreeNode<T>> siblingsOf(String id) {
    final node = this[id];
    if (node.parentId == null) return [node];
    return [for (final c in this[node.parentId!]._childIds) _nodes[c]!];
  }

  /// Zero-based position of [id] among its siblings and the sibling count.
  ({int index, int count}) positionOf(String id) {
    final node = this[id];
    if (node.parentId == null) return (index: 0, count: 1);
    final siblings = this[node.parentId!]._childIds;
    return (index: siblings.indexOf(id), count: siblings.length);
  }

  /// Makes [id] part of the active path by pointing every ancestor at it.
  /// Nodes below [id] keep their remembered active children.
  void select(String id) {
    var node = this[id];
    while (node.parentId != null) {
      final parent = this[node.parentId!];
      parent._activeChildIndex = parent._childIds.indexOf(node.id);
      node = parent;
    }
  }

  /// Switches to sibling number [index] (zero-based) of [id]. Below the new
  /// sibling the path continues along the leaf last visited there.
  void selectSibling(String id, int index) {
    final siblings = siblingsOf(id);
    RangeError.checkValidIndex(
      index,
      siblings,
      'index',
      siblings.length,
    );
    select(siblings[index].id);
  }

  /// Serializes the tree (format `chat_branches`, version 1). [encode] turns a
  /// value into a JSON-encodable object.
  Map<String, Object?> toJson({required Object? Function(T value) encode}) =>
      _treeToJson<T>(this, encode);
}
