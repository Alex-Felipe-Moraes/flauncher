import 'dart:typed_data';

import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

void main() {
  testWidgets('home carousel grows cards and opens the complete app gallery',
      (tester) async {
    final appsService = MockAppsService();
    final settingsService = MockSettingsService();
    when(appsService.getAppBanner(any)).thenAnswer((_) async => Uint8List(0));
    when(appsService.getAppIcon(any)).thenAnswer((_) async => Uint8List(0));
    when(settingsService.showCategoryTitles).thenReturn(true);
    when(settingsService.appHighlightAnimationEnabled).thenReturn(false);

    final applications = List.generate(
      8,
      (index) => App(
        packageName: 'example.app.$index',
        name: 'Example app $index',
        version: '1.0',
        hidden: false,
      ),
    );
    when(appsService.applications).thenReturn(applications);
    final category = Category.withApplications(
      id: 1,
      name: 'TV Applications',
      type: CategoryType.grid,
      applications: applications,
    );
    var openedGallery = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppsService>.value(value: appsService),
          Provider<SettingsService>.value(value: settingsService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CategoryRow(
              category: category,
              applications: applications,
              cardRowHeight: 150,
              onViewAll: () => openedGallery = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(ListView).first, const Offset(-3000, 0));
    await tester.pumpAndSettle();
    expect(find.byType(AppCard), findsWidgets);
    expect(tester.getSize(find.byType(AppCard).first).height, greaterThan(110));
    expect(find.text('Ver todos os apps'), findsOneWidget);
    expect(find.text('Organizar apps'), findsOneWidget);

    await tester.ensureVisible(find.text('Ver todos os apps'));
    await tester.tap(find.text('Ver todos os apps'));
    expect(openedGallery, isTrue);

    await tester.ensureVisible(find.text('Organizar apps'));
    await tester.tap(find.text('Organizar apps'));
    await tester.pumpAndSettle();
    expect(find.text('Organizar TV Applications'), findsOneWidget);
    expect(find.text('APLICATIVOS DISPONÍVEIS'), findsOneWidget);
    expect(find.text('NO CARROSSEL'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });
}
