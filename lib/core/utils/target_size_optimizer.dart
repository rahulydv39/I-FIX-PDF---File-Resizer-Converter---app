/// Target Size Optimizer
/// Compresses or expands image bytes to approach a target file size.
///
/// CORE RULE:
///   input > target  →  compress only (never upscale)
///   input < target  →  expand quality/resolution toward target
library;

import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class _ProcessArgs {
  final Uint8List inputBytes;
  final int targetKB;
  final RootIsolateToken? token;

  _ProcessArgs({
    required this.inputBytes,
    required this.targetKB,
    this.token,
  });
}

class TargetSizeOptimizer {
  /// Entry point — offloads work to a background isolate.
  static Future<Uint8List> processTargetSize({
    required Uint8List inputBytes,
    required int targetKB,
    required bool useTargetSize,
  }) async {
    if (!useTargetSize) return inputBytes;

    final token = RootIsolateToken.instance;

    return compute(
      _isolatedAdaptiveCompress,
      _ProcessArgs(
        inputBytes: inputBytes,
        targetKB: targetKB,
        token: token,
      ),
    );
  }

  // ── Isolate entry ──────────────────────────────────────────────────────────

  static Future<Uint8List> _isolatedAdaptiveCompress(_ProcessArgs args) async {
    if (args.token != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(args.token!);
    }

    final Uint8List inputBytes = args.inputBytes;
    final double targetKB = args.targetKB.toDouble();
    final double inputKB = inputBytes.length / 1024;

    print('INPUT:  ${inputKB.toStringAsFixed(1)} KB');
    print('TARGET: ${targetKB.toStringAsFixed(1)} KB');

    final Uint8List result;

    if (inputKB > targetKB) {
      // ── Case 1: input is larger → COMPRESS ONLY ──────────────────────────
      result = await _compressToTarget(inputBytes, targetKB);
    } else {
      // ── Case 2: input is smaller → EXPAND toward target ──────────────────
      result = await _expandToTarget(inputBytes, targetKB);
    }

    print('OUTPUT: ${(result.length / 1024).toStringAsFixed(1)} KB');

    return result;
  }

  // ── Compress ───────────────────────────────────────────────────────────────

  /// Binary-search on JPEG quality to get output ≤ targetKB * 0.98.
  /// NEVER resizes; adjusts quality only.
  static Future<Uint8List> _compressToTarget(
    Uint8List inputBytes,
    double targetKB,
  ) async {
    int minQ = 5;
    int maxQ = 95;
    // Initialise best to a hard fallback at quality 5 so we always have
    // something under target even for extreme ratios.
    Uint8List best = await FlutterImageCompress.compressWithList(
      inputBytes,
      quality: 5,
      format: CompressFormat.jpeg,
    );

    for (int i = 0; i < 7; i++) {
      final int q = (minQ + maxQ) ~/ 2;

      final Uint8List output = await FlutterImageCompress.compressWithList(
        inputBytes,
        quality: q,
        format: CompressFormat.jpeg,
      );

      final double size = output.length / 1024;

      if (size <= targetKB * 0.98) {
        // Under target — save and try a higher quality (bigger but still OK).
        best = output;
        minQ = q + 1;
      } else {
        // Over target — must reduce quality further.
        maxQ = q - 1;
      }

      if (minQ > maxQ) break;
    }

    return best;
  }

  // ── Expand ─────────────────────────────────────────────────────────────────

  /// Tries to bring a small image closer to targetKB.
  ///
  /// Strategy:
  ///   1. Re-encode at maximum JPEG quality (95).
  ///   2. If still well below 90 % of target, upscale resolution once
  ///      proportionally, then re-encode.
  ///   3. Never exceed the target.
  static Future<Uint8List> _expandToTarget(
    Uint8List inputBytes,
    double targetKB,
  ) async {
    // Step 1: re-encode at quality 95 — often enough to approach target.
    Uint8List output = await FlutterImageCompress.compressWithList(
      inputBytes,
      quality: 95,
      format: CompressFormat.jpeg,
    );

    final double q95SizeKB = output.length / 1024;

    // Step 2: if re-encoding at q95 is still < 90 % of target, upscale once.
    if (q95SizeKB < targetKB * 0.9) {
      final img.Image? image = img.decodeImage(inputBytes);
      if (image != null) {
        final double inputKB = inputBytes.length / 1024;
        // Conservative scale factor so we don't shoot past the target.
        final double scaleFactor = sqrt(targetKB / inputKB) * 0.85;

        final img.Image scaled = img.copyResize(
          image,
          width: (image.width * scaleFactor).toInt().clamp(1, 8192),
          height: (image.height * scaleFactor).toInt().clamp(1, 8192),
        );

        final Uint8List upscaledBytes =
            Uint8List.fromList(img.encodeJpg(scaled, quality: 95));

        // Compress the upscaled bytes to bring them under target if they
        // overshot (possible when scaleFactor > 1).
        final double upscaledKB = upscaledBytes.length / 1024;
        if (upscaledKB > targetKB) {
          output = await _compressToTarget(upscaledBytes, targetKB);
        } else {
          output = upscaledBytes;
        }
      }
    }

    // Final guard: output must NEVER exceed target.
    if (output.length / 1024 > targetKB) {
      output = await _compressToTarget(output, targetKB);
    }

    return output;
  }
}
