import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

import '../tree/conversation_tree.dart';
import 'busy.dart';

/// Wraps any [LlmProvider] and keeps the chat as a tree of branches.
///
/// Editing a question or regenerating an answer adds a sibling version instead
/// of discarding the old one. Pass it to `LlmChatView(provider: ...)` in place
/// of the wrapped provider; the view only ever sees the active path.
///
/// The streams returned by [sendMessageStream], [regenerate] and [editAt] must
/// be listened to (the toolkit view does), because the busy state ends when the
/// stream does.
class BranchingProvider extends LlmProvider with ChangeNotifier {
  /// Wraps [inner]. Pass [tree] to restore a saved conversation; otherwise the
  /// tree starts from whatever history [inner] already has.
  BranchingProvider(this.inner, {ConversationTree<ChatMessage>? tree}) {
    if (tree != null) {
      _tree = tree;
      _innerPath = null; // unknown: make the first send set inner's history
    } else {
      final existing = inner.history.toList();
      _tree = existing.isEmpty
          ? ConversationTree<ChatMessage>()
          : ConversationTree<ChatMessage>.fromLinear(existing);
      _innerPath = [for (final n in _tree.activePath) n.id];
    }
  }

  /// The wrapped provider that produces the answers.
  final LlmProvider inner;

  late ConversationTree<ChatMessage> _tree;

  /// Node after which the next exchange attaches; `null` means the end of the
  /// active path. Set while the toolkit view edits a question.
  String? _cursor;

  /// Ids of the nodes `inner.history` is known to mirror, or `null` if unknown.
  List<String>? _innerPath;

  bool _streaming = false;
  bool _disposed = false;

  /// The conversation tree. Read it freely; change it through this provider
  /// while an answer is streaming is not allowed.
  ConversationTree<ChatMessage> get tree => _tree;

  /// Whether an answer is currently streaming.
  bool get isStreaming => _streaming;

  /// Whether the toolkit view is editing a question (the history is cut at the
  /// fork point). Switching branches or regenerating meanwhile is possible but
  /// confusing, so UIs may want to disable those controls.
  bool get isEditing => _cursor != null;

  bool _belongsToTree(List<ChatMessage> list) =>
      list.isNotEmpty && list.every((m) => nodeIdOf(m) != null);

  String get _tipId {
    final path = _tree.activePath;
    return path.isEmpty ? _tree.rootId : path.last.id;
  }

  void _ensureIdle(String operation) {
    if (_streaming) throw BranchBusyException(operation);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The messages of the active path (up to the fork point while the toolkit
  /// view is editing a question).
  @override
  Iterable<ChatMessage> get history {
    final cursor = _cursor;
    if (cursor == null) return _tree.activeValues;
    return [for (final n in _tree.pathTo(cursor)) n.value!];
  }

  @override
  set history(Iterable<ChatMessage> value) {
    _ensureIdle('history');
    final list = value.toList();
    final active = _tree.activePath;
    var isPrefix = list.length <= active.length;
    for (var i = 0; isPrefix && i < list.length; i++) {
      isPrefix = identical(list[i], active[i].value);
    }
    if (isPrefix) {
      // Edit started (shorter prefix) or cancelled (the full path again).
      _cursor = list.length == active.length
          ? null
          : (list.isEmpty ? _tree.rootId : active[list.length - 1].id);
    } else if (_belongsToTree(list)) {
      // The view put back messages of this tree (for example when an edit is
      // cancelled after switching branches): show the path of the last one and
      // keep every version.
      _tree.select(nodeIdOf(list.last)!);
      _cursor = null;
    } else {
      // A history this tree has never seen: migrate it as a single branch.
      _tree = ConversationTree<ChatMessage>.fromLinear(list);
      _cursor = null;
      _innerPath = null;
    }
    _notify();
  }

  /// Delegates to [inner]; one-off generations are not part of the chat.
  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) =>
      inner.generateStream(prompt, attachments: attachments);

  /// Sends [prompt] as a new question under the current fork point.
  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) {
    _ensureIdle('sendMessageStream');
    return _start(
      contextEndId: _cursor ?? _tipId,
      userMessage: ChatMessage.user(prompt, attachments),
    );
  }

  /// Asks the same question again and adds the answer as a new sibling.
  ///
  /// [llmMessage] defaults to the last answer of the active path. The model
  /// only sees the conversation before that question.
  Stream<String> regenerate([ChatMessage? llmMessage]) {
    _ensureIdle('regenerate');
    final ChatMessage target;
    if (llmMessage != null) {
      target = llmMessage;
    } else {
      final path = _tree.activePath;
      if (path.isEmpty || !path.last.value!.origin.isLlm) {
        throw StateError(
          'There is no answer to regenerate. Send a message first, or pass '
          'the llm message you want to regenerate.',
        );
      }
      target = path.last.value!;
    }
    final id = nodeIdOf(target);
    final node = id == null ? null : _tree[id];
    if (node == null || !node.value!.origin.isLlm) {
      throw ArgumentError.value(
        llmMessage,
        'llmMessage',
        'must be an answer (llm message) that belongs to this tree',
      );
    }
    final userNode = _tree[node.parentId!];
    if (userNode.value == null || !userNode.value!.origin.isUser) {
      throw ArgumentError.value(
        llmMessage,
        'llmMessage',
        'has no question above it to ask again',
      );
    }
    return _start(
      contextEndId: userNode.parentId!,
      userMessage: userNode.value!,
      existingUserNodeId: userNode.id,
    );
  }

