import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const navy = Color(0xFF023E8A);
  static const primary = Color(0xFF00B4D8);
  static const secondary = Color(0xFF0077B6);
  static const accent = Color(0xFF90E0EF);
  static const background = Color(0xFFF8FAFC);
  static const textDark = Color(0xFF03045E);
  static const textGrey = Color(0xFF64748B);
  static const nectarGold = Color(0xFFFFB703);
}

class AppTextStyles {
  static TextStyle h1 = GoogleFonts.manrope(
    fontSize: 24, 
    fontWeight: FontWeight.w800, 
    color: AppColors.textDark
  );
  static TextStyle h2 = GoogleFonts.manrope(
    fontSize: 16, 
    fontWeight: FontWeight.w700, 
    color: AppColors.textDark, 
    letterSpacing: 0.5
  );
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12, 
    color: AppColors.textGrey, 
    fontWeight: FontWeight.w500
  );
}

class AppDecorations {
  static BoxShadow softShadow = BoxShadow(
    color: AppColors.navy.withValues(alpha: 0.08), 
    blurRadius: 15, 
    offset: const Offset(0, 5)
  );

  static BoxDecoration glassCard = BoxDecoration(
    color: Colors.white, 
    borderRadius: BorderRadius.circular(20), 
    boxShadow: [softShadow]
  );
  
  static InputDecoration smartInput(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
    prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15), 
      borderSide: BorderSide.none
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15), 
      borderSide: BorderSide(color: Colors.blue.shade50)
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15), 
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5)
    ),
  );
}