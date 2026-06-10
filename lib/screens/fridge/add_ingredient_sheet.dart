import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/ingredient_category_resolver.dart';
import '../../core/util/ingredient_emoji.dart';
import '../../core/util/ingredient_shelf_life.dart';
import '../../models/ingredient.dart';

class AddIngredientSheet extends StatefulWidget {
  final void Function(Ingredient) onAdd;

  const AddIngredientSheet({super.key, required this.onAdd});

  @override
  State<AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends State<AddIngredientSheet> {
  static const _recentIngredientsKey = 'recent_ingredients';

  static const _quickIngredients = [
    ('달걀', '🥚', IngredientCategory.dairy, '개'),
    ('대파', '🧅', IngredientCategory.vegetable, '단'),
    ('두부', '🫙', IngredientCategory.dairy, '모'),
    ('당근', '🥕', IngredientCategory.vegetable, '개'),
    ('양파', '🧅', IngredientCategory.vegetable, '개'),
    ('감자', '🥔', IngredientCategory.vegetable, '개'),
    ('닭가슴살', '🍗', IngredientCategory.meat, 'g'),
    ('김치', '🥬', IngredientCategory.processed, 'g'),
  ];

  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  IngredientCategory? _selectedCategory;
  String _unit = '개';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 7));
  bool _expiryManuallySet = false; // 사용자가 직접 고르면 자동 제안 중단
  List<String> _recentIngredients = [];

  /// 이름 기반으로 일반적인 유통기한을 자동 제안 (직접 선택 전까지만)
  void _suggestExpiry(String name) {
    if (_expiryManuallySet || name.trim().isEmpty) return;
    final category = _selectedCategory ?? categoryForIngredient(name);
    _expiryDate =
        DateTime.now().add(Duration(days: shelfLifeDaysFor(name, category)));
  }

  @override
  void initState() {
    super.initState();
    _loadRecentIngredients();
  }

  Future<void> _loadRecentIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentIngredientsKey) ?? [];
    if (mounted) {
      setState(() {
        _recentIngredients = recent;
      });
    }
  }

  Future<void> _rememberRecentIngredient(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentIngredientsKey) ?? [];
    recent.remove(trimmed);
    recent.insert(0, trimmed);
    if (recent.length > 6) {
      recent.removeRange(6, recent.length);
    }
    await prefs.setStringList(_recentIngredientsKey, recent);
    if (mounted) {
      setState(() {
        _recentIngredients = recent;
      });
    }
  }

  Future<void> _removeRecentIngredient(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentIngredientsKey) ?? [];
    recent.removeWhere((e) => e == name);
    await prefs.setStringList(_recentIngredientsKey, recent);
    if (mounted) {
      setState(() {
        _recentIngredients = recent;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            '재료 추가',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (_recentIngredients.isNotEmpty) ...[
            const Text(
              '최근 추가한 재료',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentIngredients.map((ingredient) {
                return InputChip(
                  label: Text(
                    ingredient,
                    style: TextStyle(
                      fontSize: 13,
                      color: _nameCtrl.text == ingredient
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: _nameCtrl.text == ingredient
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _nameCtrl.text = ingredient;
                      _suggestExpiry(ingredient);
                    });
                  },
                  onDeleted: () => _removeRecentIngredient(ingredient),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  backgroundColor: _nameCtrl.text == ingredient
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            const Text(
              '빠른 선택',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickIngredients.map((q) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _nameCtrl.text = q.$1;
                      _selectedCategory = q.$3;
                      _unit = q.$4;
                      _suggestExpiry(q.$1);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _nameCtrl.text == q.$1
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _nameCtrl.text == q.$1
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      '${q.$2} ${q.$1}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _nameCtrl.text == q.$1
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: _nameCtrl.text == q.$1
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              hintText: '재료 이름 직접 입력',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _suggestExpiry(v)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '수량'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(hintText: '단위'),
                  items: ['개', 'g', 'ml', '단', '모', '봉', '공기', '큰술']
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _unit = v);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<IngredientCategory>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(hintText: '카테고리'),
            items: IngredientCategory.values
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(category.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(category.label),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (category) {
              setState(() => _selectedCategory = category);
            },
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _expiryDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _expiryDate = picked;
                  _expiryManuallySet = true;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '유통기한: ${_expiryDate.year}.${_expiryDate.month.toString().padLeft(2, '0')}.${_expiryDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('냉장고에 추가'),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final category = _selectedCategory ?? categoryForIngredient(name);

    final ingredient = Ingredient(
      id: const Uuid().v4(),
      name: name,
      category: category,
      quantity: double.tryParse(_qtyCtrl.text) ?? 1,
      unit: _unit,
      expiryDate: _expiryDate,
      emoji: emojiForIngredient(name, category),
    );
    widget.onAdd(ingredient);
    _rememberRecentIngredient(name);
    Navigator.pop(context);
  }
}
