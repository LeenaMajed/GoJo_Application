import 'package:flutter/material.dart';


const kAccent    = Color(0xFFC8963E);   // Petra gold
const kAccentDim = Color(0xFFA07530);   // Deep gold
const kDanger    = Color(0xFFD9534F);
const kWarning   = Color(0xFFE8941A);
const kDeadSeaBlue = Color(0xFF2A7FA5);

const kDarkBg        = Color(0xFF111111);
const kDarkSurface   = Color(0xFF1A1A1A);
const kDarkCard      = Color(0xFF222222);
const kDarkDivider   = Color(0xFF2E2E2E);
const kDarkPrimary   = Color(0xFFF0F0F0);
const kDarkSecondary = Color(0xFF888888);


const kLightBg        = Color(0xFFF7F7F7);
const kLightSurface   = Color(0xFFFFFFFF);
const kLightCard      = Color(0xFFFFFFFF);
const kLightDivider   = Color(0xFFE8E8E8);
const kLightPrimary   = Color(0xFF111111);
const kLightSecondary = Color(0xFF888888);

extension GojoThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg        => isDark ? kDarkBg        : kLightBg;
  Color get surface   => isDark ? kDarkSurface   : kLightSurface;
  Color get card      => isDark ? kDarkCard      : kLightCard;
  Color get divider   => isDark ? kDarkDivider   : kLightDivider;
  Color get primary   => isDark ? kDarkPrimary   : kLightPrimary;
  Color get secondary => isDark ? kDarkSecondary : kLightSecondary;
}

ThemeData gojoDarkTheme()  => _build(Brightness.dark,  kDarkBg,  kDarkSurface,  kDarkCard,  kDarkDivider,  kDarkPrimary,  kDarkSecondary);
ThemeData gojoLightTheme() => _build(Brightness.light, kLightBg, kLightSurface, kLightCard, kLightDivider, kLightPrimary, kLightSecondary);

ThemeData _build(Brightness br, Color bg, Color surf, Color card, Color div, Color pri, Color sec) {
  return ThemeData(
    useMaterial3: true,
    brightness: br,
    scaffoldBackgroundColor: bg,
    fontFamily: 'SF Pro Display', 
    colorScheme: ColorScheme(
      brightness: br, primary: kAccent, onPrimary: Colors.white,
      secondary: kDeadSeaBlue, onSecondary: Colors.white,
      error: kDanger, onError: Colors.white, surface: surf, onSurface: pri,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surf, elevation: 0,
      scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(color: pri, fontSize: 17, fontWeight: FontWeight.w700),
      iconTheme: IconThemeData(color: pri),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: card,
      hintStyle: TextStyle(color: sec, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: div)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kAccent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent, foregroundColor: Colors.white, elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kAccent, side: const BorderSide(color: kAccent),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kAccent)),
    dividerTheme: DividerThemeData(color: div, thickness: 1),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surf, selectedItemColor: kAccent, unselectedItemColor: sec,
      type: BottomNavigationBarType.fixed, elevation: 0,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: div)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent : sec),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent.withOpacity(0.3) : div),
    ),
    sliderTheme: const SliderThemeData(activeTrackColor: kAccent, thumbColor: kAccent),
  );
}

TabBar buildPillTabBar(TabController ctrl, List<String> labels, BuildContext ctx, {bool scrollable = false}) =>
  TabBar(
    controller: ctrl,
    isScrollable: scrollable,
    tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
    dividerColor: Colors.transparent,
    indicator: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(10)),
    indicatorSize: TabBarIndicatorSize.tab,
    labelColor: Colors.white,
    unselectedLabelColor: ctx.secondary,
    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    tabs: labels.map((l) => Tab(text: l)).toList(),
  );
