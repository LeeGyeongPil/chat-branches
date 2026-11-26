import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

/// A Firebase-style provider for tests: records every `history =` call (a real
/// FirebaseProvider restarts its chat session there), answers instantly and
/// deterministically with "A<k>: <prompt>", and can be told to fail or pause.
class FakeSessionProvider extends LlmProvider with ChangeNotifier {
  final List<ChatMessage> _history = [];

  /// Texts of the history each time the setter was called.
  final List<List<String>> historySets = [];

  /// Prompts received by sendMessageStream, with the history texts at that time.
  final List<({String prompt, List<String> context})> sent = [];

  int _answers = 0;

  /// When set, the answer waits for this completer after the first chunk.
  Completer<void>? gate;

  /// Exception thrown after the first chunk, if any.
  Object? failWith;

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> value) {
    _history
      ..clear()
      ..addAll(value);
    historySets.add([for (final m in _history) m.text ?? '']);
    notifyListeners();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    yield 'A${++_answers}: ';
    final g = gate;
    if (g != null) await g.future;
    final f = failWith;
    if (f != null) throw f;
    yield prompt;
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) {
    sent.add((prompt: prompt, context: [for (final m in _history) m.text ?? '']));
    final user = ChatMessage.user(prompt, attachments);
    final llm = ChatMessage.llm();
    _history.addAll([user, llm]);
    return generateStream(prompt, attachments: attachments).map((c) {
      llm.append(c);
      return c;
    });
  }
}

/// Drains [stream] and ignores a thrown error, returning it (or null).
Future<Object?> drain(Stream<String> stream) async {
  try {
    await stream.drain<void>();
    return null;
  } on Object catch (e) {
    return e;
  }
}

List<String> texts(Iterable<ChatMessage> messages) =>
    [for (final m in messages) m.text ?? ''];
