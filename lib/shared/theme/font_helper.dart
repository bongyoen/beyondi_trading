import 'package:flutter/material.dart';

TextStyle inter({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  FontStyle? fontStyle,
}) =>
    TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: TextDecoration.none,
    );

TextStyle poppins({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  FontStyle? fontStyle,
}) =>
    TextStyle(
      fontFamily: 'Poppins',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: TextDecoration.none,
    );
