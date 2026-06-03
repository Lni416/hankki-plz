import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// SSD MobileNet / YOLOv8 TFLite 기반 식재료 감지 서비스 (모바일 전용)
///
/// 현재 번들 모델: COCO SSD MobileNet v1 (300×300 uint8 quant)
///   인식 가능: 사과·바나나·오렌지·브로콜리·당근·케이크·피자 등
///
/// 업그레이드:
///   scripts/download_yolo_model.sh 실행 → assets/models/food_yolov8n.tflite 교체
class YoloDetection {
  final String label;
  final String koreanLabel;
  final double confidence;
  final double x, y, width, height;

  const YoloDetection({
    required this.label,
    required this.koreanLabel,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  String toString() => '$koreanLabel (${(confidence * 100).toStringAsFixed(0)}%)';
}

class YoloService {
  static const _modelAsset  = 'assets/models/food_yolov8n.tflite';
  static const _labelsAsset = 'assets/models/food_labels.txt';

  // SSD MobileNet 입력 크기
  static const int _inputSize = 300;
  static const double _confThreshold = 0.45;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // ── 영어 → 한국어 재료명 ───────────────────────────────────────────────────
  static const Map<String, String> _koreanMap = {
    'banana': '바나나', 'apple': '사과', 'sandwich': '샌드위치',
    'orange': '오렌지', 'broccoli': '브로콜리', 'carrot': '당근',
    'hot dog': '소시지', 'pizza': '피자', 'donut': '도넛', 'cake': '케이크',
    'egg': '달걀', 'eggs': '달걀', 'chicken': '닭고기', 'pork': '돼지고기',
    'beef': '소고기', 'fish': '생선', 'shrimp': '새우', 'tofu': '두부',
    'onion': '양파', 'garlic': '마늘', 'potato': '감자', 'tomato': '토마토',
    'pepper': '고추', 'green onion': '대파', 'scallion': '대파',
    'lettuce': '상추', 'spinach': '시금치', 'mushroom': '버섯',
    'cucumber': '오이', 'cabbage': '배추', 'radish': '무',
    'sweet potato': '고구마', 'corn': '옥수수', 'avocado': '아보카도',
    'lemon': '레몬', 'strawberry': '딸기', 'grape': '포도',
    'watermelon': '수박', 'pineapple': '파인애플',
    'pear': '배', 'peach': '복숭아', 'rice': '쌀', 'bread': '빵',
    'milk': '우유', 'cheese': '치즈', 'butter': '버터',
    'kimchi': '김치', 'seaweed': '미역', 'salmon': '연어',
    'tuna': '참치', 'anchovy': '멸치', 'clam': '조개',
  };

  // COCO 모델에서 식재료로 간주할 라벨
  static const Set<String> _foodLabels = {
    'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot',
    'hot dog', 'pizza', 'donut', 'cake',
    'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl',
  };

  // ── 초기화 ────────────────────────────────────────────────────────────────
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
      final labelsData = await rootBundle.loadString(_labelsAsset);
      _labels = labelsData.split('\n').where((l) => l.trim().isNotEmpty).toList();
      _isInitialized = true;
      return true;
    } catch (_) {
      _isInitialized = false;
      return false;
    }
  }

  // ── CameraImage 감지 (실시간 스트림) ─────────────────────────────────────
  Future<List<YoloDetection>> detectFromCameraImage(CameraImage cameraImage) async {
    if (!_isInitialized) return [];
    try {
      final image = _cameraImageToRgb(cameraImage);
      if (image == null) return [];
      return _runInference(image, cameraImage.width, cameraImage.height);
    } catch (_) {
      return [];
    }
  }

