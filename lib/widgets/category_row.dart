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

import 'dart:typed_data';

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/category_container_common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app.dart';
import '../models/category.dart';
import '../providers/settings_service.dart';

class CategoryRow extends StatelessWidget {
  final Category category;
  final List<App> applications;
  final ValueChanged<App>? onApplicationFocused;
  final int? cardRowHeight;
  final VoidCallback? onViewAll;

  CategoryRow({
    Key? key,
    required this.category,
    required this.applications,
    this.onApplicationFocused,
    this.cardRowHeight,
    this.onViewAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget categoryContent;
    final emptyStateCount = applications.isEmpty ? 1 : 0;
    final hasActionCards = onViewAll != null;
    if (applications.isEmpty && !hasActionCards) {
      categoryContent = categoryContainerEmptyState(context);
    } else {
      categoryContent = SizedBox(
          height: (cardRowHeight ?? category.rowHeight).toDouble(),
          child: ListView.custom(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
              scrollDirection: Axis.horizontal,
              childrenDelegate: SliverChildBuilderDelegate(
                childCount: emptyStateCount +
                    applications.length +
                    (hasActionCards ? 2 : 0),
                findChildIndexCallback: _findChildIndex,
                (context, index) {
                  if (emptyStateCount == 1 && index == 0) {
                    return SizedBox(
                      key: const ValueKey<String>('empty-category'),
                      width: 220,
                      child: categoryContainerEmptyState(context),
                    );
                  }

                  final applicationIndex = index - emptyStateCount;
                  if (applicationIndex >= 0 &&
                      applicationIndex < applications.length) {
                    return Padding(
                      key: Key(applications[applicationIndex].packageName),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: AppCard(
                        category: category,
                        application: applications[applicationIndex],
                        autofocus: applicationIndex == 0,
                        onFocused: onApplicationFocused,
                        onMove: (direction) =>
                            _onMove(context, direction, applicationIndex),
                        onMoveEnd: () => _onMoveEnd(context),
                      ),
                    );
                  }

                  final viewAllIndex = emptyStateCount + applications.length;
                  if (onViewAll != null && index == viewAllIndex) {
                    return Padding(
                      key: const ValueKey<String>('view-all-apps'),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _ViewAllAppsCard(onPressed: onViewAll!),
                    );
                  }

                  return Padding(
                    key: const ValueKey<String>('organize-apps'),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _OrganizeAppsCard(
                      onPressed: () => _openOrganizer(context),
                    ),
                  );
                },
              )));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Selector<SettingsService, bool>(
            selector: (context, service) => service.showCategoryTitles,
            builder: (context, showCategoriesTitle, _) {
              if (showCategoriesTitle) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(category.name,
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          shadows: [
                            const Shadow(
                                color: Colors.black54,
                                offset: Offset(1, 1),
                                blurRadius: 8)
                          ])),
                );
              }

              return SizedBox.shrink();
            }),
        categoryContent
      ],
    );
  }

  int _findChildIndex(Key key) {
    final emptyStateCount = applications.isEmpty ? 1 : 0;
    final viewAllIndex = emptyStateCount + applications.length;
    if (key == const ValueKey<String>('empty-category') &&
        emptyStateCount == 1) {
      return 0;
    }
    if (key == const ValueKey<String>('view-all-apps') && onViewAll != null) {
      return viewAllIndex;
    }
    if (key == const ValueKey<String>('organize-apps') && onViewAll != null) {
      return viewAllIndex + 1;
    }
    if (key is ValueKey<String>) {
      final applicationIndex =
          applications.indexWhere((app) => app.packageName == key.value);
      return applicationIndex < 0 ? -1 : applicationIndex + emptyStateCount;
    }
    return -1;
  }

  Future<void> _openOrganizer(BuildContext context) async {
    final appsService = context.read<AppsService>();
    final availableApplications = appsService.applications
        .where((application) => !application.hidden)
        .toList(growable: false);
    final selectedApplications = await showDialog<List<App>>(
      context: context,
      builder: (_) => _OrganizeAppsDialog(
        categoryName: category.name,
        availableApplications: availableApplications,
        selectedApplications: applications,
      ),
    );
    if (selectedApplications == null || !context.mounted) {
      return;
    }

    try {
      await appsService.replaceCategoryApplications(
        category,
        selectedApplications,
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to save carousel apps: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Não foi possível salvar os aplicativos: $error')),
        );
      }
    }
  }

  void _onMove(BuildContext context, AxisDirection direction, int index) {
    int newIndex = 0;

    if (direction == AxisDirection.right && index < applications.length - 1) {
      newIndex = index + 1;
    } else if (direction == AxisDirection.left && index > 0) {
      newIndex = index - 1;
    } else {
      return;
    }

    final appsService = context.read<AppsService>();
    appsService.reorderApplication(category, index, newIndex);
  }

  void _onMoveEnd(BuildContext context) {
    final appsService = context.read<AppsService>();
    appsService.saveApplicationOrderInCategory(category);
  }
}

