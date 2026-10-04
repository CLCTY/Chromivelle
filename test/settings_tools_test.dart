import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/main.dart';
import 'package:image_editor/settings/editor_settings.dart';
import 'package:image_editor/core/shader/preview_transform.dart';
import 'package:image_editor/data/model/edit_command.dart';

class MemorySettingsStore implements SettingsStore {
  String? saved;
  @override
  Future<EditorSettings> load() async => EditorSettings.decode(saved);
  @override
  Future<void> save(EditorSettings settings) async {
    saved = settings.encode();
  }
}

void main() {
  test('Tool choices persist and at least one tool remains enabled', () async {
    final store = MemorySettingsStore();
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final ctrl = container.read(settingsProvider.notifier);
    for (final tool in EditorTool.values.skip(1)) {
      await ctrl.setTool(tool, false);
    }
    expect((await store.load()).visibleTools, [EditorTool.adjust]);
    expect(() => ctrl.setTool(EditorTool.adjust, false), throwsStateError);
    await ctrl.update(
      container
          .read(settingsProvider)
          .copyWith(dynamicColor: false, animations: false),
    );
    final reloaded = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(await store.load()),
      ],
    );
    addTearDown(reloaded.dispose);
    expect(reloaded.read(settingsProvider).visibleTools, [EditorTool.adjust]);
    expect(reloaded.read(settingsProvider).dynamicColor, isFalse);
    expect(reloaded.read(settingsProvider).animations, isFalse);
    expect(EditorSettings.decode('{broken').visibleTools.length, 7);
  });

  test(
    'Rotated and mirrored previews keep picking in original pixel coordinates',
    () {
      const image = Size(400, 200), viewport = Size(300, 500);
      final rotated = PreviewTransform.matrix(
        viewport: viewport,
        image: image,
        geometry: GeometryTransform(rotation: math.pi / 2),
      );
      final origin = MatrixUtils.transformPoint(rotated, Offset.zero);
      expect(origin.dx, closeTo(275, .001));
      expect(origin.dy, closeTo(0, .001));
      const target = Offset(120, 60);
      for (final g in [
        const GeometryTransform(flipHorizontal: true),
        const GeometryTransform(flipVertical: true),
        GeometryTransform(rotation: math.pi / 2, flipHorizontal: true),
      ]) {
        final transform = PreviewTransform.matrix(
          viewport: viewport,
          image: image,
          geometry: g,
          zoom: 2,
          pan: const Offset(12, -20),
        );
        final picked = PreviewTransform.pixelAt(
          MatrixUtils.transformPoint(transform, target),
          transform,
          image,
        )!;
        expect(picked.dx, closeTo(target.dx, .001));
        expect(picked.dy, closeTo(target.dy, .001));
      }
      expect(
        PreviewTransform.pixelAt(const Offset(-200, -200), rotated, image),
        isNull,
      );
    },
  );

  testWidgets(
    'Four tools fit; swipe reveals extras; settings hide current tool',
    (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemorySettingsStore();
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ImageEditorApp(),
        ),
      );
      await tester.pumpAndSettle();
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.white, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 200);
      picture.dispose();
      container.read(editorProvider.notifier).setImage(image);
      await tester.pumpAndSettle();
      final bar = find.byKey(const PageStorageKey('editor-tool-bar'));
      final width = tester.getSize(bar).width;
      for (final tool in EditorTool.values.take(4)) {
        final rect = tester.getRect(find.byKey(ValueKey('tool-${tool.name}')));
        expect(rect.width, closeTo(width / 4 - 6, .001));
        expect(rect.right, lessThanOrEqualTo(tester.getRect(bar).right));
      }
      await tester.drag(bar, const Offset(-320, 0));
      await tester.pumpAndSettle();
      for (final tool in [
        EditorTool.whiteBalance,
        EditorTool.hsl,
        EditorTool.looks,
      ]) {
        await tester.tap(find.byKey(ValueKey('tool-${tool.name}')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final strengthRect = tester.getRect(find.byType(Slider));
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      for (final name in ['清透', '暖阳', '原色', '暖阳']) {
        await tester.tap(find.text(name));
        for (final time in [0, 16, 64, 120, 240]) {
          await tester.pump(Duration(milliseconds: time));
          expect(
            tester.getRect(find.byType(Slider)),
            strengthRect,
            reason: 'The strength bar must stay in place while switching $name',
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpAndSettle();
      }
      await tester.tapAt(
        Offset(
          strengthRect.left + strengthRect.width * .35,
          strengthRect.center.dy,
        ),
      );
      await tester.pumpAndSettle();
      final strength = tester.widget<Slider>(find.byType(Slider)).value;
      expect(strength, greaterThan(0));
      expect(strength, lessThan(1));
      await tester.tap(find.text('清透'));
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(find.byType(Slider)).value, strength);
      await tester.tap(find.text('暖阳'));
      await tester.pumpAndSettle();
      expect(
        container.read(editorProvider).edit.adjust.temperature,
        greaterThan(0),
      );
      final looks = find.byKey(const PageStorageKey('look-strip'));
      expect(tester.widget<ListView>(looks).scrollDirection, Axis.horizontal);
      await tester.drag(looks, const Offset(-1900, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('低饱和'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(Slider)), strengthRect);
      expect(tester.widget<Slider>(find.byType(Slider)).value, strength);
      expect(
        container.read(editorProvider).edit.adjust.saturation,
        lessThan(0),
      );
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      final tile = find.byKey(const ValueKey('setting-looks'));
      await tester.scrollUntilVisible(tile, 200);
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();
      expect(
        (await store.load()).enabledTools,
        isNot(contains(EditorTool.looks)),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tool-looks')), findsNothing);
      expect(
        container.read(editorProvider).edit.adjust.saturation,
        lessThan(0),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      image.dispose();
    },
  );
}
