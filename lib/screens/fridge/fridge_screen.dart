import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ingredient.dart';
import '../../providers/fridge_provider.dart';
import 'add_ingredient_sheet.dart';

class FridgeScreen extends ConsumerWidget {
  const FridgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(fridgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 냉장고 🧊'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _showAnalyzeSheet(context),
              icon: const Icon(Icons.camera_alt_outlined,
                  size: 18, color: AppColors.primary),
              label: const Text(
                '카메라 인식',
                style:
                    TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('재료 추가', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ingredientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (ingredients) {
          final grouped = <IngredientCategory, List<Ingredient>>{};
          for (final i in ingredients) {
            grouped.putIfAbsent(i.category, () => []).add(i);
          }
          return ingredients.isEmpty
              ? _buildEmpty(context, ref)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final category = grouped.keys.elementAt(index);
                    final items = grouped[category]!;
                    return _CategorySection(
                      category: category,
                      items: items,
                      sectionIndex: index,
                      onDelete: (id) =>
                          ref.read(fridgeProvider.notifier).removeIngredient(id),
                    );
                  },
                );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🧊', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            '냉장고가 비어있어요',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '재료를 추가해 레시피를 추천받아 보세요!',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddSheet(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('재료 추가하기'),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddIngredientSheet(
        onAdd: (ingredient) =>
            ref.read(fridgeProvider.notifier).addIngredient(ingredient),
      ),
    );
  }

  void _showAnalyzeSheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📸 카메라 재료 인식'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🤖', style: TextStyle(fontSize: 40)),
                    SizedBox(height: 8),
                    Text(
                      'YOLOv8 식재료 인식',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '데모에서는 수동 입력을 사용해 주세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '실제 앱에서는 냉장고 사진을 촬영하면\nYOLOv8이 식재료를 자동으로 인식합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final IngredientCategory category;
  final List<Ingredient> items;
  final int sectionIndex;
  final void Function(String) onDelete;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.sectionIndex,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Icon(category.icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                category.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${items.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
        ...items.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _IngredientTile(
                  ingredient: e.value,
                  index: sectionIndex * 10 + e.key,
                  onDelete: onDelete,
                ),
              ),
            ),
      ],
    );
  }
}

class _IngredientTile extends StatelessWidget {
  final Ingredient ingredient;
  final int index;
  final void Function(String) onDelete;

  const _IngredientTile({
    required this.ingredient,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(ingredient.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(ingredient.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ingredient.isExpired
                ? AppColors.danger.withOpacity(0.4)
                : ingredient.isUrgent
                    ? AppColors.warning.withOpacity(0.4)
                    : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Text(ingredient.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${ingredient.quantity.toStringAsFixed(ingredient.quantity == ingredient.quantity.roundToDouble() ? 0 : 1)} ${ingredient.unit}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ingredient.expiryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ingredient.expiryLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ingredient.expiryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 30 * index))
        .fadeIn()
        .slideX(begin: 0.05);
  }
}
