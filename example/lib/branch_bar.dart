import 'dart:async';
import 'dart:convert';

import 'package:chat_branches/chat_branches.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

import 'l10n.dart';

/// The bar above the chat: version switchers for the last question and answer,
/// Regenerate and Export JSON.
class BranchBar extends StatelessWidget {
  /// Creates the bar for [provider] in language [lang].
  const BranchBar({required this.provider, required this.lang, super.key});

  /// The branching provider shown in the chat view.
  final BranchingProvider provider;

  /// Language code, a key of `messages`.
  final String lang;

  @override
  Widget build(BuildContext context) {
    final labels =
        lang == 'ko' ? BranchSwitcherLabels.ko : BranchSwitcherLabels.en;
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final path = provider.tree.activePath;
        final question = path.where((n) => n.value!.origin.isUser).lastOrNull;
        final answer =
            path.isNotEmpty && path.last.value!.origin.isLlm ? path.last : null;
        // Switching and regenerating are off while streaming or while the chat view
        // is editing a question.
        final busy = provider.isStreaming || provider.isEditing;
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            if (question != null)
              _switcher(tr(lang, 'question'), question.value!, labels, busy),
            if (answer != null)
              _switcher(tr(lang, 'answer'), answer.value!, labels, busy),
            TextButton.icon(
              key: const Key('regenerate'),
              icon: const Icon(Icons.refresh),
              label: Text(tr(lang, 'regenerate')),
              onPressed: answer == null || busy
                  ? null
                  : () => unawaited(provider.regenerate().drain<void>()),
            ),
            TextButton.icon(
              key: const Key('export'),
              icon: const Icon(Icons.data_object),
              label: Text(tr(lang, 'exportJson')),
              onPressed: () => _export(context),
            ),
          ],
        );
      },
    );
  }

  Widget _switcher(
    String title,
    ChatMessage message,
    BranchSwitcherLabels labels,
    bool busy,
  ) {
    final info = provider.branchInfoOf(message)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        BranchSwitcher(
          index: info.index,
          count: info.count,
          enabled: !busy,
          labels: labels,
          onSelect: (i) => provider.selectSibling(message, i),
        ),
      ],
    );
  }

  void _export(BuildContext context) {
    final text = const JsonEncoder.withIndent('  ').convert(provider.toJson());
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(lang, 'exportTitle')),
          content: SingleChildScrollView(child: SelectableText(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr(lang, 'close')),
            ),
          ],
        ),
      ),
    );
  }
}