  // ── Uint8List 감지 (정지 이미지) ─────────────────────────────────────────
  Future<List<YoloDetection>> detectFromBytes(Uint8List bytes) async {
    if (!_isInitialized) return [];
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return [];
      return _runInference(decoded, decoded.width, decoded.height);
    } catch (_) {
      return [];
    }
  }

  // ── SSD MobileNet 추론 ────────────────────────────────────────────────────
  // 출력: boxes[1,10,4] / classes[1,10] / scores[1,10] / count[1]
  List<YoloDetection> _runInference(img.Image source, int origW, int origH) {
    final interpreter = _interpreter;
    if (interpreter == null) return [];

    // 입력: [1, 300, 300, 3] uint8
    final resized = img.copyResize(source, width: _inputSize, height: _inputSize);
    final inputBytes = Uint8List(_inputSize * _inputSize * 3);
    int idx = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final p = resized.getPixel(x, y);
        inputBytes[idx++] = p.r.toInt();
        inputBytes[idx++] = p.g.toInt();
        inputBytes[idx++] = p.b.toInt();
      }
    }
    final input = inputBytes.reshape([1, _inputSize, _inputSize, 3]);

    // 출력 버퍼
    final boxes   = [List.generate(10, (_) => List.filled(4, 0.0))];
    final classes = [List.filled(10, 0.0)];
    final scores  = [List.filled(10, 0.0)];
    final count   = [0.0];

    interpreter.runForMultipleInputs([input], {0: boxes, 1: classes, 2: scores, 3: count});

    final numDetections = count[0].toInt().clamp(0, 10);
    final detections = <YoloDetection>[];

    for (int i = 0; i < numDetections; i++) {
      final score = scores[0][i];
      if (score < _confThreshold) continue;

      final classIdx = classes[0][i].toInt();
      // SSD labelmap의 첫 항목은 배경('???') 이므로 +1 offset
      final label = (classIdx + 1 < _labels.length) ? _labels[classIdx + 1].trim() : '';
      if (label.isEmpty || label == '???') continue;

      // COCO 80-class 모델에서 식재료만 필터
      if (_labels.length <= 100 && !_foodLabels.contains(label.toLowerCase())) continue;

      // 박스: [y1, x1, y2, x2] 정규화 → 픽셀 좌표
      final y1 = (boxes[0][i][0]).clamp(0.0, 1.0) * origH;
      final x1 = (boxes[0][i][1]).clamp(0.0, 1.0) * origW;
      final y2 = (boxes[0][i][2]).clamp(0.0, 1.0) * origH;
      final x2 = (boxes[0][i][3]).clamp(0.0, 1.0) * origW;

      final korean = _koreanMap[label.toLowerCase()] ?? label;
      detections.add(YoloDetection(
        label: label,
        koreanLabel: korean,
        confidence: score,
        x: x1,
        y: y1,
        width: (x2 - x1).abs(),
        height: (y2 - y1).abs(),
      ));
    }

    return detections;
  }

  // ── 카메라 이미지 → RGB 변환 ──────────────────────────────────────────────
  img.Image? _cameraImageToRgb(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA(cameraImage);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  img.Image _convertYUV420(CameraImage image) {
    final w = image.width, h = image.height;
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    final uvRowStride  = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 2;
    final out = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final yVal = yPlane[y * image.planes[0].bytesPerRow + x];
        final uvIdx = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
        final uVal = uPlane[uvIdx] - 128;
        final vVal = vPlane[uvIdx] - 128;
        final r = (yVal + 1.402 * vVal).clamp(0, 255).toInt();
        final g = (yVal - 0.344136 * uVal - 0.714136 * vVal).clamp(0, 255).toInt();
        final b = (yVal + 1.772 * uVal).clamp(0, 255).toInt();
        out.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return out;
  }

  img.Image _convertBGRA(CameraImage image) {
    final bytes = image.planes[0].bytes;
    final out = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final offset = y * image.planes[0].bytesPerRow + x * 4;
        out.setPixelRgba(x, y, bytes[offset + 2], bytes[offset + 1], bytes[offset], 255);
      }
    }
    return out;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
