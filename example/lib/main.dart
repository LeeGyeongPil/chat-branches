import 'dart:ui' as ui;

import 'package:chat_branches/chat_branches.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'branch_bar.dart';
import 'l10n.dart';
import 'practice_provider.dart';

/// Storage key of the chosen language (`en` or `ko`). Screenshots can also
/// open the web build with `?lang=ko`.
const String langKey = 'chat_branches_example.lang';
/// Storage key of the "Keep branches" switch.
const String keepKey = 'chat_branches_example.keep';

/// The texts LlmChatView draws itself (input hint, button tooltips) in [lang].
/// Fields left out keep the toolkit defaults; the toolkit fills them in.
/// Still English in flutter_ai_toolkit 1.0.0 (no setting exists): the
/// "Editing" label above the input and the long-press menu items Edit / Copy.
LlmChatViewStyle chatViewStyle(String lang) => LlmChatViewStyle(
      // 입력창 안내 문구: 툴킷 기본값은 영어 'Ask me anything...'
      chatInputStyle: ChatInputStyle(hintText: tr(lang, 'inputHint')),
      // 아이콘 버튼의 말풍선 도움말(마우스를 올리면 보인다)
      submitButtonStyle: ActionButtonStyle(text: tr(lang, 'sendTooltip')),
      stopButtonStyle: ActionButtonStyle(text: tr(lang, 'stopTooltip')),
      cancelButtonStyle: ActionButtonStyle(text: tr(lang, 'cancelEditTooltip')),
    );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ExampleApp(prefs: prefs));
}

/// The example: a chat view backed by a practice mock, with branches on or off.
class ExampleApp extends StatefulWidget {
  /// Creates the app. [answerDelay] and [onProvider] exist for tests.
  const ExampleApp({
    required this.prefs,
    this.answerDelay = const Duration(milliseconds: 700),
    this.onProvider,
    super.key,
  });

  /// Where the language and the switch are remembered.
  final SharedPreferences prefs;

  /// Pause of the mock before each answer.
  final Duration answerDelay;

  /// Called whenever the active chat provider is (re)created.
  final ValueChanged<LlmProvider>? onProvider;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late String _lang;
  late bool _keep;
  late LlmProvider _provider;

  @override
  void initState() {
    super.initState();
    // Language: ?lang= in the address > saved choice > device language.
    final query = Uri.base.queryParameters['lang'];
    final saved = widget.prefs.getString(langKey);
    final device = ui.PlatformDispatcher.instance.locale.languageCode;
    _lang = [query, saved].firstWhere(
      (l) => supportedLanguages.contains(l),
      orElse: () => device == 'ko' ? 'ko' : 'en',
    )!;
    _keep = widget.prefs.getBool(keepKey) ?? true;
    _provider = _newProvider();
  }

  LlmProvider _newProvider() {
    final mock = PracticeProvider(delay: widget.answerDelay);
    final LlmProvider provider = _keep ? BranchingProvider(mock) : mock;
    widget.onProvider?.call(provider);
    return provider;
  }

  @override
  void dispose() {
    _disposeProvider(_provider);
    super.dispose();
  }

  void _disposeProvider(LlmProvider p) {
    if (p is BranchingProvider) {
      final inner = p.inner;
      p.dispose();
      if (inner is PracticeProvider) inner.dispose();
    } else if (p is PracticeProvider) {
      p.dispose();
    }
  }

  void _setLang(String lang) {
    setState(() => _lang = lang);
    widget.prefs.setString(langKey, lang);
  }

  void _setKeep(bool keep) {
    widget.prefs.setBool(keepKey, keep);
    final old = _provider;
    // Dispose the old provider after the frame that stops using it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _disposeProvider(old);
    });
    setState(() {
      _keep = keep;
      _provider = _newProvider(); // a fresh conversation for each mode
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: tr(_lang, 'appTitle'),
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: Text(tr(_lang, 'appTitle')),
          actions: [
            Text(tr(_lang, 'keepBranches')),
            Switch(
              key: const Key('keep-branches'),
              value: _keep,
              onChanged: _setKeep,
            ),
            PopupMenuButton<String>(
              key: const Key('language-menu'),
              icon: const Icon(Icons.language),
              tooltip: tr(_lang, 'language'),
              onSelected: _setLang,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'en', child: Text('English')),
                PopupMenuItem(value: 'ko', child: Text('한국어')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(8),
              child: Text(tr(_lang, 'mockNotice')),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: provider is BranchingProvider
                  ? BranchBar(provider: provider, lang: _lang)
                  : Text(
                      tr(_lang, 'branchesOffHint'),
                      key: const Key('branches-off-hint'),
                    ),
            ),
            Expanded(
              child: LlmChatView(
                key: ValueKey('chat-$_keep'),
                provider: provider,
                welcomeMessage: tr(_lang, 'welcome'),
                style: chatViewStyle(_lang),
                enableVoiceNotes: false,
                enableAttachments: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
