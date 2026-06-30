import 'package:flutter/material.dart';

class AppTheme {
  static final Color seed = Colors.green;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: seed,
    brightness: Brightness.light,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: seed,
    brightness: Brightness.dark,
  );
}
