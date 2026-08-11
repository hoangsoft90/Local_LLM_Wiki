import 'package:agent_wiki/core/util/frontmatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('frontmatter', () {
    test('parses frontmatter and body', () {
      const md = '---\npage_id: abc\ntitle: "Hello World"\n'
          'claim_ids: [c1, c2]\n---\n\n# Body\n\nContent here.';
      final doc = parseFrontmatter(md);
      expect(doc.frontmatter['page_id'], 'abc');
      expect(doc.frontmatter['title'], 'Hello World');
      expect(doc.frontmatter['claim_ids'], ['c1', 'c2']);
      expect(doc.body.trim(), '# Body\n\nContent here.');
    });

    test('no frontmatter → empty map, body unchanged', () {
      const md = '# Just a body';
      final doc = parseFrontmatter(md);
      expect(doc.frontmatter, isEmpty);
      expect(doc.body, md);
    });

    test('render → parse round-trips strings, lists, bools', () {
      const body = '## Summary\n\nSome text.';
      final rendered = renderFrontmatter({
        'page_id': 'p1',
        'title': 'With "quotes" and colon: here',
        'claim_ids': <String>['a', 'b'],
        'deprecated': false,
      }, body);
      final doc = parseFrontmatter(rendered);
      expect(doc.frontmatter['page_id'], 'p1');
      expect(doc.frontmatter['title'], 'With "quotes" and colon: here');
      expect(doc.frontmatter['claim_ids'], ['a', 'b']);
      expect(doc.frontmatter['deprecated'], false);
      expect(doc.body.trim(), body);
    });

    test('unknown keys are preserved', () {
      const md = '---\npage_id: p\ncustom_key: keep-me\n---\n\nbody';
      final doc = parseFrontmatter(md);
      expect(doc.frontmatter['custom_key'], 'keep-me');
    });
  });
}
