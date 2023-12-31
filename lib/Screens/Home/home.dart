/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2023, Ankit Sangwan
 */

import 'dart:io';

import 'package:blackhole/CustomWidgets/gradient_containers.dart';
import 'package:blackhole/CustomWidgets/miniplayer.dart';
import 'package:blackhole/CustomWidgets/snackbar.dart';
import 'package:blackhole/Helpers/backup_restore.dart';
import 'package:blackhole/Helpers/downloads_checker.dart';
import 'package:blackhole/Helpers/github.dart';
import 'package:blackhole/Helpers/route_handler.dart';
import 'package:blackhole/Helpers/update.dart';
import 'package:blackhole/Screens/Common/routes.dart';
import 'package:blackhole/Screens/Home/home_screen.dart';
import 'package:blackhole/Screens/Library/library.dart';
import 'package:blackhole/Screens/LocalMusic/downed_songs.dart';
import 'package:blackhole/Screens/LocalMusic/downed_songs_desktop.dart';
import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:blackhole/Screens/Settings/new_settings_page.dart';
import 'package:blackhole/Screens/Top Charts/top.dart';
import 'package:blackhole/Screens/YouTube/youtube_home.dart';
import 'package:blackhole/Services/ext_storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:persistent_bottom_nav_bar/persistent_tab_view.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);
  String? appVersion;
  String name =
      Hive.box('settings').get('name', defaultValue: 'Guest') as String;
  bool checkUpdate =
      Hive.box('settings').get('checkUpdate', defaultValue: false) as bool;
  bool autoBackup =
      Hive.box('settings').get('autoBackup', defaultValue: false) as bool;
  List sectionsToShow = Hive.box('settings').get(
    'sectionsToShow',
    defaultValue: ['Home', 'Top Charts', 'YouTube', 'Library'],
  ) as List;
  DateTime? backButtonPressTime;

  void callback() {
    sectionsToShow = Hive.box('settings').get(
      'sectionsToShow',
      defaultValue: ['Home', 'Top Charts', 'YouTube', 'Library'],
    ) as List;
    setState(() {});
  }

  void _onItemTapped(int index) {
    _selectedIndex.value = index;
    _controller.jumpToTab(
      index,
    );
  }

  Future<bool> handleWillPop(BuildContext context) async {
    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
        backButtonPressTime == null ||
            now.difference(backButtonPressTime!) > const Duration(seconds: 3);

    if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
      backButtonPressTime = now;
      ShowSnackBar().showSnackBar(
        context,
        AppLocalizations.of(context)!.exitConfirm,
        duration: const Duration(seconds: 2),
        noAction: true,
      );
      return false;
    }
    return true;
  }

  void checkVersion() {
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      appVersion = packageInfo.version;

      if (checkUpdate) {
        Logger.root.info('Checking for update');
        GitHub.getLatestVersion().then((String version) async {
          if (compareVersion(
            version,
            appVersion!,
          )) {
            // List? abis =
            //     await Hive.box('settings').get('supportedAbis') as List?;

            // if (abis == null) {
            //   final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
            //   final AndroidDeviceInfo androidDeviceInfo =
            //       await deviceInfo.androidInfo;
            //   abis = androidDeviceInfo.supportedAbis;
            //   await Hive.box('settings').put('supportedAbis', abis);
            // }

            Logger.root.info('Update available');
            ShowSnackBar().showSnackBar(
              context,
              AppLocalizations.of(context)!.updateAvailable,
              duration: const Duration(seconds: 15),
              action: SnackBarAction(
                textColor: Theme.of(context).colorScheme.secondary,
                label: AppLocalizations.of(context)!.update,
                onPressed: () {
                  Navigator.pop(context);
                  launchUrl(
                    Uri.parse('https://sangwan5688.github.io/download/'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            );
          } else {
            Logger.root.info('No update available');
          }
        });
      }
      if (autoBackup) {
        final List<String> checked = [
          AppLocalizations.of(
            context,
          )!
              .settings,
          AppLocalizations.of(
            context,
          )!
              .downs,
          AppLocalizations.of(
            context,
          )!
              .playlists,
        ];
        final List playlistNames = Hive.box('settings').get(
          'playlistNames',
          defaultValue: ['Favorite Songs'],
        ) as List;
        final Map<String, List> boxNames = {
          AppLocalizations.of(
            context,
          )!
              .settings: ['settings'],
          AppLocalizations.of(
            context,
          )!
              .cache: ['cache'],
          AppLocalizations.of(
            context,
          )!
              .downs: ['downloads'],
          AppLocalizations.of(
            context,
          )!
              .playlists: playlistNames,
        };
        final String autoBackPath = Hive.box('settings').get(
          'autoBackPath',
          defaultValue: '',
        ) as String;
        if (autoBackPath == '') {
          ExtStorageProvider.getExtStorage(
            dirName: 'BlackHole/Backups',
            writeAccess: true,
          ).then((value) {
            Hive.box('settings').put('autoBackPath', value);
            createBackup(
              context,
              checked,
              boxNames,
              path: value,
              fileName: 'BlackHole_AutoBackup',
              showDialog: false,
            );
          });
        } else {
          createBackup(
            context,
            checked,
            boxNames,
            path: autoBackPath,
            fileName: 'BlackHole_AutoBackup',
            showDialog: false,
          );
        }
      }
    });
    if (Hive.box('settings').get('proxyIp') == null) {
      Hive.box('settings').put('proxyIp', '103.47.67.134');
    }
    if (Hive.box('settings').get('proxyPort') == null) {
      Hive.box('settings').put('proxyPort', 8080);
    }
    downloadChecker();
  }

  final PageController _pageController = PageController();
  final PersistentTabController _controller = PersistentTabController();

  @override
  void initState() {
    super.initState();
    checkVersion();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool rotated = MediaQuery.of(context).size.height < screenWidth;
    return GradientContainer(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        drawer: Drawer(
          child: GradientContainer(
            child: CustomScrollView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  elevation: 0,
                  stretch: true,
                  expandedHeight: MediaQuery.of(context).size.height * 0.2,
                  flexibleSpace: FlexibleSpaceBar(
                    title: RichText(
                      text: TextSpan(
                        text: AppLocalizations.of(context)!.appTitle,
                        style: const TextStyle(
                          fontSize: 30.0,
                          fontWeight: FontWeight.w500,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: appVersion == null ? '' : '\nv$appVersion',
                            style: const TextStyle(
                              fontSize: 7.0,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.end,
                    ),
                    titlePadding: const EdgeInsets.only(bottom: 40.0),
                    centerTitle: true,
                    background: ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.black.withOpacity(0.1),
                          ],
                        ).createShader(
                          Rect.fromLTRB(0, 0, rect.width, rect.height),
                        );
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image(
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        image: AssetImage(
                          Theme.of(context).brightness == Brightness.dark
                              ? 'assets/header-dark.jpg'
                              : 'assets/header.jpg',
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      ListTile(
                        title: ValueListenableBuilder(
                          valueListenable: _selectedIndex,
                          builder: (context, value, Widget? child) => Text(
                            AppLocalizations.of(context)!.home,
                            style: _selectedIndex.value == 0
                                ? TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  )
                                : null,
                          ),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: ValueListenableBuilder(
                          valueListenable: _selectedIndex,
                          builder: (context, value, Widget? child) => Icon(
                            Icons.home_rounded,
                            color: _selectedIndex.value == 0
                                ? Theme.of(context).colorScheme.secondary
                                : null,
                          ),
                        ),
                        selected: _selectedIndex.value == 0,
                        onTap: () {
                          Navigator.pop(context);
                          if (_selectedIndex.value != 0) {
                            _onItemTapped(0);
                          }
                        },
                      ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.myMusic),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: Icon(
                          MdiIcons.folderMusic,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => (Platform.isWindows ||
                                      Platform.isLinux ||
                                      Platform.isMacOS)
                                  ? const DownloadedSongsDesktop()
                                  : const DownloadedSongs(
                                      showPlaylists: true,
                                    ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.downs),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: Icon(
                          Icons.download_done_rounded,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/downloads');
                        },
                      ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.playlists),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: Icon(
                          Icons.playlist_play_rounded,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/playlists');
                        },
                      ),
                      ListTile(
                        title: ValueListenableBuilder(
                          valueListenable: _selectedIndex,
                          builder: (context, value, Widget? child) => Text(
                            AppLocalizations.of(context)!.settings,
                            style: sectionsToShow.contains('Settings') &&
                                    _selectedIndex.value == 3
                                ? TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  )
                                : null,
                          ),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: ValueListenableBuilder(
                          valueListenable: _selectedIndex,
                          builder: (context, value, Widget? child) => Icon(
                            Icons
                                .settings_rounded, // miscellaneous_services_rounded,
                            color: sectionsToShow.contains('Settings') &&
                                    _selectedIndex.value == 3
                                ? Theme.of(context).colorScheme.secondary
                                : null,
                          ),
                        ),
                        selected: _selectedIndex.value == 3,
                        onTap: () {
                          Navigator.pop(context);
                          if (sectionsToShow.contains('Settings')) {
                            if (_selectedIndex.value != 3) {
                              _onItemTapped(3);
                            }
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    NewSettingsPage(callback: callback),
                              ),
                            );
                          }
                        },
                      ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.about),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: Icon(
                          Icons.info_outline_rounded,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/about');
                        },
                      ),
                    ],
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: <Widget>[
                      const Spacer(),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(5, 30, 5, 20),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.madeBy,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: WillPopScope(
          onWillPop: () => handleWillPop(context),
          child: SafeArea(
            child: Row(
              children: [
                if (rotated)
                  ValueListenableBuilder(
                    valueListenable: _selectedIndex,
                    builder:
                        (BuildContext context, int indexValue, Widget? child) {
                      return NavigationRail(
                        minWidth: 70.0,
                        groupAlignment: 0.0,
                        backgroundColor:
                            // Colors.transparent,
                            Theme.of(context).cardColor,
                        selectedIndex: indexValue,
                        onDestinationSelected: (int index) {
                          _onItemTapped(index);
                        },
                        labelType: screenWidth > 1050
                            ? NavigationRailLabelType.selected
                            : NavigationRailLabelType.none,
                        selectedLabelTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelTextStyle: TextStyle(
                          color: Theme.of(context).iconTheme.color,
                        ),
                        selectedIconTheme: Theme.of(context).iconTheme.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                        unselectedIconTheme: Theme.of(context).iconTheme,
                        useIndicator: screenWidth < 1050,
                        indicatorColor: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.2),
                        leading: Builder(
                          builder: (context) => Transform.rotate(
                            angle: 22 / 7 * 2,
                            child: IconButton(
                              icon: const Icon(
                                Icons.horizontal_split_rounded,
                              ),
                              // color: Theme.of(context).iconTheme.color,
                              onPressed: () {
                                Scaffold.of(context).openDrawer();
                              },
                              tooltip: MaterialLocalizations.of(context)
                                  .openAppDrawerTooltip,
                            ),
                          ),
                        ),
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(Icons.home_rounded),
                            label: Text(AppLocalizations.of(context)!.home),
                          ),
                          if (sectionsToShow.contains('Top Charts'))
                            NavigationRailDestination(
                              icon: const Icon(Icons.trending_up_rounded),
                              label: Text(
                                AppLocalizations.of(context)!.topCharts,
                              ),
                            ),
                          NavigationRailDestination(
                            icon: const Icon(MdiIcons.youtube),
                            label: Text(AppLocalizations.of(context)!.youTube),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.my_library_music_rounded),
                            label: Text(AppLocalizations.of(context)!.library),
                          ),
                          if (sectionsToShow.contains('Settings'))
                            NavigationRailDestination(
                              icon: const Icon(Icons.settings_rounded),
                              label: Text(
                                AppLocalizations.of(context)!.settings,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                Expanded(
                  child: PersistentTabView.custom(
                    context,
                    controller: _controller,
                    itemCount: 4,
                    navBarHeight: rotated ? 75 : 140.0,
                    confineInSafeArea: false,
                    routeAndNavigatorSettings:
                        CustomWidgetRouteAndNavigatorSettings(
                      routes: namedRoutes,
                      onGenerateRoute: (RouteSettings settings) {
                        if (settings.name == '/player') {
                          return PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (_, __, ___) => const PlayScreen(),
                          );
                        }
                        return HandleRoute.handleRoute(settings.name);
                      },
                    ),
                    customWidget: SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: MiniPlayer(),
                          ),
                          if (!rotated)
                            ValueListenableBuilder(
                              valueListenable: _selectedIndex,
                              builder: (
                                BuildContext context,
                                int indexValue,
                                Widget? child,
                              ) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  height: 60,
                                  child: SalomonBottomBar(
                                    currentIndex: indexValue,
                                    onTap: (index) {
                                      _onItemTapped(index);
                                    },
                                    items: _navBarItems(context),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    screens: [
                      const HomeScreen(),
                      if (sectionsToShow.contains('Top Charts'))
                        TopCharts(
                          pageController: _pageController,
                        ),
                      const YouTube(),
                      const LibraryPage(),
                      if (sectionsToShow.contains('Settings'))
                        NewSettingsPage(callback: callback),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<SalomonBottomBarItem> _navBarItems(BuildContext context) {
    return [
      SalomonBottomBarItem(
        icon: const Icon(Icons.home_rounded),
        title: Text(AppLocalizations.of(context)!.home),
        selectedColor: Theme.of(context).colorScheme.secondary,
      ),
      if (sectionsToShow.contains('Top Charts'))
        SalomonBottomBarItem(
          icon: const Icon(Icons.trending_up_rounded),
          title: Text(AppLocalizations.of(context)!.topCharts),
          selectedColor: Theme.of(context).colorScheme.secondary,
        ),
      if (sectionsToShow.contains('YouTube'))
        SalomonBottomBarItem(
          icon: const Icon(MdiIcons.youtube),
          title: Text(AppLocalizations.of(context)!.youTube),
          selectedColor: Theme.of(context).colorScheme.secondary,
        ),
      SalomonBottomBarItem(
        icon: const Icon(Icons.my_library_music_rounded),
        title: Text(AppLocalizations.of(context)!.library),
        selectedColor: Theme.of(context).colorScheme.secondary,
      ),
      if (sectionsToShow.contains('Settings'))
        SalomonBottomBarItem(
          icon: const Icon(Icons.settings_rounded),
          title: Text(AppLocalizations.of(context)!.settings),
          selectedColor: Theme.of(context).colorScheme.secondary,
        ),
    ];
  }
}
