import 'package:flutter/material.dart';

// ── 필터 바용 필 버튼 ──────────────────────────────────────────
// 선택 전: 회색 배경 [라벨 ▾]
// 선택 후: 파란 배경 [라벨: 값 ▾]
class FilterPill<T> extends StatelessWidget {
  final String label;
  final String selectedLabel;
  final bool isActive;
  final List<(String, T?)> options;
  final void Function(T?) onSelected;
  final Color activeColor;

  const FilterPill({
    super.key,
    required this.label,
    required this.selectedLabel,
    required this.isActive,
    required this.options,
    required this.onSelected,
    this.activeColor = const Color(0xFF1565C0),
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : Colors.grey.shade600;
    final bg = isActive
        ? activeColor.withValues(alpha: 0.08)
        : Colors.grey.shade100;

    return PopupMenuButton<T?>(
      onSelected: onSelected,
      itemBuilder: (_) => options
          .map((o) => PopupMenuItem<T?>(
                value: o.$2,
                child: Text(o.$1, style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? '$label: $selectedLabel' : label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

// ── 폼 다이얼로그용 선택 필드 ──────────────────────────────────
// OutlineInputBorder TextField와 동일한 외형
// InputDecorator + PopupMenuButton 조합
class FormSelect<T> extends StatelessWidget {
  final String label;
  final String? currentLabel; // null 이면 hint 표시
  final String hint;
  final List<(String, T?)> options;
  final void Function(T?) onSelected;
  final bool isRequired;

  const FormSelect({
    super.key,
    required this.label,
    required this.currentLabel,
    required this.options,
    required this.onSelected,
    this.hint = '선택하세요',
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = currentLabel != null && currentLabel!.isNotEmpty;
    return PopupMenuButton<T?>(
      onSelected: onSelected,
      itemBuilder: (_) => options
          .map((o) => PopupMenuItem<T?>(
                value: o.$2,
                child: Text(o.$1, style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: const Icon(Icons.keyboard_arrow_down, size: 20),
        ),
        child: Text(
          hasValue ? currentLabel! : hint,
          style: TextStyle(
            fontSize: 14,
            color: hasValue ? Colors.black87 : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
