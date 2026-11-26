// Keep in sync with the Quick start in README.md.
import 'dart:convert';

import 'package:chat_branches/chat_branches.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('README quick start', () async {
    // 1. Wrap the provider you already use.
    final provider = BranchingProvider(EchoProvider());

    await provider.sendMessageStream('Plan a 3-day trip to Busan').drain<void>();

    // 2. The chat view does this when the user edits the last question:
    //    it shortens the history, then sends the new text.
    provider.history = provider.history.take(0);
    await provider.sendMessageStream('Plan a 2-day trip to Busan').drain<void>();

    // 3. The question now has two versions; flip back to the first.
    final question = provider.history.first;
    final info = provider.branchInfoOf(question)!;
    expect('${info.index + 1}/${info.count}', '2/2');
    provider.selectSibling(question, 0);
    expect(provider.history.first.text, 'Plan a 3-day trip to Busan');

    // 4. Save and restore.
    final saved = jsonEncode(provider.toJson());
    final restored = BranchingProvider(
      EchoProvider(),
      tree: BranchingProvider.treeFromJson(
        jsonDecode(saved) as Map<String, Object?>,
      ),
    );
    expect(restored.history.first.text, 'Plan a 3-day trip to Busan');
    expect(restored.tree.length, provider.tree.length);
  });
}
