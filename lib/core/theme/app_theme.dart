// En esta clase se define el tema de la aplicación
import 'package:flutter/material.dart';
import 'package:first_app/core/theme/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      // establecemos el uso de material design 3
      useMaterial3: true,
      // Definimos los colores de la aplicación
      scaffoldBackgroundColor: AppColors.backgroundColor,

      colorScheme: ColorScheme.light(
        primary: AppColors.primary, //Color primario
        secondary: AppColors.secondary, //Color secundario
        surface: AppColors.cardColor, //Color de los elementos de la UI
        error: AppColors.errorColor, //Color de error
        onPrimary: AppColors
            .buttonTextColor, // color de los textos sobre el color primario
        onSecondary: AppColors
            .buttonTextColor, // color de los textos sobre el color secundario
        onSurface: AppColors
            .textColor, // color de los textos sobre el color de superficie
      ),

      // Definimos el tema de los botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonColor, //color del boton
          foregroundColor: AppColors.buttonDisabledTextColor, // color del texto
          disabledBackgroundColor:
              AppColors.buttonDisabledColor, // color del boton deshabilitado
          disabledForegroundColor: AppColors
              .buttonDisabledTextColor, // color del texto deshabilitado
        ),
      ),

      // Definimos el tema de laAppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary, //color del AppBar
        foregroundColor: AppColors.buttonTextColor, // color del texto
      ),
    );
  }
}
