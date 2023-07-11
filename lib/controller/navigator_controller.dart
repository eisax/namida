import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/packages/inner_drawer.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaNavigator {
  static NamidaNavigator get inst => _instance;
  static final NamidaNavigator _instance = NamidaNavigator._internal();
  NamidaNavigator._internal();

  final navKey = Get.nestedKey(1);

  final RxList<NamidaRoute> currentWidgetStack = <NamidaRoute>[].obs;
  NamidaRoute? get currentRoute => currentWidgetStack.lastOrNull;
  int currentDialogNumber = 0;

  final GlobalKey<InnerDrawerState> innerDrawerKey = GlobalKey<InnerDrawerState>();
  final heroController = HeroController();

  void toggleDrawer() {
    innerDrawerKey.currentState?.toggle();
  }

  void _hideSearchMenuAndUnfocus() => ScrollSearchController.inst.hideSearchMenu();
  void _minimizeMiniplayer() => MiniPlayerController.inst.snapToMini();

  /// used when going to artist subpage
  void _calculateDimensions() {
    final libTab = currentRoute?.toLibraryTab();
    if (libTab != null) {
      Dimensions.inst.updateDimensions(libTab);
    }
  }

  void _hideEverything() {
    _hideSearchMenuAndUnfocus();
    _minimizeMiniplayer();
    _calculateDimensions();
    closeAllDialogs();
  }

  void onFirstLoad() {
    final initialTab = SettingsController.inst.selectedLibraryTab.value;
    navigateTo(initialTab.toWidget(), durationInMs: 0);
    Dimensions.inst.updateDimensions(initialTab);
  }

  Future<void> navigateTo(
    Widget page, {
    bool nested = true,
    Transition transition = Transition.cupertino,
    int durationInMs = 500,
  }) async {
    currentWidgetStack.add(page.toNamidaRoute());
    _hideEverything();

    currentRoute?.updateColorScheme();

    await Get.to(
      () => page,
      id: nested ? 1 : null,
      preventDuplicates: false,
      transition: transition,
      curve: Curves.easeOut,
      duration: Duration(milliseconds: durationInMs),
      opaque: true,
      fullscreenDialog: false,
    );
  }

  /// Use [dialogBuilder] in case you want to acess the theme generated by [colorScheme].
  Future<void> navigateDialog({
    Widget? dialog,
    Widget Function(ThemeData theme)? dialogBuilder,
    int durationInMs = 300,
    bool tapToDismiss = true,
    void Function()? onDismissing,
    Color? colorScheme,
    bool lighterDialogColor = true,
    double scale = 0.96,
    bool blackBg = false,
  }) async {
    final rootNav = navigator;
    if (rootNav == null) return;

    ScrollSearchController.inst.unfocusKeyboard();
    currentDialogNumber++;

    Future<bool> onWillPop() async {
      if (!tapToDismiss) return false;
      if (onDismissing != null) onDismissing();

      if (currentDialogNumber > 0) {
        closeDialog();
        return false;
      }

      return true;
    }

    final theme = AppThemes.inst.getAppTheme(colorScheme, null, lighterDialogColor);

    await Get.to(
      WillPopScope(
        onWillPop: onWillPop,
        child: GestureDetector(
          onTap: onWillPop,
          child: NamidaBgBlur(
            blur: 5.0,
            enabled: currentDialogNumber == 1,
            child: Container(
              color: Colors.black.withOpacity(blackBg ? 1.0 : 0.45),
              child: Transform.scale(
                scale: scale,
                child: Theme(
                  data: theme,
                  child: dialogBuilder == null ? dialog! : dialogBuilder(theme),
                ),
              ),
            ),
          ),
        ),
      ),
      duration: Duration(milliseconds: durationInMs),
      preventDuplicates: false,
      opaque: false,
      fullscreenDialog: true,
      transition: Transition.fade,
    );

    _printDialogs();
  }

  Future<void> closeDialog([int count = 1]) async {
    if (currentDialogNumber == 0) return;
    final closeCount = count.withMaximum(currentDialogNumber);
    currentDialogNumber -= closeCount;
    Get.close(closeCount);
    _printDialogs();
  }

  Future<void> closeAllDialogs() async {
    closeDialog(currentDialogNumber);
    _printDialogs();
  }

  void _printDialogs() => printy("Current Dialogs: $currentDialogNumber");

  Future<void> navigateOff(
    Widget page, {
    bool nested = true,
    Transition transition = Transition.cupertino,
    int durationInMs = 500,
  }) async {
    currentWidgetStack.removeLast();
    currentWidgetStack.add(page.toNamidaRoute());
    _hideEverything();

    currentRoute?.updateColorScheme();

    await Get.off(
      () => page,
      id: nested ? 1 : null,
      preventDuplicates: false,
      transition: transition,
      curve: Curves.easeOut,
      duration: Duration(milliseconds: durationInMs),
      opaque: true,
      fullscreenDialog: false,
    );
  }

  Future<void> navigateOffAll(
    Widget page, {
    bool nested = true,
    Transition transition = Transition.cupertino,
  }) async {
    currentWidgetStack
      ..clear()
      ..add(page.toNamidaRoute());
    _hideEverything();

    currentRoute?.updateColorScheme();

    await Get.offAll(
      () => page,
      id: nested ? 1 : null,
      transition: transition,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> popPage() async {
    if (innerDrawerKey.currentState?.isOpened ?? false) {
      innerDrawerKey.currentState?.close();
      return;
    }
    if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      _hideSearchMenuAndUnfocus();
      return;
    }

    // pop only if not in root, otherwise show _doubleTapToExit().
    if (currentWidgetStack.length > 1) {
      currentWidgetStack.removeLast();
      _calculateDimensions();
      navKey?.currentState?.pop();
    } else {
      await _doubleTapToExit();
    }
    currentRoute?.updateColorScheme();
    _hideSearchMenuAndUnfocus();
  }

  DateTime _currentBackPressTime = DateTime(0);
  Future<bool> _doubleTapToExit() async {
    final now = DateTime.now();
    if (now.difference(_currentBackPressTime) > const Duration(seconds: 3)) {
      _currentBackPressTime = now;

      final tcolor = Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(50), Get.textTheme.displayMedium!.color!);
      Get.showSnackbar(
        GetSnackBar(
          messageText: Text(
            Language.inst.EXIT_APP_SUBTITLE,
            style: Get.textTheme.displayMedium?.copyWith(color: tcolor),
          ),
          icon: Icon(
            Broken.logout,
            color: tcolor,
          ),
          shouldIconPulse: false,
          snackPosition: SnackPosition.BOTTOM,
          snackStyle: SnackStyle.FLOATING,
          borderRadius: 14.0.multipliedRadius,
          backgroundColor: Colors.grey.withOpacity(0.2),
          barBlur: 10.0,
          // dismissDirection: DismissDirection.none,
          margin: const EdgeInsets.all(8.0),
          animationDuration: const Duration(milliseconds: 300),
          forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
          reverseAnimationCurve: Curves.easeInOutQuart,
          duration: const Duration(seconds: 3),
          snackbarStatus: (status) {
            // -- resets time
            if (status == SnackbarStatus.CLOSED) {
              _currentBackPressTime = DateTime(0);
            }
          },
        ),
      );
      return false;
    }
    SystemNavigator.pop();
    return true;
  }
}
