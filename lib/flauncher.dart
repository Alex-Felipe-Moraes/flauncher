/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';

import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/providers/wikimedia_featured_image_service.dart';
import 'package:flauncher/widgets/apps_grid.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import 'models/app.dart';
import 'models/category.dart';

class FLauncher extends StatefulWidget {
  const FLauncher();

  @override
  State<FLauncher> createState() => _FLauncherState();
}

class _FLauncherState extends State<FLauncher> {
  static const double _featuredPanelHeightFactor = 0.40;
  static const double _featuredPanelMinHeight = 250;
  static const double _featuredPanelMaxHeight = 380;
  static const int _homeAppCardHeight = 125;

  bool _gallerySelected = false;
  final ValueNotifier<String?> _focusedApplicationName =
      ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          context
              .read<WikimediaFeaturedImageService?>()
              ?.loadFeaturedImageForStartup(),
        );
      }
    });
  }

  @override
  void dispose() {
    _focusedApplicationName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
      policy: RowByRowTraversalPolicy(),
      child: Stack(children: [
        Consumer<WallpaperService>(
            builder: (_, wallpaperService, __) =>
                _wallpaper(context, wallpaperService)),
        Consumer<LauncherState>(
            builder: (_, state, child) => Visibility(
                child: child!,
                replacement: const Center(child: AlternativeLauncherView()),
                visible: state.launcherVisible),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: FocusAwareAppBar(
                gallerySelected: _gallerySelected,
                onPageSelected: (gallerySelected) {
                  setState(() => _gallerySelected = gallerySelected);
                },
              ),
              body: Consumer<AppsService>(
                builder: (context, appsService, _) {
                  if (!appsService.initialized) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _emptyState(context),
                    );
                  }

                  final sections = appsService.launcherSections;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!_gallerySelected) ...[
                                  _featuredPanel(context),
                                  const SizedBox(height: 8),
                                  _sections(sections),
                                ] else
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: _gallery(
                                      context,
                                      appsService.applications,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ))
      ]));

  Widget _sections(List<LauncherSection> sections) => Column(
        children: sections.map((section) {
          final Widget categoryWidget;

          if (section is LauncherSpacer) {
            return SizedBox(
                key: Key(section.id.toString()),
                height: section.height.toDouble());
          }

          Category category = section as Category;
          categoryWidget = CategoryRow(
            category: category,
            applications: category.applications
                .take(Category.maxHomeApplications)
                .toList(growable: false),
            cardRowHeight: _homeAppCardHeight,
            onApplicationFocused: (application) =>
                _onApplicationFocused(context, application),
            onViewAll: () => setState(() => _gallerySelected = true),
          );

          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: categoryWidget);
        }).toList(),
      );

  Widget _gallery(BuildContext context, List<App> installedApplications) {
    final applications = installedApplications
        .where((application) => !application.hidden)
        .toList();
    final category = Category.withApplications(
      id: -1,
      name: 'Galeria de Aplicativos',
      type: CategoryType.grid,
      applications: applications,
    );

    return AppsGrid(
      key: const ValueKey('application-gallery'),
      category: category,
      applications: applications,
      onApplicationFocused: (application) =>
          _onApplicationFocused(context, application),
    );
  }

  Widget _featuredPanel(BuildContext context) {
    return Consumer<WikimediaFeaturedImageService?>(
      builder: (context, featuredService, _) =>
          _buildFeaturedPanel(context, featuredService),
    );
  }

  Widget _buildFeaturedPanel(
    BuildContext context,
    WikimediaFeaturedImageService? featuredService,
  ) {
    final featuredImage = featuredService?.featuredImage;
    final height =
        MediaQuery.sizeOf(context).height * _featuredPanelHeightFactor;

    return SizedBox(
      key: const ValueKey('home-featured-panel'),
      height: height
          .clamp(_featuredPanelMinHeight, _featuredPanelMaxHeight)
          .toDouble(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: _focusedApplicationName,
                      builder: (context, focusedApplicationName, _) => Text(
                        focusedApplicationName ??
                            featuredImage?.title ??
                            'FLauncher',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(
                                color: Color.fromARGB(221, 14, 14, 14),
                                blurRadius: 10)
                          ],
                        ),
                      ),
                    ),
                    if (featuredImage?.description.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        featuredImage!.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 8)
                          ],
                        ),
                      ),
                    ],
                    if (featuredImage != null) ...[
                      const SizedBox(height: 8),
                      Tooltip(
                        message: [
                          featuredImage.sourceUrl,
                          if (featuredImage.licenseUrl.isNotEmpty)
                            featuredImage.licenseUrl,
                        ].join('\n'),
                        child: Text(
                          [
                            'Wikimedia Commons',
                            if (featuredImage.credit.isNotEmpty)
                              featuredImage.credit,
                            if (featuredImage.license.isNotEmpty)
                              featuredImage.license,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 8)
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (featuredService?.isLoading == true)
              const Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (featuredService?.lastError != null)
              Align(
                alignment: Alignment.topRight,
                child: Tooltip(
                  message: featuredService!.lastError.toString(),
                  child:
                      const Icon(Icons.cloud_off_outlined, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onApplicationFocused(BuildContext context, App application) {
    if (_focusedApplicationName.value != application.name) {
      _focusedApplicationName.value = application.name;
    }
  }

  Widget _wallpaper(BuildContext context, WallpaperService wallpaperService) {
    return Selector<WikimediaFeaturedImageService?, WikimediaFeaturedImage?>(
      selector: (_, featuredService) => featuredService?.featuredImage,
      builder: (context, featuredImage, _) =>
          _buildWallpaper(context, wallpaperService, featuredImage),
    );
  }

  Widget _buildWallpaper(
    BuildContext context,
    WallpaperService wallpaperService,
    WikimediaFeaturedImage? featuredImage,
  ) {
    final background = _defaultWallpaper(context, wallpaperService);

    final physicalSize = MediaQuery.sizeOf(context);
    final featuredService = context.read<WikimediaFeaturedImageService?>();
    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        if (featuredImage != null) ...[
          Image.memory(
            featuredImage.imageBytes,
            key: const Key('featured-background'),
            fit: BoxFit.cover,
            height: physicalSize.height,
            width: physicalSize.width,
            cacheWidth:
                (physicalSize.width * MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(1, 1280)
                    .toInt(),
            errorBuilder: (context, error, stackTrace) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  featuredService?.reportImageFailure(error, stackTrace);
                }
              });
              return const SizedBox.expand();
            },
          ),
          const IgnorePointer(
            child: ColoredBox(color: Color(0x40000000)),
          ),
        ],
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 190,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x40000000),
                    Color(0x1A000000),
                    Color(0x00000000),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: physicalSize.height * 0.62,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x12000000),
                    Color(0x35000000),
                  ],
                  stops: [0, 0.35, 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultWallpaper(
      BuildContext context, WallpaperService wallpaperService) {
    if (wallpaperService.wallpaper != null) {
      final physicalSize = MediaQuery.sizeOf(context);
      return Image(
          image: wallpaperService.wallpaper!,
          key: const Key("background"),
          fit: BoxFit.cover,
          height: physicalSize.height,
          width: physicalSize.width);
    } else {
      return Container(
          key: const Key("background"),
          decoration:
              BoxDecoration(gradient: wallpaperService.gradient.gradient));
    }
  }

  Widget _emptyState(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(localizations.loading,
              style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
