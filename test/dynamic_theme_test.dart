import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/main.dart';

void main() {
  testWidgets('System palette refresh preserves image and active tool', (
    tester,
  ) async {
    var systemColor = const Color(0xFFAACCEE);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      DynamicColorPlugin.channel,
      (call) async => call.method == 'getCorePalette'
          ? Int32List.fromList(List<int>.filled(65, systemColor.toARGB32()))
          : null,
    );
    addTearDown(
      () =>
          messenger.setMockMethodCallHandler(DynamicColorPlugin.channel, null),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ImageEditorApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primary,
      systemColor,
    );
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.white, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(100, 100);
    picture.dispose();
    container.read(editorProvider.notifier).setImage(image);
    await tester.pumpAndSettle();
    await tester.tap(find.text('留色').last);
    await tester.pumpAndSettle();
    systemColor = const Color(0xFFDDBBEE);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primary,
      systemColor,
    );
    expect(container.read(editorProvider).image, same(image));
    expect(find.text('去色留色'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    image.dispose();
  });
}
