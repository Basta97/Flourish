import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  // Styles are created once: google_fonts builds a new style and looks the
  // font up on every call, and these are read in nearly every build.

  // Tabular figures keep amounts from jittering while they animate.
  static const _tabular = [FontFeature.tabularFigures()];

  static final TextStyle display = GoogleFonts.spaceGrotesk(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.08,
  );
  static final TextStyle headline = GoogleFonts.spaceGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.14,
  );
  static final TextStyle title = GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.22,
  );
  static final TextStyle subtitle = GoogleFonts.manrope(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.28,
  );
  static final TextStyle body = GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );
  static final TextStyle bodyMedium = GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.32,
  );
  static final TextStyle caption = GoogleFonts.manrope(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.28,
  );
  static final TextStyle overline = GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.25,
  );

  /// Small uppercase label above a value ("NET WORTH").
  static final TextStyle eyebrow = GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    height: 1.2,
  );

  static final TextStyle numberHero = GoogleFonts.spaceGrotesk(
    fontSize: 44,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.6,
    height: 1.0,
    fontFeatures: _tabular,
  );
  static final TextStyle numberLarge = GoogleFonts.spaceGrotesk(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.05,
    fontFeatures: _tabular,
  );
  static final TextStyle number = GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.15,
    fontFeatures: _tabular,
  );
  static final TextStyle numberSmall = GoogleFonts.spaceGrotesk(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.16,
    fontFeatures: _tabular,
  );
}
