import 'package:chat_branches/chat_branches.dart';
import 'package:chat_branches_example/l10n.dart';
import 'package:chat_branches_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LlmProvider> _pump(
  WidgetTester tester, {
  Map<String, Object> stored = const {},
  SharedPreferences? prefs,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final p = prefs ?? await SharedPreferences.getInstance();
  await tester.pumpWidget(ExampleApp(
    prefs: p,
    answerDelay: Duration.zero,
    onProvider: (provider) => _last = provider,
  ));
  await tester.pump();
  return _last!;
}

/// The hint of the chat input field that LlmChatView draws.
String? inputHint(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration?.hintText;

/// Replays what LlmChatView does when the user edits the last question.
Future<void> _editLastQuestion(
  WidgetTester tester,
  LlmProvider p,
  String text,
) async {
  p.history = p.history.toList()..removeLast()..removeLast();
  await tester.runAsync(() => p.sendMessageStream(text).drain<void>());
  await tester.pump();
}

void main() {
  test('en and ko have the same keys', () {
    expect(messages.keys.toSet(), supportedLanguages.toSet());
    expect(messages['en']!.keys.toSet(), messages['ko']!.keys.toSet());
    for (final lang in supportedLanguages) {
      for (final entry in messages[lang]!.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: '$lang.${entry.key}');
      }
    }
  });

  testWidgets('language choice is applied and persisted', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Practice mock'), findsOneWidget);
    expect(find.text('Regenerate'), findsOneWidget);
    expect(inputHint(tester), 'Ask me anything...');

    await tester.tap(find.byKey(const Key('language-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('한국어'));
    await tester.pumpAndSettle();
    expect(find.textContaining('연습용 목'), findsOneWidget);
    expect(find.text('갈래 유지'), findsOneWidget, reason: 'switch label');
    // The input hint drawn by LlmChatView follows the language too.
    expect(inputHint(tester), '무엇이든 물어보세요...');
    expect(find.text('무엇이든 물어보세요...'), findsOneWidget);
    expect(find.text('Ask me anything...'), findsNothing);

    // A new start reads the saved choice (device language is not Korean).
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(langKey), 'ko');
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, prefs: prefs);
    expect(find.textContaining('연습용 목'), findsOneWidget);
    expect(inputHint(tester), '무엇이든 물어보세요...');
  });

  test('toolkit texts come from the message table', () {
    for (final lang in supportedLanguages) {
      final style = chatViewStyle(lang);
      expect(style.chatInputStyle!.hintText, tr(lang, 'inputHint'));
      expect(style.submitButtonStyle!.text, tr(lang, 'sendTooltip'));
      expect(style.stopButtonStyle!.text, tr(lang, 'stopTooltip'));
      expect(style.cancelButtonStyle!.text, tr(lang, 'cancelEditTooltip'));
    }
    // English keeps the toolkit's own wording; Korean replaces it.
    final toolkit = LlmChatViewStyle.defaultStyle();
    expect(tr('en', 'inputHint'), toolkit.chatInputStyle!.hintText);
    expect(tr('ko', 'inputHint'), isNot(toolkit.chatInputStyle!.hintText));
  });

  testWidgets('first start uses English when the device is not Korean',
      (tester) async {
    await _pump(tester);
    expect(find.text('Keep branches'), findsOneWidget);
  });

  testWidgets('bar texts follow the language', (tester) async {
    final p = await _pump(tester, stored: {langKey: 'ko'}) as BranchingProvider;
    await tester.runAsync(() => p.sendMessageStream('안녕').drain<void>());
    await tester.pump();
    expect(find.text('다시 만들기'), findsOneWidget);
    expect(find.text('질문'), findsOneWidget);
    expect(find.text('JSON 내보내기'), findsOneWidget);
    expect(find.byTooltip('이전 버전'), findsWidgets);
  });

  testWidgets('branches off vs on', (tester) async {
    // On: after an edit the question shows version 2/2.
    final on = await _pump(tester) as BranchingProvider;
    await tester.runAsync(() => on.sendMessageStream('first').drain<void>());
    await tester.pump();
    expect(find.text('2/2'), findsNothing);
    await _editLastQuestion(tester, on, 'first (edited)');
    expect(find.text('2/2'), findsWidgets); // question and the new answer?
    await tester.tap(find.byTooltip('Previous version').first);
    await tester.pump();
    expect(on.history.first.text, 'first');

    // Off: the old pair is gone and no switcher exists.
    await tester.tap(find.byKey(const Key('keep-branches')));
    await tester.pumpAndSettle();
    final off = _last!;
    expect(off, isNot(isA<BranchingProvider>()));
    expect(find.byKey(const Key('branches-off-hint')), findsOneWidget);
    await tester.runAsync(() => off.sendMessageStream('first').drain<void>());
    await _editLastQuestion(tester, off, 'first (edited)');
    expect(off.history.map((m) => m.text).any((t) => t == 'first'), isFalse);
    expect(find.text('2/2'), findsNothing);

    // Switching back on starts a fresh tree.
    await tester.tap(find.byKey(const Key('keep-branches')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('branches-off-hint')), findsNothing);
  });

  testWidgets('regenerate and export work from the bar', (tester) async {
    final p = await _pump(tester) as BranchingProvider;
    await tester.runAsync(() => p.sendMessageStream('q').drain<void>());
    await tester.pump();
    await tester.tap(find.byKey(const Key('regenerate')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(p.tree.length, 3);
    expect(p.history.last.text, contains('Take #2'));

    await tester.tap(find.byKey(const Key('export')));
    await tester.pumpAndSettle();
    expect(find.textContaining('"format": "chat_branches"'), findsOneWidget);
  });
}

/// The provider the app created most recently (set by the onProvider hook).
LlmProvider? _last;
