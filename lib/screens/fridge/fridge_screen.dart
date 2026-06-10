import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/ingredient_category_resolver.dart';
import '../../core/util/ingredient_emoji.dart';
import '../../core/util/ingredient_shelf_life.dart';
import '../../models/ingredient.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fridge_provider.dart';
import '../../services/cloud_functions_service.dart';
import 'add_ingredient_sheet.dart';
import 'camera_recognition_screen.dart';
import 'receipt_review_sheet.dart';

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
              onPressed: () => _showAnalyzeSheet(context, ref),
              icon: const Icon(
                Icons.camera_alt_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              label: const Text(
                '카메라 인식',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
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
        label: const Text(
          '재료 추가',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
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
                      onDelete: (id) => ref
                          .read(fridgeProvider.notifier)
                          .removeIngredient(id),
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

  Future<void> _showAnalyzeSheet(BuildContext context, WidgetRef ref) async {
    // 모바일: 카메라 촬영 vs 갤러리 선택
    // 웹: image_picker only (카메라 미지원)
    final source = await showModalBottomSheet<_RecognizeSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              '📸 재료 자동 인식',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              kIsWeb
                  ? 'Gemini AI가 사진에서 식재료를 찾아드려요'
                  : 'YOLOv8 + Gemini AI가 식재료를 자동으로 찾아드려요',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // 카메라 촬영: 모바일=실시간 YOLO 화면, 웹=image_picker camera
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: '카메라 촬영',
                    badge: kIsWeb ? null : 'YOLO',
                    onTap: () => Navigator.pop(ctx, _RecognizeSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                // 갤러리: 항상 image_picker gallery
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_outlined,
                    label: '갤러리 선택',
                    onTap: () => Navigator.pop(ctx, _RecognizeSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                // 영수증: 장본 품목 일괄 등록 + 유통기한 자동 설정
                Expanded(
                  child: _SourceButton(
                    icon: Icons.receipt_long_outlined,
                    label: '영수증 스캔',
                    badge: 'NEW',
                    onTap: () => Navigator.pop(ctx, _RecognizeSource.receipt),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    // 모바일 카메라 → 실시간 YOLO 화면으로 이동
    if (source == _RecognizeSource.camera && !kIsWeb) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CameraRecognitionScreen()),
      );
      return;
    }

    // 갤러리 / 웹 카메라 / 영수증 → image_picker 사용
    final picker = ImagePicker();
    final ImageSource pickerSource;
    if (source == _RecognizeSource.gallery) {
      pickerSource = ImageSource.gallery;
    } else if (source == _RecognizeSource.receipt) {
      // 영수증: 모바일=카메라 촬영, 웹=파일 선택
      pickerSource = kIsWeb ? ImageSource.gallery : ImageSource.camera;
    } else {
      pickerSource = ImageSource.camera; // 웹 카메라 촬영
    }
    final xFile = await picker.pickImage(
      source: pickerSource,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (xFile == null || !context.mounted) return;

    if (source == _RecognizeSource.receipt) {
      await _analyzeReceipt(context, ref, xFile);
      return;
    }

    // Firebase 미설정 시 시뮬레이션
    final firebaseAvailable = ref.read(firebaseAvailableProvider);
    if (!firebaseAvailable) {
      _showRecognizedIngredients(context, ref, ['달걀', '당근', '대파'], simulated: true);
      return;
    }

    // Gemini Vision 인식
    if (!context.mounted) return;
    _showLoadingDialog(context, '🤖 재료를 인식하고 있어요...');

    try {
      final ingredients = await CloudFunctionsService.recognizeIngredients(
        File(xFile.path),
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      _showRecognizedIngredients(context, ref, ingredients);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('인식 실패: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 영수증 사진 → Gemini 품목 추출 → 확인 시트 → 일괄 추가
  Future<void> _analyzeReceipt(
    BuildContext context,
    WidgetRef ref,
    XFile xFile,
  ) async {
    final firebaseAvailable = ref.read(firebaseAvailableProvider);

    List<ReceiptItem> items;
    if (!firebaseAvailable) {
      // 시뮬레이션 모드
      items = const [
        ReceiptItem(name: '우유', quantity: 1, unit: '개'),
        ReceiptItem(name: '달걀', quantity: 1, unit: '판'),
        ReceiptItem(name: '두부', quantity: 2, unit: '모'),
      ];
    } else {
      _showLoadingDialog(context, '🧾 영수증을 읽고 있어요...');
      try {
        final bytes = await xFile.readAsBytes();
        items = await CloudFunctionsService.parseReceipt(bytes);
        if (!context.mounted) return;
        Navigator.pop(context); // 로딩 닫기
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('영수증 인식 실패: $e'),
              backgroundColor: AppColors.danger),
        );
        return;
      }
    }

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptReviewSheet(
        items: items,
        onConfirm: (ingredients) {
          final notifier = ref.read(fridgeProvider.notifier);
          for (final ingredient in ingredients) {
            notifier.addIngredient(ingredient);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${ingredients.length}개 재료를 냉장고에 추가했어요 🧊'),
              backgroundColor: AppColors.secondary,
            ),
          );
        },
      ),
    );
  }

  void _showRecognizedIngredients(
    BuildContext context,
    WidgetRef ref,
    List<String> names, {
    bool simulated = false,
  }) {
    final selected = <String>{...names};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(simulated ? '🤖 인식 결과 (시뮬레이션)' : '🤖 인식된 재료'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (simulated)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Firebase 미연결 상태 — 예시 결과입니다',
                    style: TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                '냉장고에 추가할 재료를 선택하세요',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: names.map((name) {
                  final isSelected = selected.contains(name);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        selected.remove(name);
                      } else {
                        selected.add(name);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      final notifier = ref.read(fridgeProvider.notifier);
                      for (final name in selected) {
                        final category = categoryForIngredient(name);
                        notifier.addIngredient(
                          Ingredient(
                            id: const Uuid().v4(),
                            name: name,
                            category: category,
                            quantity: 1,
                            unit: '개',
                            expiryDate: DateTime.now().add(
                              Duration(
                                  days: shelfLifeDaysFor(name, category)),
                            ),
                            emoji: emojiForIngredient(name, category),
                          ),
                        );
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${selected.length}개 재료를 냉장고에 추가했어요 🧊',
                          ),
                          backgroundColor: AppColors.secondary,
                        ),
                      );
                    },
              child: Text('${selected.length}개 추가'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RecognizeSource { camera, gallery, receipt }

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 28, color: AppColors.primary),
                if (badge != null)
                  Positioned(
                    top: -6,
                    right: -18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
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
                Text(ingredient.emoji, style: emojiStyle(28)),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
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
