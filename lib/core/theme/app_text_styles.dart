import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get heading => GoogleFonts.poppins(fontWeight: FontWeight.w600);
  static TextStyle get headingBold => GoogleFonts.poppins(fontWeight: FontWeight.w700);
  static TextStyle get body => GoogleFonts.inter();
  static TextStyle get bodyMedium => GoogleFonts.inter(fontWeight: FontWeight.w500);
  static TextStyle get bodySemiBold => GoogleFonts.inter(fontWeight: FontWeight.w600);
  static TextStyle get label => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500);
  static TextStyle get caption => GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400);
  static TextStyle get number => GoogleFonts.poppins(fontWeight: FontWeight.w600, letterSpacing: -0.5);
  static TextStyle get numberBold => GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static TextStyle get numberMono => GoogleFonts.poppins(fontWeight: FontWeight.w500, letterSpacing: 0);
}
