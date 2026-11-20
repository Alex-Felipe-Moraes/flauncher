import 'package:flauncher/database.dart';
import 'package:flauncher/models/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FLauncherDatabase database;

  setUp(() {
    database = FLauncherDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  test('replaces carousel apps in order without changing other categories',
      () async {
    await database.customInsert(
      "INSERT INTO apps(package_name, name, version) VALUES"
      "('app.a', 'App A', '1'), ('app.b', 'App B', '1'),"
      "('app.c', 'App C', '1');",
    );
    final categoryId = await database.customInsert(
      "INSERT INTO categories(name, sort, 'order') VALUES('Home', 1, 0);",
    );
    final otherCategoryId = await database.customInsert(
      "INSERT INTO categories(name, 'order') VALUES('Other', 1);",
    );
    await database.customInsert(
      "INSERT INTO apps_categories(category_id, app_package_name, 'order')"
      " VALUES($categoryId, 'app.a', 0), ($categoryId, 'app.b', 1),"
      "($otherCategoryId, 'app.c', 0);",
    );

    await database.replaceCategoryApplications(categoryId, ['app.c', 'app.b']);

    final selectedApps = await database
        .customSelect(
          'SELECT app_package_name, "order" FROM apps_categories '
          'WHERE category_id = $categoryId ORDER BY "order";',
        )
        .get();
    expect(
      selectedApps.map((row) => row.read<String>('app_package_name')).toList(),
      ['app.c', 'app.b'],
    );
    expect(
      selectedApps.map((row) => row.read<int>('order')).toList(),
      [0, 1],
    );

    final updatedCategory = await database
        .customSelect(
          'SELECT sort FROM categories WHERE id = $categoryId;',
        )
        .getSingle();
    expect(updatedCategory.read<int>('sort'), CategorySort.manual.index);

    final otherCategoryApps = await database
        .customSelect(
          'SELECT app_package_name FROM apps_categories '
          'WHERE category_id = $otherCategoryId;',
        )
        .get();
    expect(otherCategoryApps, hasLength(1));
    expect(otherCategoryApps.single.read<String>('app_package_name'), 'app.c');
  });
}
