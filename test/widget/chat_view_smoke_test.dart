import 'package:chat_branches/chat_branches.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LlmChatView renders echoed reply through BranchingProvider',
      (tester) async {
    final provider = BranchingProvider(EchoProvider());
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LlmChatView(provider: provider))),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'hello branches');
    await tester.pump();
    // Submit with the keyboard action, as a user pressing "enter" would.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    // EchoProvider waits ~2 s before answering.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(provider.tree.length, 2);
    expect(provider.history.last.text, contains('hello branches'));
    expect(find.textContaining('Echo', findRichText: true), findsWidgets);
    expect(find.textContaining('hello branches', findRichText: true), findsWidgets);
  });
}
