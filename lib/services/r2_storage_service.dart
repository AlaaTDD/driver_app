
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:minio/minio.dart';
import '../core/constants/env_constants.dart';



class R2StorageService {
  late final Minio _minio = Minio(
    endPoint: '${EnvConstants.r2AccountId}.r2.cloudflarestorage.com',
    accessKey: EnvConstants.r2AccessKeyId,
    secretKey: EnvConstants.r2SecretKey,
    region: 'auto',
  );

  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

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
      
      final bytes = await file.openRead(0, 4).first;
      final isJpg = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
      final isPng = bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
      final isPdf = bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;
      final isWebp = bytes.length >= 4 && bytes[0] == 0x52 && bytes[1] == 0x49;

      if (!isJpg && !isPng && !isPdf && !isWebp) {
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

      await _minio.putObject(
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
        await _minio.removeObject(EnvConstants.r2BucketName, objectName);
        debugPrint('🗑️ R2: Deleted $objectName');
      }
    } catch (e) {
      debugPrint('❌ R2: Delete failed: $e');
      throw Exception('Failed to delete file: $e');
    }
  }
}
