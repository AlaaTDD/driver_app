
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:minio/minio.dart';
import '../core/constants/env_constants.dart';



class R2StorageService {
  Minio? _minio;

  
  static const int _maxFileSizeBytes = 10 * 1024 * 1024;

  
  static const Set<String> _allowedExtensions = {
    'jpg', 'jpeg', 'png', 'webp', 'pdf',
  };

  Minio _getClient() {
    if (_minio != null) return _minio!;
    try {
      _minio = Minio(
        endPoint: '${EnvConstants.r2AccountId}.r2.cloudflarestorage.com',
        accessKey: EnvConstants.r2AccessKeyId,
        secretKey: EnvConstants.r2SecretKey,
        region: 'auto',
      );
    } catch (e) {
      throw Exception('R2 initialization failed: $e');
    }
    return _minio!;
  }

  Future<String> uploadFile({
    required File file,
    required String path,
  }) async {
    try {
      
      final fileLength = await file.length();
      if (fileLength > _maxFileSizeBytes) {
        throw Exception(
            'errorFileTooLarge');
      }
      if (fileLength == 0) {
        throw Exception('errorFileEmpty');
      }

      
      final fileExtension = file.path.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(fileExtension)) {
        throw Exception('errorFileUnsupported');
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}';
      final fullPath = '$path/$fileName';

      String contentType = 'application/octet-stream';
      if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (fileExtension == 'png') {
        contentType = 'image/png';
      } else if (fileExtension == 'webp') {
        contentType = 'image/webp';
      } else if (fileExtension == 'pdf') {
        contentType = 'application/pdf';
      }

      final stream = file.openRead().map((chunk) => Uint8List.fromList(chunk));

      await _getClient().putObject(
        EnvConstants.r2BucketName,
        fullPath,
        stream,
        size: fileLength,
        metadata: {'Content-Type': contentType},
      );

      final url = '${EnvConstants.r2PublicUrl}/$fullPath';
      debugPrint('📤 R2: Uploaded $fullPath (${(fileLength / 1024).toStringAsFixed(0)} KB)');
      return url;
    } catch (e) {
      debugPrint('❌ R2: Upload failed: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final publicUrlPrefix = '${EnvConstants.r2PublicUrl}/';
      if (url.startsWith(publicUrlPrefix)) {
        final objectName = url.substring(publicUrlPrefix.length);
        await _getClient().removeObject(EnvConstants.r2BucketName, objectName);
        debugPrint('🗑️ R2: Deleted $objectName');
      }
    } catch (e) {
      debugPrint('❌ R2: Delete failed: $e');
      throw Exception('Failed to delete file: $e');
    }
  }
}
