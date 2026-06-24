import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';
import '../constants/env_constants.dart';
import '../errors/exceptions.dart';
import 'package:snapix/core/utils/app_logger.dart';

class R2StorageService {
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  Future<String> uploadFile({
    required File file,
    required String path,
  }) async {
    try {
      final fileLength = await file.length();
      if (fileLength > _maxFileSizeBytes) {
        throw ValidationException('errorFileTooLarge');
      }
      if (fileLength == 0) {
        throw ValidationException('errorFileEmpty');
      }

      final fileExtension = file.path.split('.').last.toLowerCase();

      final bytes = await file.openRead(0, 4).first;
      final isJpg = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
      final isPng = bytes.length >= 4 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47;
      final isPdf = bytes.length >= 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;
      final isWebp = bytes.length >= 4 && bytes[0] == 0x52 && bytes[1] == 0x49;

      if (!isJpg && !isPng && !isPdf && !isWebp) {
        throw ValidationException('errorFileUnsupported');
      }

      final fileBytes = await file.readAsBytes();

      final uri =
          Uri.parse('${EnvConstants.supabaseUrl}/functions/v1/upload-file');
      final request = http.MultipartRequest('POST', uri);

      final token = SupabaseService.client.auth.currentSession?.accessToken ??
          EnvConstants.supabaseAnonKey;
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['action'] = 'upload';
      request.fields['path'] = path;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: file.path.split('/').last,
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseBody);

      if (response.statusCode != 200) {
        AppLogger.error(
            'R2: HTTP ${response.statusCode} — body: $responseBody');
        final errorMsg =
            (jsonResponse['error'] ?? jsonResponse['msg'] ?? jsonResponse['message'])
                ?.toString();
        throw ServerException(errorMsg ?? 'errorUploadFailed');
      }

      final url = jsonResponse['url'];
      AppLogger.debug(
          '📤 R2: Uploaded via Edge Function (${(fileLength / 1024).toStringAsFixed(0)} KB)');
      return url;
    } catch (e, st) {
      AppLogger.error('R2: Upload failed: $e\n$st');
      if (e is AppException) rethrow;
      throw ServerException('errorUploadFailed', details: e);
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final uri =
          Uri.parse('${EnvConstants.supabaseUrl}/functions/v1/upload-file');
      final request = http.MultipartRequest('POST', uri);

      final token = SupabaseService.client.auth.currentSession?.accessToken ??
          EnvConstants.supabaseAnonKey;
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['action'] = 'delete';
      request.fields['url'] = url;

      final response = await request.send();
      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        AppLogger.error(
            'R2: HTTP ${response.statusCode} — body: $responseBody');
        final jsonResponse = jsonDecode(responseBody);
        final errorMsg =
            (jsonResponse['error'] ?? jsonResponse['msg'] ?? jsonResponse['message'])
                ?.toString();
        throw ServerException(errorMsg ?? 'errorDeleteFailed');
      }
      AppLogger.debug('🗑️ R2: Deleted via Edge Function');
    } catch (e, st) {
      AppLogger.error('R2: Delete failed: $e\n$st');
      if (e is AppException) rethrow;
      throw ServerException('errorDeleteFailed', details: e);
    }
  }
}
