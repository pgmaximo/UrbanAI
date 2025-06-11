import 'package:flutter/material.dart';
import 'package:urbanai/main.dart'; // Para acessar AppColors

/// Retorna um InputDecoration padronizado para os TextFormFields do app.
/// 
/// [label] é o texto que aparece no campo (ex: "Nome completo").
/// [icon] é o ícone opcional que aparecerá no início do campo.
InputDecoration getStyledInputDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.secondary),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: icon != null 
      ? Icon(icon, color: AppColors.secondary.withOpacity(0.7)) 
      : null,
    
    // Borda padrão
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    
    // Borda quando o campo está habilitado (não focado)
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
    ),
    
    // Borda quando o usuário clica no campo
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
    ),

    // Borda em caso de erro de validação
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.red, width: 1.0),
    ),

    // Borda focada quando há um erro de validação
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.red, width: 2.0),
    ),
  );
}