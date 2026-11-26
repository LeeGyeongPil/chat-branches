import 'package:chat_branches/chat_branches.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows position and calls onSelect', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_wrap(
      BranchSwitcher(index: 1, count: 3, onSelect: picked.add),
    ));
    expect(find.text('2/3'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous version'));
    await tester.tap(find.byTooltip('Next version'));
    expect(picked, [0, 2]);
  });

  testWidgets('disabled at edges', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_wrap(
      BranchSwitcher(index: 0, count: 2, onSelect: picked.add),
    ));
    await tester.tap(find.byTooltip('Previous version'));
    expect(picked, isEmpty);
    await tester.tap(find.byTooltip('Next version'));
    expect(picked, [1]);

    picked.clear();
    await tester.pumpWidget(_wrap(
      BranchSwitcher(index: 1, count: 2, onSelect: picked.add),
    ));
    await tester.tap(find.byTooltip('Next version'));
    expect(picked, isEmpty);

    await tester.pumpWidget(_wrap(
      BranchSwitcher(index: 1, count: 3, onSelect: picked.add, enabled: false),
    ));
    await tester.tap(find.byTooltip('Previous version'));
    await tester.tap(find.byTooltip('Next version'));
    expect(picked, isEmpty);
  });

  testWidgets('korean labels', (tester) async {
    await tester.pumpWidget(_wrap(
      BranchSwitcher(
        index: 1,
        count: 3,
        onSelect: (_) {},
        labels: BranchSwitcherLabels.ko,
      ),
    ));
    expect(find.byTooltip('이전 버전'), findsOneWidget);
    expect(find.byTooltip('다음 버전'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('custom position text', (tester) async {
    await tester.pumpWidget(_wrap(
      BranchSwitcher(
        index: 0,
        count: 2,
        onSelect: (_) {},
        labels: BranchSwitcherLabels(
          previous: 'p',
          next: 'n',
          position: (i, n) => 'v$i of $n',
        ),
      ),
    ));
    expect(find.text('v1 of 2'), findsOneWidget);
  });
}
