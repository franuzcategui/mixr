import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const String _fontFamily = 'Inter';

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      fontFamily: _fontFamily,
      textTheme: ThemeData.light().textTheme.apply(fontFamily: _fontFamily),
    );
  }
}
