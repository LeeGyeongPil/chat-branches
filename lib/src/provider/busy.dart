/// Thrown when a branch change is attempted while an answer is streaming.
///
/// Wait for the stream to finish (or cancel it) and try again.
class BranchBusyException implements Exception {
  /// Creates the exception for the refused [operation].
  const BranchBusyException(this.operation);

  /// Name of the refused operation, for example `selectSibling`.
  final String operation;

  @override
  String toString() => 'BranchBusyException: $operation is not allowed while '
      'an answer is streaming. Wait for the stream to finish or cancel it '
      '(check BranchingProvider.isStreaming).';
}
