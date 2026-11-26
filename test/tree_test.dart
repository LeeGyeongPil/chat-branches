import 'package:chat_branches/tree.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('append, siblings, position and activePath', () {
    final t = ConversationTree<String>();
    final q1 = t.append(t.rootId, 'q1');
    final a1 = t.append(q1.id, 'a1');
    final a1b = t.append(q1.id, 'a1b');
    expect(t.activeValues, ['q1', 'a1b']);
    expect(t.siblingsOf(a1.id).map((n) => n.value), ['a1', 'a1b']);
    expect(t.positionOf(a1b.id), (index: 1, count: 2));
    expect(t.positionOf(q1.id), (index: 0, count: 1));
    expect(t.pathTo(a1.id).map((n) => n.value), ['q1', 'a1']);
    expect(t.length, 3);
    expect(t.rootId, 'n0');
  });

  test('selectSibling returns to the last visited leaf', () {
    final t = ConversationTree<String>();
    final q1 = t.append(t.rootId, 'q1');
    t.append(q1.id, 'a1');
    final q2 = t.append(q1.id, 'q2'); // sibling of a1 (just for shape)
    t.append(q2.id, 'a2');
    final q2b = t.append(q1.id, 'q2b');
    final a2b = t.append(q2b.id, 'a2b');
    final q3 = t.append(a2b.id, 'q3');
    t.append(q3.id, 'a3');
    expect(t.activeValues, ['q1', 'q2b', 'a2b', 'q3', 'a3']);
    t.selectSibling(q2b.id, 1); // q2
    expect(t.activeValues, ['q1', 'q2', 'a2']);
    t.selectSibling(q2.id, 2); // back to q2b -> remembered leaf a3
    expect(t.activeValues, ['q1', 'q2b', 'a2b', 'q3', 'a3']);
    expect(() => t.selectSibling(q2.id, 9), throwsRangeError);
  });

  test('unknown id throws NodeNotFoundException', () {
    final t = ConversationTree<String>();
    expect(() => t['nope'], throwsA(isA<NodeNotFoundException>()));
    expect(() => t.append('nope', 'x'), throwsA(isA<NodeNotFoundException>()));
    expect(() => t.pathTo('nope'), throwsA(isA<NodeNotFoundException>()));
    expect(
      () => t.select('nope'),
      throwsA(isA<NodeNotFoundException>().having((e) => e.id, 'id', 'nope')),
    );
  });

  test('custom id generator must be unique', () {
    final t = ConversationTree<String>(newId: () => 'same');
    expect(() => t.append(t.rootId, 'x'), throwsArgumentError);
  });
}
