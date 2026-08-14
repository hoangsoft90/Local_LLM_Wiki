import 'package:agent_wiki/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deep-link route parsing (no dead ends)', () {
    test('page deep links resolve the page id (with/without leading slash)', () {
      expect(deepLinkPageId('/page/abc123'), 'abc123');
      expect(deepLinkPageId('page/abc123'), 'abc123');
      expect(deepLinkPageId('/page/'), isNull, reason: 'empty id → no link');
    });

    test('URL-encoded ids are decoded', () {
      expect(deepLinkPageId('/page/hello%20world'), 'hello world');
    });

    test('non-page paths return null (fall back to home, never crash)', () {
      expect(deepLinkPageId('/'), isNull);
      expect(deepLinkPageId(''), isNull);
      expect(deepLinkPageId('/settings'), isNull);
      expect(deepLinkPageId('/page'), isNull);
      expect(deepLinkPageId('page/'), isNull);
      expect(deepLinkPageId('random/path/here'), isNull);
    });
  });

  group('buildAppRoute contract (the app never dead-ends on any route name)', () {
    test('every possible route name resolves to a non-null route', () {
      // The app has NO named routes — before the fallback, any non-`/` name
      // (web URL, deep link, reload) crashed the router. Assert the contract:
      // unknown paths AND page deep links both produce a route.
      for (final name in ['/page/abc123', '/nope', '/settings', 'x/y', '/']) {
        final route = buildAppRoute(RouteSettings(name: name));
        expect(route, isNotNull, reason: 'route name "$name" must never 404');
        expect(route!.settings.name, name);
      }
    });
  });
}
