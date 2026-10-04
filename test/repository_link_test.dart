import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/settings/settings_page.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class FakeLauncher extends UrlLauncherPlatform {
  @override
  get linkDelegate => null;

  bool succeeds = true;
  String? url;
  PreferredLaunchMode? mode;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    this.url = url;
    mode = options.mode;
    return succeeds;
  }
}

void main() {
  for (final succeeds in [true, false]) {
    testWidgets(
      'Repository entry opens externally or offers a fallback ($succeeds)',
      (tester) async {
        final previous = UrlLauncherPlatform.instance;
        final launcher = FakeLauncher()..succeeds = succeeds;
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() => UrlLauncherPlatform.instance = previous);
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: SettingsPage())),
        );
        final entry = find.byKey(const ValueKey('setting-repository'));
        await tester.scrollUntilVisible(entry, 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(launcher.url, 'https://github.com/CLCTY/Chromivelle');
        expect(launcher.mode, PreferredLaunchMode.externalApplication);
        expect(find.text('复制链接'), succeeds ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
