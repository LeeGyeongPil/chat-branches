/// Texts used by `BranchSwitcher`. Pass your own for other languages.
class BranchSwitcherLabels {
  /// Creates custom labels.
  const BranchSwitcherLabels({
    required this.previous,
    required this.next,
    required this.position,
  });

  /// English labels.
  static const BranchSwitcherLabels en = BranchSwitcherLabels(
    previous: 'Previous version',
    next: 'Next version',
    position: _plain,
  );

  /// Korean labels.
  static const BranchSwitcherLabels ko = BranchSwitcherLabels(
    previous: '이전 버전',
    next: '다음 버전',
    position: _plain,
  );

  /// Tooltip of the "previous" button.
  final String previous;

  /// Tooltip of the "next" button.
  final String next;

  /// Text between the buttons; [i] is one-based, [n] the number of versions.
  final String Function(int i, int n) position;

  static String _plain(int i, int n) => '$i/$n';
}
