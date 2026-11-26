import 'package:chat_branches/chat_branches.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_session_provider.dart';

void main() {
  test('regenerate adds an answer sibling', () async {
    final inner = FakeSessionProvider();
    final p = BranchingProvider(inner);
    await drain(p.sendMessageStream('q'));
    final question = p.history.first;
    await drain(p.regenerate());
    await drain(p.regenerate());
    final last = p.history.last;
    expect(last.text, 'A3: q');
    expect(p.branchInfoOf(last), (index: 2, count: 3));
    expect(p.branchInfoOf(question), (index: 0, count: 1));
    expect(p.tree.length, 4);
    expect(inner.sent.map((s) => s.prompt), ['q', 'q', 'q']);
    expect(inner.sent.last.context, isEmpty);

    p.selectSibling(last, 0);
    expect(p.history.last.text, 'A1: q');
  });

  test('regenerate with nothing to regenerate explains itself', () {
    final p = BranchingProvider(FakeSessionProvider());
    expect(p.regenerate, throwsA(isA<StateError>()));
  });

  test('editAt in the middle keeps the old subtree', () async {
    final p = BranchingProvider(FakeSessionProvider());
    await drain(p.sendMessageStream('q1'));
    await drain(p.sendMessageStream('q2'));
    await drain(p.sendMessageStream('q3'));
    final path = p.history.toList();
    expect(path.length, 6);
    final firstQuestion = path.first;

    await drain(p.editAt(firstQuestion, 'q1 edited'));
    expect(p.tree.activePath.length, 2);
    expect(p.branchInfoOf(p.history.first), (index: 1, count: 2));
    expect(texts(p.history).first, 'q1 edited');

    p.selectSibling(p.history.first, 0);
    expect(p.history.length, 6);
    expect(identical(p.history.first, firstQuestion), isTrue);
    expect(texts(p.history).last, 'A3: q3');
  });

  test('editAt and regenerate reject foreign messages', () async {
    final p = BranchingProvider(FakeSessionProvider());
    await drain(p.sendMessageStream('q'));
    final stranger = ChatMessage.user('x', const []);
    expect(() => p.editAt(stranger, 'y'), throwsArgumentError);
    expect(() => p.regenerate(stranger), throwsArgumentError);
    expect(() => p.editAt(p.history.last, 'y'), throwsArgumentError);
    expect(() => p.selectSibling(stranger, 0), throwsArgumentError);
    expect(p.branchInfoOf(stranger), isNull);
  });

  test('reset empties the tree', () async {
    final inner = FakeSessionProvider();
    final p = BranchingProvider(inner);
    await drain(p.sendMessageStream('q'));
    p.reset();
    expect(p.history, isEmpty);
    await drain(p.sendMessageStream('again'));
    expect(inner.sent.last.context, isEmpty);
    expect(inner.historySets.last, isEmpty);
  });
}
