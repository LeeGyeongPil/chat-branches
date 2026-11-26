/// All screen texts in one place. Both languages must have the same keys
/// (checked by a test).
const Map<String, Map<String, String>> messages = {
  'en': {
    'appTitle': 'chat_branches example',
    'mockNotice':
        'Practice mock - echoes your prompt, no AI model is called.',
    'keepBranches': 'Keep branches',
    'branchesOffHint':
        'Branches are off: editing a question replaces the old pair.',
    'language': 'Language',
    'question': 'Question',
    'answer': 'Answer',
    'regenerate': 'Regenerate',
    'exportJson': 'Export JSON',
    'exportTitle': 'Conversation tree (JSON)',
    'close': 'Close',
    'welcome':
        'Send a message, press the edit icon on your last message, then use '
        'the Question < n/m > control to get the first version back.',
    // Texts drawn by LlmChatView itself, passed in through LlmChatViewStyle.
    'inputHint': 'Ask me anything...',
    'sendTooltip': 'Submit Message',
    'stopTooltip': 'Stop',
    'cancelEditTooltip': 'Cancel',
  },
  'ko': {
    'appTitle': 'chat_branches 예제',
    'mockNotice': '연습용 목 - 입력을 되돌려 줄 뿐 AI 모델을 부르지 않습니다.',
    'keepBranches': '갈래 유지',
    'branchesOffHint': '갈래가 꺼져 있습니다: 질문을 고치면 이전 질문·답변 쌍이 사라집니다.',
    'language': '언어',
    'question': '질문',
    'answer': '답변',
    'regenerate': '다시 만들기',
    'exportJson': 'JSON 내보내기',
    'exportTitle': '대화 트리 (JSON)',
    'close': '닫기',
    'welcome': '메시지를 보낸 뒤 마지막 메시지의 편집 아이콘으로 고쳐 보세요. '
        '질문 < n/m > 컨트롤로 처음 버전으로 돌아올 수 있습니다.',
    // LlmChatView 가 직접 그리는 문구 (LlmChatViewStyle 로 넘긴다)
    'inputHint': '무엇이든 물어보세요...',
    'sendTooltip': '메시지 보내기',
    'stopTooltip': '멈추기',
    'cancelEditTooltip': '편집 취소',
  },
};

/// The language codes the example supports.
const List<String> supportedLanguages = ['en', 'ko'];

/// Looks up [key] in [lang]; falls back to English.
String tr(String lang, String key) =>
    messages[lang]?[key] ?? messages['en']![key]!;
