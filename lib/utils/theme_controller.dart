import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  // Holds the selected theme key. `gradient` is the existing storage key for
  // the Indigo preset and is retained for backwards compatibility.
  static final ValueNotifier<String> themeKey = ValueNotifier('professional');

  // Holds custom color value (only used when themeKey == 'custom')
  static final ValueNotifier<Color> customColor = ValueNotifier(Colors.blue);

  static void setTheme(String key, {Color? color}) {
    themeKey.value = key;
    if (key == 'custom' && color != null) {
      customColor.value = color;
      _saveCustomColor(color);
    }
    _saveThemeKey(key);
  }

  // Available theme presets (key -> MaterialColor)
  static final Map<String, MaterialColor> presets = {
    'professional': MaterialColor(0xFF212121, const <int, Color>{
      50: Color(0xFFE0E0E0),
      100: Color(0xFFB0B0B0),
      200: Color(0xFF808080),
      300: Color(0xFF616161),
      400: Color(0xFF424242),
      500: Color(0xFF212121),
      600: Color(0xFF1E1E1E),
      700: Color(0xFF1A1A1A),
      800: Color(0xFF121212),
      900: Color(0xFF000000),
    }),
    'gradient': MaterialColor(0xFF5E72E4, const <int, Color>{
      50: Color(0xFFECEFFE),
      100: Color(0xFFD0D7FC),
      200: Color(0xFFB1BCFA),
      300: Color(0xFF92A1F8),
      400: Color(0xFF7A8DF6),
      500: Color(0xFF5E72E4),
      600: Color(0xFF5666D8),
      700: Color(0xFF4C56CC),
      800: Color(0xFF4347C0),
      900: Color(0xFF3330AD),
    }),
    'mocha': MaterialColor(0xFF6F4E37, const <int, Color>{
      50: Color(0xFFEEE9E6),
      100: Color(0xFFD4C7C0),
      200: Color(0xFFB7A296),
      300: Color(0xFF9A7D6C),
      400: Color(0xFF84614D),
      500: Color(0xFF6F4E37),
      600: Color(0xFF674731),
      700: Color(0xFF5C3D2A),
      800: Color(0xFF523423),
      900: Color(0xFF402516),
    }),
    'green': Colors.green,
    'violet': Colors.purple,
    'orange': Colors.orange,
    'brown': Colors.brown,
    'red': Colors.red,
    'yellow': Colors.amber,
    'blue': Colors.blue,
  };

  static MaterialColor getMaterialColor(String key) {
    final color = key == 'custom'
        ? customColor.value
        : (presets[key]?.shade500 ?? Colors.blue);
    return _createMaterialColor(color);
  }

  /// Returns the muted accent that is actually applied to the interface.
  /// Every preset remains recognisable, but avoids highly saturated colors.
  static Color previewColor(String key) => getMaterialColor(key).shade500;

  static Color neutralizeForUi(Color color) {
    final hsl = HSLColor.fromColor(color);
    final saturation = hsl.saturation <= .34
        ? hsl.saturation
        : (hsl.saturation * .42).clamp(.12, .34).toDouble();
    final lightness = hsl.lightness.clamp(.34, .46).toDouble();
    return hsl
        .withSaturation(saturation)
        .withLightness(lightness)
        .toColor();
  }

  // Create an opaque, accessible MaterialColor from a muted accent color.
  static MaterialColor _createMaterialColor(Color color) {
    final base = neutralizeForUi(color);
    final hsl = HSLColor.fromColor(base);
    Color tone(double lightness) => hsl.withLightness(lightness).toColor();

    final shades = <int, Color>{
      50: tone(.96),
      100: tone(.90),
      200: tone(.82),
      300: tone(.72),
      400: tone(.60),
      500: base,
      600: tone(.30),
      700: tone(.25),
      800: tone(.20),
      900: tone(.15),
    };

    return MaterialColor(base.toARGB32(), shades);
  }

  // Persistence
  static const _kStorageKey = 'app_theme_key';
  static const _kCustomColorKey = 'app_custom_color';

  static Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final saved = sp.getString(_kStorageKey);
      final savedColor = sp.getInt(_kCustomColorKey);

      if (savedColor != null) {
        customColor.value = Color(savedColor);
      }

      if (saved != null && (presets.containsKey(saved) || saved == 'custom')) {
        themeKey.value = saved;
      }
    } catch (_) {
      // ignore if persistence not available
    }
  }

  static Future<void> _saveThemeKey(String key) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kStorageKey, key);
    } catch (_) {
      // ignore write errors
    }
  }

  static Future<void> _saveCustomColor(Color color) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_kCustomColorKey, color.toARGB32());
    } catch (_) {
      // ignore write errors
    }
  }
}
