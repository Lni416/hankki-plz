import 'dart:typed_data';

/// 웹/플랫폼 미지원 시 사용되는 YoloService 스텁
/// dart:ffi 없이 컴파일 가능 — 항상 빈 결과 반환
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
  bool get isInitialized => false;

  Future<bool> initialize() async => false;

  Future<List<YoloDetection>> detectFromCameraImage(dynamic cameraImage) async => [];

  Future<List<YoloDetection>> detectFromBytes(Uint8List bytes) async => [];

  void dispose() {}
}
