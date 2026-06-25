import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/editor_state.dart';

/// A native resource manager for Mesh2Motion that replaces and extends
/// the functionality of M3ResourceManager with support for memory buffers
/// and blob URLs on Web.
class M2MResourceManager {
  static final M2MResourceManager instance = M2MResourceManager._internal();
  M2MResourceManager._internal();

  /// Memory cache for buffers (useful for files picked via FilePicker on Web)
  final Map<String, Uint8List> _memoryBuffers = {};

  /// Registers a buffer in memory with a specific name/path.
  void registerBuffer(String path, Uint8List bytes) {
    M2MLogger.info('ResourceManager: Registering memory buffer for $path (${bytes.length} bytes)');
    _memoryBuffers[path] = bytes;
  }

  /// Fetches raw byte data as a [ByteBuffer].
  /// Supports: memory buffers, http/https, and assets.
  Future<ByteBuffer> loadBuffer(String path) async {
    // 1. Check memory cache first (for FilePicker results)
    if (_memoryBuffers.containsKey(path)) {
      M2MLogger.info('ResourceManager: Loading from memory: $path');
      return _memoryBuffers[path]!.buffer;
    }

    // 2. Check for URLs
    final isUrl = path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:');
    if (isUrl) {
      M2MLogger.info('ResourceManager: Fetching from URL: $path');
      final response = await http.get(Uri.parse(path));
      if (response.statusCode != 200) {
        throw Exception('Failed to load data from URL ($path): ${response.statusCode}');
      }
      return response.bodyBytes.buffer;
    }

    // 3. Check for local assets
    M2MLogger.info('ResourceManager: Loading from assets: $path');
    final fullPath = path.startsWith('assets/') || path.startsWith('packages/') ? path : 'assets/$path';
    try {
      final data = await rootBundle.load(fullPath);
      return data.buffer;
    } catch (e) {
      M2MLogger.error('ResourceManager: Failed to load asset $fullPath', e);
      rethrow;
    }
  }

  void clear() {
    _memoryBuffers.clear();
  }
}
