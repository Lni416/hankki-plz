import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/ingredient_category_resolver.dart';
import '../../core/util/ingredient_emoji.dart';
import '../../core/util/ingredient_shelf_life.dart';
import '../../models/ingredient.dart';
import '../../providers/fridge_provider.dart';
import '../../services/cloud_functions_service.dart';
import '../../services/yolo_service.dart';

/// 실시간 카메라 화면 + YOLOv8 온디바이스 식재료 감지
///
/// 동작 흐름:
///  1) CameraPreview 실시간 표시
///  2) 매 프레임마다 YoloService 로 식재료 감지 → 바운딩 박스 오버레이
///  3) 화면 하단에 감지된 재료 목록 (실시간 업데이트)
///  4) '냉장고에 추가' 버튼 → 선택된 재료만 fridgeProvider 에 등록
///
/// 모델 파일이 없거나 초기화 실패 시 Gemini 폴백 모드로 자동 전환.
class CameraRecognitionScreen extends ConsumerStatefulWidget {
  const CameraRecognitionScreen({super.key});

  @override
  ConsumerState<CameraRecognitionScreen> createState() =>
      _CameraRecognitionScreenState();
}

class _CameraRecognitionScreenState
    extends ConsumerState<CameraRecognitionScreen>
    with WidgetsBindingObserver {
  // ── 카메라 ─────────────────────────────────────────────────────────────────
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _cameraReady = false;
  int _cameraIndex = 0; // 0 = 후면

  // ── YOLO ─────────────────────────────────────────────────────────────────
  final YoloService _yolo = YoloService();
  bool _yoloReady = false;
  bool _detecting = false;

  // ── 감지 결과 ────────────────────────────────────────────────────────────
  List<YoloDetection> _detections = [];
  // 누적 감지 (확신도 높은 것만 유지)
  Map<String, _AccDetection> _accumulated = {};
  Timer? _accumTimer;

  // ── 선택된 재료 ───────────────────────────────────────────────────────────
  Set<String> _selected = {};

  // ── UI 상태 ───────────────────────────────────────────────────────────────
  bool _paused = false; // true = 캡처 후 정지 모드
  String _statusMsg = '카메라 초기화 중...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _statusMsg = '카메라를 찾을 수 없어요');
        return;
      }
      await _startCamera(_cameras[_cameraIndex]);
    } catch (e) {
      setState(() => _statusMsg = '카메라 초기화 실패: $e');
    }
  }

  Future<void> _startCamera(CameraDescription desc) async {
    final ctrl = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    try {
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = ctrl;
        _cameraReady = true;
        _statusMsg = 'YOLO 모델 로딩 중...';
      });
      // YOLO 모델 초기화
      final ok = await _yolo.initialize();
      if (!mounted) return;
      setState(() {
        _yoloReady = ok;
        _statusMsg = ok ? '재료를 카메라에 비춰주세요 📸' : '모델 미설치 — 촬영 후 Gemini로 인식합니다';
      });
      if (ok) _startDetectionStream();
    } catch (e) {
      setState(() => _statusMsg = '카메라 오류: $e');
    }
  }

  // ── 실시간 감지 루프 ──────────────────────────────────────────────────────
  void _startDetectionStream() {
    _cameraController?.startImageStream((CameraImage frame) async {
      if (_detecting || _paused || !_yoloReady) return;
      _detecting = true;
      try {
        final results = await _yolo.detectFromCameraImage(frame);
        if (!mounted) return;
        setState(() => _detections = results);
        _updateAccumulated(results);
      } finally {
        _detecting = false;
      }
    });
  }

  void _updateAccumulated(List<YoloDetection> detections) {
    final now = DateTime.now();
    for (final d in detections) {
      final existing = _accumulated[d.koreanLabel];
      if (existing == null || d.confidence > existing.confidence) {
        _accumulated[d.koreanLabel] = _AccDetection(
          label: d.koreanLabel,
          confidence: d.confidence,
          lastSeen: now,
        );
        // 새 재료 자동 선택
        _selected.add(d.koreanLabel);
      }
    }
    // 2초 이상 안 보이면 제거
    _accumulated.removeWhere((k, v) => now.difference(v.lastSeen).inSeconds > 2);
    _selected.removeWhere((k) => !_accumulated.containsKey(k));
  }

  // ── 카메라 전후면 전환 ────────────────────────────────────────────────────
  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    setState(() {
      _cameraReady = false;
      _detections = [];
      _accumulated = {};
      _selected = {};
    });
    await _startCamera(_cameras[_cameraIndex]);
  }

  // ── 정지 캡처 (YOLO 없을 때는 Gemini로) ─────────────────────────────────
  Future<void> _capture() async {
    if (_cameraController == null || !_cameraReady) return;
    setState(() => _paused = true);
    await _cameraController?.stopImageStream();

    if (_yoloReady) {
      // YOLO 감지 결과 그대로 사용
      if (_accumulated.isEmpty) {
        setState(() {
          _statusMsg = '인식된 재료가 없어요. 다시 촬영해보세요.';
          _paused = false;
        });
        _startDetectionStream();
      }
      return;
    }

    // YOLO 없음 → 촬영 후 Gemini 인식
    try {
      final xFile = await _cameraController!.takePicture();
      if (!mounted) return;
      setState(() => _statusMsg = '🤖 Gemini AI가 재료를 인식 중...');
      // cloud functions 호출
      final file = xFile;
      // (Gemini 폴백: CloudFunctionsService 호출)
      // 여기선 데모 결과 표시 — 실 배포 시 CloudFunctionsService.recognizeIngredients 사용
      final names = await _callGemini(file.path);
      if (!mounted) return;
      setState(() {
        for (final n in names) {
          _accumulated[n] = _AccDetection(label: n, confidence: 0.9, lastSeen: DateTime.now());
          _selected.add(n);
        }
        _statusMsg = '${names.length}개 재료가 인식되었어요';
      });
    } catch (e) {
      setState(() {
        _statusMsg = '인식 실패: $e';
        _paused = false;
      });
      _startDetectionStream();
    }
  }

  Future<List<String>> _callGemini(String imagePath) async {
    try {
      return await CloudFunctionsService.recognizeIngredients(File(imagePath));
    } catch (_) {
      return [];
    }
  }

  // ── 재개 ─────────────────────────────────────────────────────────────────
  void _resume() {
    setState(() {
      _paused = false;
      _accumulated = {};
      _selected = {};
      _detections = [];
      _statusMsg = '재료를 카메라에 비춰주세요 📸';
    });
    _startDetectionStream();
  }

  // ── 냉장고 추가 ──────────────────────────────────────────────────────────
  void _addToFridge() {
    if (_selected.isEmpty) return;
    final notifier = ref.read(fridgeProvider.notifier);
    for (final name in _selected) {
      final category = categoryForIngredient(name);
      notifier.addIngredient(Ingredient(
        id: const Uuid().v4(),
        name: name,
        category: category,
        quantity: 1,
        unit: '개',
        expiryDate: DateTime.now()
            .add(Duration(days: shelfLifeDaysFor(name, category))),
        emoji: emojiForIngredient(name, category),
      ));
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_selected.length}개 재료를 냉장고에 추가했어요 🧊'),
      backgroundColor: AppColors.secondary,
    ));
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accumTimer?.cancel();
    _cameraController?.dispose();
    _yolo.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ① 카메라 프리뷰
            if (_cameraReady && _cameraController != null)
              Positioned.fill(child: _buildCameraPreview())
            else
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),

            // ② YOLO 바운딩 박스
            if (_cameraReady && _yoloReady && _detections.isNotEmpty)
              Positioned.fill(child: _buildBoundingBoxes()),

            // ③ 상단 툴바
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // ④ 하단 패널
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return LayoutBuilder(builder: (context, constraints) {
      final scale = constraints.maxWidth /
          (_cameraController!.value.previewSize!.height);
      return Transform.scale(
        scale: scale,
        child: Center(child: CameraPreview(_cameraController!)),
      );
    });
  }

  Widget _buildBoundingBoxes() {
    return LayoutBuilder(builder: (context, constraints) {
      final previewSize = _cameraController!.value.previewSize!;
      return CustomPaint(
        painter: _BoundingBoxPainter(
          detections: _detections,
          previewWidth: previewSize.height, // landscape → portrait swap
          previewHeight: previewSize.width,
          canvasWidth: constraints.maxWidth,
          canvasHeight: constraints.maxHeight,
        ),
      );
    });
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              '재료 자동 인식',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: _cameras.length > 1 ? _flipCamera : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final items = _accumulated.values.toList();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상태 메시지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              _statusMsg,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),

          // 감지된 재료 칩
          if (items.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: items.map((item) {
                final isSelected = _selected.contains(item.label);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selected.remove(item.label);
                    } else {
                      _selected.add(item.label);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.white38,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(item.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white70
                                : Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // 버튼 row
          Row(
            children: [
              if (_paused)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resume,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    label: const Text('다시 촬영',
                        style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _cameraReady ? _capture : null,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_yoloReady ? '촬영 확정' : '촬영'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              if (_selected.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addToFridge,
                    icon: const Icon(Icons.add),
                    label: Text('${_selected.length}개 추가'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── 바운딩 박스 페인터 ────────────────────────────────────────────────────────
class _BoundingBoxPainter extends CustomPainter {
  final List<YoloDetection> detections;
  final double previewWidth, previewHeight;
  final double canvasWidth, canvasHeight;

  const _BoundingBoxPainter({
    required this.detections,
    required this.previewWidth,
    required this.previewHeight,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = canvasWidth / previewWidth;
    final scaleY = canvasHeight / previewHeight;

    final boxPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final bgPaint = Paint()..color = AppColors.primary.withValues(alpha: 0.75);

    for (final d in detections) {
      final rect = Rect.fromLTWH(
        d.x * scaleX,
        d.y * scaleY,
        d.width * scaleX,
        d.height * scaleY,
      );
      // 박스
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        boxPaint,
      );
      // 라벨 배경
      final labelText = '${d.koreanLabel} ${(d.confidence * 100).toStringAsFixed(0)}%';
      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(
        rect.left, rect.top - tp.height - 6,
        tp.width + 12, tp.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        bgPaint,
      );
      tp.paint(canvas, Offset(labelRect.left + 6, labelRect.top + 3));
    }
  }

  @override
  bool shouldRepaint(_BoundingBoxPainter old) => old.detections != detections;
}

// ── 누적 감지 헬퍼 ────────────────────────────────────────────────────────────
class _AccDetection {
  final String label;
  final double confidence;
  final DateTime lastSeen;
  const _AccDetection({
    required this.label,
    required this.confidence,
    required this.lastSeen,
  });
}
