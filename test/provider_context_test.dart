import 'package:chat_branches/chat_branches.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_session_provider.dart';

void main() {
  test('inner receives the path up to the fork', () async {
    final inner = FakeSessionProvider();
    final p = BranchingProvider(inner);
    await drain(p.sendMessageStream('one'));
    await drain(p.sendMessageStream('two'));
    // edit "two"
    p.history = p.history.toList()..removeLast()..removeLast();
    await drain(p.sendMessageStream('two b'));
    expect(inner.sent.last.prompt, 'two b');
    expect(inner.sent.last.context, ['one', 'A1: one']);

    // switch to the old branch and ask a new question there
    p.selectSibling(p.history.toList()[2], 0);
    await drain(p.sendMessageStream('three'));
    expect(inner.sent.last.context, ['one', 'A1: one', 'two', 'A2: two']);

    // regenerating sends the question again with the context before it
    await drain(p.regenerate());
    expect(inner.sent.last.prompt, 'three');
    expect(inner.sent.last.context, ['one', 'A1: one', 'two', 'A2: two']);
  });

  test('continuing on the tip does not reset inner history', () async {
    final inner = FakeSessionProvider();
    final p = BranchingProvider(inner);
    await drain(p.sendMessageStream('one'));
    await drain(p.sendMessageStream('two'));
    await drain(p.sendMessageStream('three'));
    expect(inner.historySets, isEmpty);
    expect(inner.sent.last.context, ['one', 'A1: one', 'two', 'A2: two']);
  });

  test('a restored tree makes the first send set inner history once', () async {
    final src = BranchingProvider(FakeSessionProvider());
    await drain(src.sendMessageStream('one'));
    final inner = FakeSessionProvider();
    final p = BranchingProvider(inner, tree: BranchingProvider.treeFromJson(src.toJson()));
    await drain(p.sendMessageStream('two'));
    expect(inner.historySets.length, 1);
    expect(inner.sent.last.context, ['one', 'A1: one']);
    await drain(p.sendMessageStream('three'));
    expect(inner.historySets.length, 1);
  });

  test('wrapping an inner provider that already has history adopts it', () async {
    final inner = FakeSessionProvider();
    await drain(inner.sendMessageStream('old'));
    final p = BranchingProvider(inner);
    expect(texts(p.history), ['old', 'A1: old']);
    await drain(p.sendMessageStream('new'));
    expect(inner.historySets, isEmpty);
    expect(texts(p.history), ['old', 'A1: old', 'new', 'A2: new']);
  });
}
