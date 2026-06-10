import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/ingredient_category_resolver.dart';
import '../../core/util/ingredient_emoji.dart';
import '../../core/util/ingredient_shelf_life.dart';
import '../../models/ingredient.dart';
import '../../services/cloud_functions_service.dart';

/// 영수증 인식 결과 확인/수정 시트.
/// 품목별 이름·유통기한을 수정한 뒤 한 번에 냉장고에 추가한다.
class ReceiptReviewSheet extends StatefulWidget {
  final List<ReceiptItem> items;
  final void Function(List<Ingredient> ingredients) onConfirm;

  const ReceiptReviewSheet({
    super.key,
    required this.items,
    required this.onConfirm,
  });

  @override
  State<ReceiptReviewSheet> createState() => _ReceiptReviewSheetState();
}

class _ReviewEntry {
  String name;
  double quantity;
  String unit;
  DateTime expiryDate;

  _ReviewEntry({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
  });

  IngredientCategory get category => categoryForIngredient(name);
  String get emoji => emojiForIngredient(name, category);
}

class _ReceiptReviewSheetState extends State<ReceiptReviewSheet> {
  late List<_ReviewEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.items.map((item) {
      final category = categoryForIngredient(item.name);
      return _ReviewEntry(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        expiryDate: DateTime.now().add(
          Duration(days: shelfLifeDaysFor(item.name, category)),
        ),
      );
    }).toList();
  }

  Future<void> _editName(int index) async {
    final controller = TextEditingController(text: _entries[index].name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('재료 이름 수정', style: TextStyle(fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '재료 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    setState(() {
      final entry = _entries[index];
      entry.name = newName;
      // 이름이 바뀌면 카테고리 기반 유통기한도 재계산
      entry.expiryDate = DateTime.now().add(
        Duration(days: shelfLifeDaysFor(newName, categoryForIngredient(newName))),
      );
    });
  }

  Future<void> _editExpiry(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entries[index].expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() => _entries[index].expiryDate = picked);
  }

  void _confirm() {
    final ingredients = _entries
        .map((e) => Ingredient(
              id: const Uuid().v4(),
              name: e.name,
              category: e.category,
              quantity: e.quantity,
              unit: e.unit,
              expiryDate: e.expiryDate,
              emoji: e.emoji,
            ))
        .toList();
    widget.onConfirm(ingredients);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('M/d');
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            '🧾 영수증 인식 결과',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '이름이나 유통기한을 탭해서 수정할 수 있어요',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: _entries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      '인식된 식재료가 없어요 😢\n영수증이 잘 보이게 다시 찍어보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Text(e.emoji, style: emojiStyle(24)),
                            const SizedBox(width: 10),
                            // 이름 (탭 → 수정)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _editName(i),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${e.quantity.toStringAsFixed(e.quantity == e.quantity.roundToDouble() ? 0 : 1)}${e.unit} · ${e.category.label}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 유통기한 (탭 → datePicker)
                            GestureDetector(
                              onTap: () => _editExpiry(i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '~${dateFmt.format(e.expiryDate)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close,
                                  size: 18, color: AppColors.textHint),
                              onPressed: () =>
                                  setState(() => _entries.removeAt(i)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _entries.isEmpty ? null : _confirm,
              child: Text('${_entries.length}개 모두 냉장고에 추가'),
            ),
          ),
        ],
      ),
    );
  }
}
