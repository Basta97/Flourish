import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  // Tabular figures keep amounts from jittering while they animate.
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle get display => GoogleFonts.spaceGrotesk(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.08,
  );
  static TextStyle get headline => GoogleFonts.spaceGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.14,
  );
  static TextStyle get title => GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.22,
  );
  static TextStyle get subtitle => GoogleFonts.manrope(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.28,
  );
  static TextStyle get body => GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );
  static TextStyle get bodyMedium => GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.32,
  );
  static TextStyle get caption => GoogleFonts.manrope(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.28,
  );
  static TextStyle get overline => GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.25,
  );

  /// Small uppercase label above a value ("NET WORTH").
  static TextStyle get eyebrow => GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    height: 1.2,
  );

  static TextStyle get numberHero => GoogleFonts.spaceGrotesk(
    fontSize: 44,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.6,
    height: 1.0,
    fontFeatures: _tabular,
  );
  static TextStyle get numberLarge => GoogleFonts.spaceGrotesk(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.05,
    fontFeatures: _tabular,
  );
  static TextStyle get number => GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.15,
    fontFeatures: _tabular,
  );
  static TextStyle get numberSmall => GoogleFonts.spaceGrotesk(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.16,
    fontFeatures: _tabular,
  );
}
