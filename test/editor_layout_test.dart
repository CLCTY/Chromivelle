import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/main.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(800, 360)]) {
    testWidgets('Home and tools fit $size with enlarged text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ImageEditorApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('从相册导入'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 200, 150),
        Paint()..color = Colors.green,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 150);
      picture.dispose();
      container.read(editorProvider.notifier).setImage(image);
      await tester.pumpAndSettle();
      for (final tool in ['黑白', '留色', '变换', '调色']) {
        await tester.tap(find.text(tool).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tool at $size');
      }
      await tester.tap(find.text('饱和度').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Slider));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Slider));
      await tester.pumpAndSettle();
      expect(
        container.read(editorProvider).edit.selectiveColor.enabled,
        isFalse,
      );
      await tester.tap(find.byTooltip('返回主页'));
      await tester.pumpAndSettle();
      if (find.text('继续编辑').evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(FilledButton, '返回主页'));
        await tester.pumpAndSettle();
      }
      expect(find.text('从相册导入'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      image.dispose();
    });
  }
}
