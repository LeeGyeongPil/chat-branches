import 'dart:async';

import 'package:chat_branches/chat_branches.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_session_provider.dart';

void main() {
  test('switching while streaming throws BranchBusyException', () async {
    final inner = FakeSessionProvider();
    final p = BranchingProvider(inner);
    await drain(p.sendMessageStream('q'));
    await drain(p.regenerate());

    inner.gate = Completer<void>();
    final stream = p.regenerate();
    final done = drain(stream);
    expect(p.isStreaming, isTrue);
    final msg = p.history.last;
    expect(() => p.selectSibling(msg, 0), throwsA(isA<BranchBusyException>()));
    expect(() => p.editAt(p.history.first, 'x'),
        throwsA(isA<BranchBusyException>()));
    expect(p.regenerate, throwsA(isA<BranchBusyException>()));
    expect(() => p.history = const [], throwsA(isA<BranchBusyException>()));
    expect(p.reset, throwsA(isA<BranchBusyException>()));

    inner.gate!.complete();
    await done;
    expect(p.isStreaming, isFalse);
    p.selectSibling(p.history.last, 0); // allowed again
  });

  test('cancel keeps partial answer and clears busy', () async {
    final inner = FakeSessionProvider()
      ..failWith = const LlmCancelException();
    final p = BranchingProvider(inner);
    final error = await drain(p.sendMessageStream('q'));
    expect(error, isA<LlmCancelException>());
    expect(p.isStreaming, isFalse);
    expect(texts(p.history), ['q', 'A1: ']); // user node + partial answer
    expect(p.tree.length, 2);

    inner.failWith = null;
    await drain(p.sendMessageStream('next'));
    // the next exchange hangs below the partial answer, not elsewhere
    expect(texts(p.history), ['q', 'A1: ', 'next', 'A2: next']);
    expect(p.tree.length, 4);
    // inner is re-synced after a failure
    expect(inner.historySets.last, ['q', 'A1: ']);
  });

  test('a failure clears busy as well', () async {
    final inner = FakeSessionProvider()
      ..failWith = const LlmFailureException('boom');
    final p = BranchingProvider(inner);
    expect(await drain(p.sendMessageStream('q')),
        isA<LlmFailureException>());
    expect(p.isStreaming, isFalse);
  });

  test('cancelling the subscription clears busy', () async {
    final inner = FakeSessionProvider()..gate = Completer<void>();
    final p = BranchingProvider(inner);
    final sub = p.sendMessageStream('q').listen((_) {});
    expect(p.isStreaming, isTrue);
    await sub.cancel();
    expect(p.isStreaming, isFalse);
  });
}