  /// Replaces the question [userMessage] with [text] as a new sibling version,
  /// at any depth. The old version and everything below it stay reachable.
  Stream<String> editAt(
    ChatMessage userMessage,
    String text, {
    Iterable<Attachment> attachments = const [],
  }) {
    _ensureIdle('editAt');
    final id = nodeIdOf(userMessage);
    if (id == null || !userMessage.origin.isUser) {
      throw ArgumentError.value(
        userMessage,
        'userMessage',
        'must be a user message that belongs to this tree',
      );
    }
    return _start(
      contextEndId: _tree[id].parentId!,
      userMessage: ChatMessage.user(text, attachments),
    );
  }

  /// Zero-based position and count of [message] among its sibling versions, or
  /// `null` when the message is not in the tree.
  ({int index, int count})? branchInfoOf(ChatMessage message) {
    final id = nodeIdOf(message);
    return id == null ? null : _tree.positionOf(id);
  }

  /// Id of the node holding [message] (compared by identity), or `null`.
  String? nodeIdOf(ChatMessage message) {
    for (final node in _tree.nodes) {
      if (identical(node.value, message)) return node.id;
    }
    return null;
  }

  /// Shows sibling number [index] (zero-based) of [message]. Throws
  /// [BranchBusyException] while streaming.
  void selectSibling(ChatMessage message, int index) {
    _ensureIdle('selectSibling');
    final id = nodeIdOf(message);
    if (id == null) {
      throw ArgumentError.value(
        message,
        'message',
        'does not belong to this tree',
      );
    }
    _tree.selectSibling(id, index);
    _cursor = null;
    _notify();
  }

  /// Empties the conversation (the wrapped provider is re-synced on the next
  /// send).
  void reset() {
    _ensureIdle('reset');
    _tree = ConversationTree<ChatMessage>();
    _cursor = null;
    _innerPath = null;
    _notify();
  }

  /// The whole tree as JSON-encodable data (see `ConversationTree.toJson`).
  Map<String, Object?> toJson() => _tree.toJson(encode: _encodeMessage);

  /// Restores a tree saved with [toJson].
  static ConversationTree<ChatMessage> treeFromJson(
    Map<String, Object?> json,
  ) =>
      ConversationTree<ChatMessage>.fromJson(json, decode: _decodeMessage);

  // The toolkit's ChatMessage.toJson writes null text for an unfinished answer
  // and a Uri for link attachments; both break a JSON round trip.
  static Object? _encodeMessage(ChatMessage message) {
    final json = message.toJson();
    json['text'] ??= '';
    final attachments = json['attachments'];
    if (attachments is List<Object?>) {
      for (final a in attachments) {
        if (a is Map<String, Object?> && a['data'] is Uri) {
          a['data'] = (a['data']! as Uri).toString();
        }
      }
    }
    return json;
  }

  static ChatMessage _decodeMessage(Object? json) =>
      ChatMessage.fromJson(Map<String, dynamic>.from(json! as Map<Object?, Object?>));

  /// Creates the nodes eagerly (so the view can show the pending answer) and
  /// returns the stream that fills the answer in.
  Stream<String> _start({
    required String contextEndId,
    required ChatMessage userMessage,
    String? existingUserNodeId,
  }) {
    _cursor = null;
    final userNodeId =
        existingUserNodeId ?? _tree.append(contextEndId, userMessage).id;
    final llmMessage = ChatMessage.llm();
    final llmNodeId = _tree.append(userNodeId, llmMessage).id;
    _tree.select(llmNodeId);
    final contextIds = [for (final n in _tree.pathTo(contextEndId)) n.id];
    _streaming = true;
    _notify();
    return _pump(
      contextIds: contextIds,
      userNodeId: userNodeId,
      llmNodeId: llmNodeId,
      userMessage: userMessage,
      llmMessage: llmMessage,
    );
  }

  bool _innerMirrors(List<String> ids) {
    final known = _innerPath;
    if (known == null || known.length != ids.length) return false;
    for (var i = 0; i < ids.length; i++) {
      if (known[i] != ids[i]) return false;
    }
    return inner.history.length == ids.length;
  }

  Stream<String> _pump({
    required List<String> contextIds,
    required String userNodeId,
    required String llmNodeId,
    required ChatMessage userMessage,
    required ChatMessage llmMessage,
  }) async* {
    var completed = false;
    try {
      // Skip the reset when inner already ends at the fork point: providers
      // such as FirebaseProvider restart their chat session on every set.
      if (!_innerMirrors(contextIds)) {
        inner.history = [for (final id in contextIds) _tree[id].value!];
      }
      // `yield*` rather than `await for`: see dart-lang/sdk#47764 (web).
      yield* inner
          .sendMessageStream(
            userMessage.text ?? '',
            attachments: userMessage.attachments,
          )
          .map((chunk) {
        llmMessage.append(chunk);
        _notify(); // lets a bar or list show the answer as it grows
        return chunk;
      });
      completed = true;
    } finally {
      _streaming = false;
      _innerPath = completed ? [...contextIds, userNodeId, llmNodeId] : null;
      _notify();
    }
  }
}
