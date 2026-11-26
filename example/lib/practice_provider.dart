import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

/// Practice mock: an [EchoProvider] whose answers start with "Take #n" so that
/// regenerated versions are visibly different. No AI model is called.
class PracticeProvider extends EchoProvider {
  /// Creates the mock; [delay] is the pause before each answer.
  PracticeProvider({this.delay = const Duration(milliseconds: 700)});

  /// Pause before the answer, to look like streaming.
  final Duration delay;

  int _take = 0;

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    _take++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    yield 'Take #$_take\n\n';
    yield 'Echo: $prompt';
  }
}
