# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-11-26

### Added
- `ConversationTree<T>`: pure-Dart conversation tree with sibling versions,
  active path, per-branch last-leaf memory and JSON v1 save/restore
  (`package:chat_branches/tree.dart`).
- `BranchingProvider`: wraps any Flutter AI Toolkit `LlmProvider`; keeps edited
  questions and regenerated answers as branches (`regenerate`, `editAt`,
  `selectSibling`, `branchInfoOf`, `reset`, `toJson`). Every version is kept
  when an edit is cancelled, also after switching branches or regenerating.
- `BranchingProvider.isEditing`: true while the toolkit view edits a question.
- Busy protection: branch changes during streaming throw `BranchBusyException`.
- `BranchSwitcher` widget with English and Korean labels.
- Example app with a practice mock provider, a "Keep branches" switch and an
  English/Korean language menu.
