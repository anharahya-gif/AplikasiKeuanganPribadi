import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final int iconCode; // Icon data point (codePoint)
  final int colorCode; // Hex color value (ARGB)
  final String type; // 'income' or 'expense'
  final bool isDefault; // system default or user custom

  Category({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorCode,
    required this.type,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_code': iconCode,
      'color_code': colorCode,
      'type': type,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      iconCode: map['icon_code'] ?? Icons.category.codePoint,
      colorCode: map['color_code'] ?? 0xFF9E9E9E,
      type: map['type'] ?? 'expense',
      isDefault: (map['is_default'] ?? 0) == 1,
    );
  }
}
