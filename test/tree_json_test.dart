import 'dart:convert';
import 'dart:typed_data';

import 'package:chat_branches/chat_branches.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _enc(String s) => {'t': s};
String _dec(Object? o) => (o! as Map<Object?, Object?>)['t']! as String;

ConversationTree<String> _sample() {
  final t = ConversationTree<String>();
  final q = t.append(t.rootId, 'q');
  t.append(q.id, 'a1');
  t.append(q.id, 'a2');
  final q2 = t.append(t.rootId, 'q-edited');
  t.append(q2.id, 'b');
  t.selectSibling(q.id, 0); // active on q, a2
  return t;
}

void main() {
  test('round trip keeps branches and active path', () {
    final t = _sample();
    final json = jsonDecode(jsonEncode(t.toJson(encode: _enc)))
        as Map<String, Object?>;
    final back = ConversationTree<String>.fromJson(json, decode: _dec);
    expect(back.activeValues, t.activeValues);
    expect(back.length, t.length);
    for (final n in t.nodes) {
      expect(back[n.id].parentId, n.parentId);
      expect(back[n.id].childIds, n.childIds);
      expect(back[n.id].activeChildIndex, n.activeChildIndex);
      expect(back[n.id].value, n.value);
    }
    // New ids continue after the highest restored id.
    final fresh = back.append(back.rootId, 'new');
    expect(t.nodes.map((n) => n.id), isNot(contains(fresh.id)));
    expect(fresh.id, 'n${t.length + 1}');
  });

  test('ChatMessage round trip keeps text and attachments', () {
    final p = BranchingProvider(_Noop());
    final tree = p.tree;
    final u = tree.append(
      tree.rootId,
      ChatMessage.user('hi', [
        FileAttachment.fileOrImage(
          name: 'a.txt',
          mimeType: 'text/plain',
          bytes: Uint8List.fromList(utf8.encode('hello')),
        ),
        LinkAttachment(name: 'site', url: Uri.parse('https://example.com/x')),
      ]),
    );
    tree.append(u.id, ChatMessage.llm()); // unfinished answer: text is null
    final text = jsonEncode(p.toJson());
    final back = BranchingProvider.treeFromJson(
      jsonDecode(text) as Map<String, Object?>,
    );
    final user = back.activeValues.first;
    expect(user.text, 'hi');
    expect(user.attachments.length, 2);
    expect(user.attachments.first.name, 'a.txt');
    expect((user.attachments.last as LinkAttachment).url.toString(),
        'https://example.com/x');
    expect(back.activeValues.last.text, '');
  });

  test('fromLinear builds a single branch', () {
    final t = ConversationTree<String>.fromLinear(['a', 'b', 'c', 'd']);
    expect(t.activePath.length, 4);
    expect(t.pathTo(t.activePath.last.id).length, 4);
    expect(t.nodes.every((n) => n.childIds.length <= 1), isTrue);
    expect(t.activeValues, ['a', 'b', 'c', 'd']);
  });

  group('invalid documents', () {
    Map<String, Object?> good() =>
        jsonDecode(jsonEncode(_sample().toJson(encode: _enc)))
            as Map<String, Object?>;

    void expectField(Map<String, Object?> doc, String field) {
      expect(
        () => ConversationTree<String>.fromJson(doc, decode: _dec),
        throwsA(
          isA<TreeFormatException>()
              .having((e) => e.field, 'field', field)
              .having((e) => e.message, 'message', contains(field)),
        ),
      );
    }

    test('rejects a foreign format', () {
      expectField(good()..['format'] = 'other', 'format');
    });

    test('rejects version 2 with TreeFormatException', () {
      expectField(good()..['version'] = 2, 'version');
    });

    test('rejects a missing child reference', () {
      final doc = good();
      final nodes = doc['nodes']! as List<Object?>;
      (nodes[0]! as Map<String, Object?>)['children'] = ['n1', 'zzz'];
      expect(
        () => ConversationTree<String>.fromJson(doc, decode: _dec),
        throwsA(isA<TreeFormatException>()
            .having((e) => e.message, 'message', contains('zzz'))),
      );
    });

    test('rejects an out-of-range active index', () {
      final doc = good();
      final nodes = doc['nodes']! as List<Object?>;
      (nodes[0]! as Map<String, Object?>)['active'] = 7;
      expectField(doc, 'nodes[0].active');
    });

    test('rejects a parent that does not list the child', () {
      final doc = good();
      final nodes = doc['nodes']! as List<Object?>;
      (nodes[1]! as Map<String, Object?>)['parent'] = 'n4';
      expect(
        () => ConversationTree<String>.fromJson(doc, decode: _dec),
        throwsA(isA<TreeFormatException>()),
      );
    });

    test('rejects a value that cannot be decoded', () {
      final doc = good();
      final nodes = doc['nodes']! as List<Object?>;
      (nodes[1]! as Map<String, Object?>)['value'] = 5;
      expectField(doc, 'nodes[1].value');
    });
  });
}

class _Noop extends EchoProvider {}
