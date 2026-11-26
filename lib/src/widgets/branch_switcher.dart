import 'package:flutter/material.dart';

import 'branch_labels.dart';

/// A compact "< 2/3 >" control for flipping between sibling versions.
///
/// [index] is zero-based. The buttons are disabled at the first and last
/// version and whenever [enabled] is false (for example while streaming).
class BranchSwitcher extends StatelessWidget {
  /// Creates the control.
  const BranchSwitcher({
    required this.index,
    required this.count,
    required this.onSelect,
    this.enabled = true,
    this.labels = BranchSwitcherLabels.en,
    super.key,
  });

  /// Zero-based index of the shown version.
  final int index;

  /// Number of versions.
  final int count;

  /// Called with the zero-based index of the version to show.
  final ValueChanged<int> onSelect;

  /// Whether the buttons react to taps.
  final bool enabled;

  /// Tooltips and position text.
  final BranchSwitcherLabels labels;

  @override
  Widget build(BuildContext context) {
    final canPrevious = enabled && index > 0;
    final canNext = enabled && index < count - 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: labels.previous,
          visualDensity: VisualDensity.compact,
          onPressed: canPrevious ? () => onSelect(index - 1) : null,
        ),
        Text(labels.position(index + 1, count)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: labels.next,
          visualDensity: VisualDensity.compact,
          onPressed: canNext ? () => onSelect(index + 1) : null,
        ),
      ],
    );
  }
}