class _ViewAllAppsCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _ViewAllAppsCard({required this.onPressed});

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 16 / 9,
        child: Material(
          color: Theme.of(context).cardColor.withOpacity(0.82),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            autofocus: false,
            focusColor: Colors.white.withOpacity(0.18),
            onFocusChange: (focused) {
              if (focused) {
                Scrollable.ensureVisible(
                  context,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.apps, size: 36),
                const SizedBox(height: 8),
                Text(
                  'Ver todos os apps',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
}

class _OrganizeAppsCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _OrganizeAppsCard({required this.onPressed});

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 16 / 9,
        child: Material(
          color: Theme.of(context).cardColor.withOpacity(0.82),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            focusColor: Colors.white.withOpacity(0.18),
            onFocusChange: (focused) {
              if (focused) {
                Scrollable.ensureVisible(
                  context,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note, size: 36),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Organizar apps',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _OrganizeAppsDialog extends StatefulWidget {
  final String categoryName;
  final List<App> availableApplications;
  final List<App> selectedApplications;

  const _OrganizeAppsDialog({
    required this.categoryName,
    required this.availableApplications,
    required this.selectedApplications,
  });

  @override
  State<_OrganizeAppsDialog> createState() => _OrganizeAppsDialogState();
}

class _OrganizeAppsDialogState extends State<_OrganizeAppsDialog> {
  late final List<App> _selectedApplications;

  @override
  void initState() {
    super.initState();
    final availablePackageNames =
        widget.availableApplications.map((app) => app.packageName).toSet();
    _selectedApplications = widget.selectedApplications
        .where((app) => availablePackageNames.contains(app.packageName))
        .take(Category.maxHomeApplications)
        .toList();
  }

  void _toggleApplication(App application, bool selected) {
    setState(() {
      if (selected) {
        if (_selectedApplications.length < Category.maxHomeApplications) {
          _selectedApplications.add(application);
        }
      } else {
        _selectedApplications
            .removeWhere((app) => app.packageName == application.packageName);
      }
    });
  }

  void _moveApplication(int index, int offset) {
    final destination = index + offset;
    if (destination < 0 || destination >= _selectedApplications.length) {
      return;
    }

    setState(() {
      final application = _selectedApplications.removeAt(index);
      _selectedApplications.insert(destination, application);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width - 48).clamp(0.0, 1120.0);
    final dialogHeight = (screenSize.height - 48).clamp(0.0, 760.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 20, 16),
              child: Row(
                children: [
                  const Icon(Icons.dashboard_customize_outlined, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Organizar ${widget.categoryName}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Escolha os cards e organize a ordem do carrossel.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _CarouselCount(count: _selectedApplications.length),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _OrganizerPanel(
                        title: 'APLICATIVOS DISPONÍVEIS',
                        subtitle: 'Selecione um card para adicionar',
                        child: GridView.builder(
                          key: const ValueKey('available-apps-grid'),
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisExtent: 132,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: widget.availableApplications.length,
                          itemBuilder: (context, index) {
                            final application =
                                widget.availableApplications[index];
                            final isSelected = _selectedApplications.any(
                              (selected) =>
                                  selected.packageName ==
                                  application.packageName,
                            );
                            return _AvailableAppCard(
                              key: ValueKey(
                                  'available-${application.packageName}'),
                              application: application,
                              selected: isSelected,
                              disabled: !isSelected &&
                                  _selectedApplications.length >=
                                      Category.maxHomeApplications,
                              onPressed: () => _toggleApplication(
                                application,
                                !isSelected,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _OrganizerPanel(
                        title: 'NO CARROSSEL',
                        subtitle: 'Use as setas para mudar a posição dos cards',
                        child: _selectedApplications.isEmpty
                            ? const _EmptyCarouselSlots()
                            : ListView.separated(
                                key: const ValueKey('selected-carousel-apps'),
                                padding: const EdgeInsets.all(12),
                                itemCount: _selectedApplications.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final application =
                                      _selectedApplications[index];
                                  return _SelectedAppCard(
                                    key: ValueKey(
                                        'selected-${application.packageName}'),
                                    application: application,
                                    position: index + 1,
                                    canMoveUp: index > 0,
                                    canMoveDown: index <
                                        _selectedApplications.length - 1,
                                    onMoveUp: () => _moveApplication(index, -1),
                                    onMoveDown: () =>
                                        _moveApplication(index, 1),
                                    onRemove: () => _toggleApplication(
                                      application,
                                      false,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Até ${Category.maxHomeApplications} apps. Os demais continuam em Todos os Apps.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      List<App>.of(_selectedApplications),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Salvar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselCount extends StatelessWidget {
  final int count;

  const _CarouselCount({required this.count});

  @override
  Widget build(BuildContext context) {
    final full = count >= Category.maxHomeApplications;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (full ? Theme.of(context).colorScheme.primary : Colors.white)
            .withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: full
              ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
              : Colors.white24,
        ),
      ),
      child: Text(
        '$count / ${Category.maxHomeApplications}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _OrganizerPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _OrganizerPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.58),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: child),
          ],
        ),
      );
}

class _AvailableAppCard extends StatefulWidget {
  final App application;
  final bool selected;
  final bool disabled;
  final VoidCallback onPressed;

  const _AvailableAppCard({
    super.key,
    required this.application,
    required this.selected,
    required this.disabled,
    required this.onPressed,
  });

  @override
  State<_AvailableAppCard> createState() => _AvailableAppCardState();
}

class _AvailableAppCardState extends State<_AvailableAppCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _focused || widget.selected;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted
              ? Theme.of(context).colorScheme.primary
              : Colors.white24,
          width: highlighted ? 3 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.disabled && !widget.selected ? null : widget.onPressed,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _OrganizerAppArtwork(application: widget.application),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE6000000)],
                    stops: [0.25, 1],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Text(
                  widget.application.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 8),
                    ],
                  ),
                ),
              ),
              if (widget.selected)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 15,
                    child: Icon(Icons.check, size: 18),
                  ),
                ),
              if (widget.disabled)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.block, color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedAppCard extends StatelessWidget {
  final App application;
  final int position;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  const _SelectedAppCard({
    super.key,
    required this.application,
    required this.position,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 82,
          child: Row(
            children: [
              SizedBox(
                width: 132,
                height: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _OrganizerAppArtwork(application: application),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 6,
                      child: CircleAvatar(
                        radius: 13,
                        child: Text(
                          '$position',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  application.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Mover para cima',
                    visualDensity: VisualDensity.compact,
                    onPressed: canMoveUp ? onMoveUp : null,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    tooltip: 'Mover para baixo',
                    visualDensity: VisualDensity.compact,
                    onPressed: canMoveDown ? onMoveDown : null,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Remover do carrossel',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      );
}

class _OrganizerAppArtwork extends StatefulWidget {
  final App application;

  const _OrganizerAppArtwork({required this.application});

  @override
  State<_OrganizerAppArtwork> createState() => _OrganizerAppArtworkState();
}

class _OrganizerAppArtworkState extends State<_OrganizerAppArtwork> {
  late Future<Uint8List> _artworkFuture;

  @override
  void initState() {
    super.initState();
    _artworkFuture = _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant _OrganizerAppArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.application.packageName != widget.application.packageName) {
      _artworkFuture = _loadArtwork();
    }
  }

  Future<Uint8List> _loadArtwork() async {
    final appsService = context.read<AppsService>();
    final banner =
        await appsService.getAppBanner(widget.application.packageName);
    if (banner.isNotEmpty) {
      return banner;
    }
    return appsService.getAppIcon(widget.application.packageName);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _artworkFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ArtworkPlaceholder(name: widget.application.name);
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _ArtworkPlaceholder(name: widget.application.name);
          }
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _ArtworkPlaceholder(name: widget.application.name),
          );
        },
      );
}

class _ArtworkPlaceholder extends StatelessWidget {
  final String name;

  const _ArtworkPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.android,
            size: 40,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          ),
        ),
      );
}

class _EmptyCarouselSlots extends StatelessWidget {
  const _EmptyCarouselSlots();

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: Category.maxHomeApplications,
        itemBuilder: (context, index) => Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 13,
                child: Text('${index + 1}'),
              ),
              const SizedBox(width: 14),
              Text(
                'Slot vazio',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
}
