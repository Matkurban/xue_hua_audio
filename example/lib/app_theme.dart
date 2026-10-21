import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';

/// The [AppTheme] defines light and dark themes for the app.
///
/// Theme setup for FlexColorScheme package v8.
/// Use same major flex_color_scheme package version. If you use a
/// lower minor version, some properties may not be supported.
/// In that case, remove them after copying this theme to your
/// app or upgrade the package to version 8.4.0.
///
/// Use it in a [MaterialApp] like this:
///
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
/// );
abstract final class AppTheme {
  // The FlexColorScheme defined light mode ThemeData.
  static ThemeData light = FlexThemeData.light(
    // Using FlexColorScheme built-in FlexScheme enum based colors
    scheme: FlexScheme.shadGreen,
    // None seed generated ColorScheme style of Fixed colors.
    fixedColorStyle: FlexFixedColorStyle.seeded,
    // Surface color adjustments.
    lightIsWhite: true,
    // Component theme configurations for light mode.
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnColors: true,
      scaffoldBackgroundBaseColor: FlexScaffoldBaseColor.surface,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      thickBorderWidth: 1.0,
      adaptiveSplash: FlexAdaptive.all(),
      splashType: FlexSplashType.inkSplash,
      splashTypeAdaptive: FlexSplashType.inkSplash,
      adaptiveRemoveElevationTint: FlexAdaptive.all(),
      adaptiveRadius: FlexAdaptive.all(),
      defaultRadius: 10.0,
      defaultRadiusAdaptive: 10.0,
      toggleButtonsBorderSchemeColor: SchemeColor.transparent,
      segmentedButtonSchemeColor: SchemeColor.primary,
      segmentedButtonUnselectedSchemeColor: SchemeColor.onInverseSurface,
      segmentedButtonBorderSchemeColor: SchemeColor.transparent,
      switchThumbFixedSize: true,
      switchAdaptiveCupertinoLike: FlexAdaptive.all(),
      progressIndicatorLinearMinHeight: 4,
      progressIndicatorLinearRadius: 7.5,
      inputDecoratorIsFilled: true,
      inputDecoratorIsDense: true,
      inputDecoratorBackgroundAlpha: 100,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorUnfocusedHasBorder: false,
      inputDecoratorFocusedHasBorder: false,
      listTileContentPadding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
      listTileTitleAlignment: ListTileTitleAlignment.center,
      fabUseShape: true,
      chipSchemeColor: SchemeColor.onInverseSurface,
      chipBlendColors: true,
      alignedDropdown: true,
      tooltipRadius: 10,
      tooltipSchemeColor: SchemeColor.onPrimary,
      tooltipOpacity: null,
      snackBarRadius: 10,
      snackBarBackgroundSchemeColor: SchemeColor.secondary,
      snackBarActionSchemeColor: SchemeColor.primary,
      appBarScrolledUnderElevation: 0.0,
      appBarCenterTitle: true,
      tabBarIndicatorWeight: 3,
      tabBarIndicatorTopRadius: 4,
      tabBarDividerColor: Color(0x00000000),
      tabBarTabAlignment: TabAlignment.start,
      bottomNavigationBarElevation: 0.0,
      menuBarShadowColor: Color(0x00000000),
      menuIndicatorRadius: 3.0,
      searchViewHeaderHeight: 48.0,
      searchUseGlobalShape: true,
      navigationRailUseIndicator: true,
    ),
    // Direct ThemeData properties.
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );

  // The FlexColorScheme defined dark mode ThemeData.
  static ThemeData dark = FlexThemeData.dark(
    // Using FlexColorScheme built-in FlexScheme enum based colors.
    scheme: FlexScheme.shadGreen,
    // None seed generated ColorScheme style of Fixed colors.
    fixedColorStyle: FlexFixedColorStyle.seeded,
    // Component theme configurations for dark mode.
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnColors: true,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      adaptiveSplash: FlexAdaptive.all(),
      splashType: FlexSplashType.inkSplash,
      splashTypeAdaptive: FlexSplashType.inkSplash,
      adaptiveRadius: FlexAdaptive.all(),
      defaultRadius: 10.0,
      defaultRadiusAdaptive: 10.0,
      thickBorderWidth: 1.0,
      toggleButtonsBorderSchemeColor: SchemeColor.transparent,
      segmentedButtonSchemeColor: SchemeColor.primary,
      segmentedButtonUnselectedSchemeColor: SchemeColor.onInverseSurface,
      segmentedButtonBorderSchemeColor: SchemeColor.transparent,
      switchThumbFixedSize: true,
      switchAdaptiveCupertinoLike: FlexAdaptive.all(),
      progressIndicatorLinearMinHeight: 4,
      progressIndicatorLinearRadius: 7.5,
      inputDecoratorIsFilled: true,
      inputDecoratorIsDense: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorUnfocusedHasBorder: false,
      inputDecoratorFocusedHasBorder: false,
      listTileContentPadding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
      listTileTitleAlignment: ListTileTitleAlignment.center,
      fabUseShape: true,
      chipSchemeColor: SchemeColor.onInverseSurface,
      chipBlendColors: true,
      alignedDropdown: true,
      tooltipRadius: 10,
      tooltipSchemeColor: SchemeColor.onPrimary,
      tooltipOpacity: null,
      snackBarRadius: 10,
      snackBarBackgroundSchemeColor: SchemeColor.secondary,
      snackBarActionSchemeColor: SchemeColor.primary,
      appBarCenterTitle: true,
      tabBarIndicatorWeight: 3,
      tabBarIndicatorTopRadius: 4,
      tabBarDividerColor: Color(0x00000000),
      tabBarTabAlignment: TabAlignment.start,
      bottomNavigationBarElevation: 0.0,
      menuBarShadowColor: Color(0x00000000),
      menuIndicatorRadius: 3.0,
      searchViewHeaderHeight: 48.0,
      searchUseGlobalShape: true,
      navigationRailUseIndicator: true,
    ),
    // Direct ThemeData properties.
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );
}
