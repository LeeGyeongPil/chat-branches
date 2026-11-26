import 'package:chat_branches/chat_branches.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_session_provider.dart';

/// Mimics LlmChatView 1.x `_onEditMessage`: drop the last llm and user
/// message, assign the shorter history, then send the edited question.
Iterable<ChatMessage> _startEdit(LlmProvider p) {
  final h = p.history.toList()..removeLast()..removeLast();
  p.history = h;
  return h;
}

void main() {
  test('plain EchoProvider loses the edited pair', () async {
    final echo = EchoProvider();
    await drain(echo.sendMessageStream('first'));
    _startEdit(echo);
    await drain(echo.sendMessageStream('first (edited)'));
    final t = texts(echo.history);
    expect(t.length, 2);
    expect(t.first, 'first (edited)');
    expect(t.any((s) => s == 'first'), isFalse); // the original is gone
  });

  test('BranchingProvider keeps both versions and switches back', () async {
    final p = BranchingProvider(EchoProvider());
    await drain(p.sendMessageStream('first'));
    final original = p.history.toList();
    final originalTexts = texts(original);
    _startEdit(p);
    await drain(p.sendMessageStream('first (edited)'));

    final edited = p.history.first;
    expect(edited.text, 'first (edited)');
    expect(p.branchInfoOf(edited), (index: 1, count: 2)); // "2/2"
    expect(p.tree.siblingsOf(p.nodeIdOf(edited)!).length, 2);

    p.selectSibling(edited, 0);
    expect(texts(p.history), originalTexts);
    expect(p.branchInfoOf(p.history.first), (index: 0, count: 2));
  });

  test('cancel edit adds no nodes', () async {
    final p = BranchingProvider(FakeSessionProvider());
    await drain(p.sendMessageStream('a'));
    final full = p.history.toList();
    final before = p.tree.length;
    p.history = full.take(0); // start edit
    expect(p.history, isEmpty);
    p.history = full; // the view puts the same objects back
    expect(p.tree.length, before);
    expect(p.history.length, 2);
    // the next send continues at the end of the conversation
    await drain(p.sendMessageStream('b'));
    expect(texts(p.history), ['a', 'A1: a', 'b', 'A2: b']);
  });

  test('foreign history is migrated as one branch', () {
    final p = BranchingProvider(FakeSessionProvider());
    final saved = [
      ChatMessage.user('q1', const []),
      ChatMessage.llm()..append('a1'),
      ChatMessage.user('q2', const []),
      ChatMessage.llm()..append('a2'),
    ];
    p.history = saved;
    expect(texts(p.history), ['q1', 'a1', 'q2', 'a2']);
    expect(p.tree.length, 4);
    expect(p.tree.activePath.length, 4);
    expect(p.branchInfoOf(saved.first), (index: 0, count: 1));
    // previous tree contents are replaced by the migrated one
    p.history = [ChatMessage.user('other', const []), ChatMessage.llm()];
    expect(p.tree.length, 2);
  });

  test('editing after a switch attaches to the right parent', () async {
    final p = BranchingProvider(FakeSessionProvider());
    await drain(p.sendMessageStream('one'));
    await drain(p.sendMessageStream('two'));
    _startEdit(p);
    await drain(p.sendMessageStream('two b'));
    p.selectSibling(p.history.toList()[2], 0); // back to "two"
    expect(texts(p.history), ['one', 'A1: one', 'two', 'A2: two']);
    await drain(p.sendMessageStream('three'));
    expect(texts(p.history),
        ['one', 'A1: one', 'two', 'A2: two', 'three', 'A4: three']);
    expect(p.tree.length, 8);
  });

  test('switching branches during an edit, then cancelling, keeps versions',
      () async {
    final p = BranchingProvider(FakeSessionProvider());
    await drain(p.sendMessageStream('v1'));
    _startEdit(p);
    await drain(p.sendMessageStream('v2'));
    final firstQuestion = p.history.first;
    expect(p.branchInfoOf(firstQuestion), (index: 1, count: 2));
    // the view keeps the pair it is editing, then starts editing again
    final kept = p.history.toList();
    p.history = const [];
    expect(p.isEditing, isTrue);
    p.selectSibling(p.tree.siblingsOf(p.nodeIdOf(firstQuestion)!)[0].value!, 0);
    expect(p.isEditing, isFalse);
    p.history = [...p.history, ...kept]; // what the view does on cancel
    expect(p.tree.length, 4);
    expect(p.branchInfoOf(kept.first), (index: 1, count: 2));
    expect(texts(p.history), ['v2', 'A2: v2']);
    p.selectSibling(p.history.first, 0);
    expect(texts(p.history), ['v1', 'A1: v1']);
  });

  test('regenerate during an edit, then cancelling, keeps versions', () async {
    final p = BranchingProvider(FakeSessionProvider());
    await drain(p.sendMessageStream('q'));
    final kept = p.history.toList();
    p.history = const []; // edit started
    await drain(p.regenerate(kept.last));
    expect(p.tree.length, 3);
    p.history = [...p.history, ...kept]; // cancel
    expect(p.tree.length, 3);
    expect(p.branchInfoOf(kept.last), (index: 0, count: 2));
    expect(texts(p.history), ['q', 'A1: q']);
  });
}
