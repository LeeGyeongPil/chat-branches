part of 'conversation_tree.dart';

/// Format name stored in every document.
const String treeJsonFormat = 'chat_branches';

/// The only supported document version.
const int treeJsonVersion = 1;

Map<String, Object?> _treeToJson<T>(
  ConversationTree<T> tree,
  Object? Function(T value) encode,
) {
  // Root first, then the rest in id-insertion order (parents before children).
  final ordered = <TreeNode<T>>[];
  void visit(TreeNode<T> node) {
    ordered.add(node);
    for (final c in node._childIds) {
      visit(tree._nodes[c]!);
    }
  }

  visit(tree._nodes[tree._rootId]!);
  return <String, Object?>{
    'format': treeJsonFormat,
    'version': treeJsonVersion,
    'root': tree._rootId,
    'nodes': [
      for (final n in ordered)
        <String, Object?>{
          'id': n.id,
          'parent': n.parentId,
          'children': List<String>.of(n._childIds),
          'active': n._activeChildIndex,
          if (n.parentId != null) 'value': encode(n.value as T),
        },
    ],
  };
}

ConversationTree<T> _treeFromJson<T>(
  Map<String, Object?> json, {
  required T Function(Object? json) decode,
  String Function()? newId,
}) {
  if (json['format'] != treeJsonFormat) {
    throw TreeFormatException(
      'format',
      'expected "$treeJsonFormat" but found ${json['format']}',
    );
  }
  if (json['version'] != treeJsonVersion) {
    throw TreeFormatException(
      'version',
      'expected $treeJsonVersion but found ${json['version']}. '
          'This release reads version $treeJsonVersion only.',
    );
  }
  final rootId = json['root'];
  if (rootId is! String) {
    throw TreeFormatException('root', 'must be a string id');
  }
  final rawNodes = json['nodes'];
  if (rawNodes is! List<Object?>) {
    throw TreeFormatException('nodes', 'must be a list');
  }

  final tree = ConversationTree<T>._empty(newId);
  tree._rootId = rootId;

  // Pass 1: create nodes.
  final children = <String, List<String>>{};
  final actives = <String, int>{};
  for (var i = 0; i < rawNodes.length; i++) {
    final path = 'nodes[$i]';
    final raw = rawNodes[i];
    if (raw is! Map<Object?, Object?>) {
      throw TreeFormatException(path, 'must be an object');
    }
    final id = raw['id'];
    if (id is! String) throw TreeFormatException('$path.id', 'must be a string');
    if (tree._nodes.containsKey(id)) {
      throw TreeFormatException('$path.id', 'duplicate id "$id"');
    }
    final parent = raw['parent'];
    if (parent != null && parent is! String) {
      throw TreeFormatException('$path.parent', 'must be a string or null');
    }
    final kids = raw['children'];
    if (kids is! List<Object?> || kids.any((k) => k is! String)) {
      throw TreeFormatException('$path.children', 'must be a list of ids');
    }
    final active = raw['active'];
    if (active is! int) {
      throw TreeFormatException('$path.active', 'must be an integer');
    }
    final isRoot = id == rootId;
    if (isRoot != (parent == null)) {
      throw TreeFormatException(
        '$path.parent',
        isRoot ? 'the root must have parent null' : 'only the root may have no parent',
      );
    }
    final lastIndex = kids.isEmpty ? 0 : kids.length - 1;
    if (active < 0 || active > lastIndex) {
      throw TreeFormatException(
        '$path.active',
        'index $active is outside 0..$lastIndex for ${kids.length} children',
      );
    }
    T? value;
    if (!isRoot) {
      if (!raw.containsKey('value')) {
        throw TreeFormatException('$path.value', 'missing');
      }
      try {
        value = decode(raw['value']);
      } on Object catch (e) {
        throw TreeFormatException('$path.value', 'could not be decoded: $e');
      }
    }
    final node = TreeNode<T>._(id, parent as String?, value);
    node._activeChildIndex = active;
    tree._nodes[id] = node;
    children[id] = List<String>.from(kids);
    actives[id] = active;
  }
  if (!tree._nodes.containsKey(rootId)) {
    throw TreeFormatException('root', 'no node with id "$rootId"');
  }

  // Pass 2: wire children and check both directions of every reference.
  for (final entry in children.entries) {
    final node = tree._nodes[entry.key]!;
    for (final childId in entry.value) {
      final child = tree._nodes[childId];
      if (child == null) {
        throw TreeFormatException(
          'nodes.${entry.key}.children',
          'refers to unknown node "$childId"',
        );
      }
      if (child.parentId != entry.key) {
        throw TreeFormatException(
          'nodes.$childId.parent',
          'is "${child.parentId}" but "${entry.key}" lists it as a child',
        );
      }
      node._childIds.add(childId);
    }
  }

  // Everything must be reachable from the root (no orphans, no cycles).
  final seen = <String>{};
  final stack = <String>[rootId];
  while (stack.isNotEmpty) {
    final id = stack.removeLast();
    if (!seen.add(id)) {
      throw TreeFormatException('nodes', 'node "$id" is reachable twice');
    }
    stack.addAll(tree._nodes[id]!._childIds);
  }
  if (seen.length != tree._nodes.length) {
    throw TreeFormatException('nodes', 'some nodes are not reachable from the root');
  }

  // Continue default ids after the highest existing "n<number>".
  final pattern = RegExp(r'^n(\d+)$');
  for (final id in tree._nodes.keys) {
    final m = pattern.firstMatch(id);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      if (n > tree._counter) tree._counter = n;
    }
  }
  return tree;
}
