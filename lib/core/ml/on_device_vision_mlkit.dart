import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'on_device_vision.dart';

OnDeviceVision createOnDeviceVision() => const MlKitVision();

class MlKitVision implements OnDeviceVision {
  const MlKitVision();

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<int?> countFaces(String imagePath) async {
    if (!_supported) return null;
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );
    try {
      final faces = await detector.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return faces.length;
    } catch (error) {
      debugPrint('MLKIT_FACE $error');
      return null; // Never block the user because of the AI check itself.
    } finally {
      await detector.close();
    }
  }

  @override
  Future<String?> readText(String imagePath) async {
    if (!_supported) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return result.text;
    } catch (error) {
      debugPrint('MLKIT_OCR $error');
      return null;
    } finally {
      await recognizer.close();
    }
  }
}
