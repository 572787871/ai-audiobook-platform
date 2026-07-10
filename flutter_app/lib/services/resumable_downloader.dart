/// 生产级可恢复下载器：
/// - 支持 Range 断点续传（.part 临时文件）
/// - 自动重试，指数退避
/// - 校验 Content-Length
/// - 支持 SHA256 校验（hex 字符串或内置前缀）
/// - 下载完成后原子重命名
/// - 下载失败保留已下载部分（.part）
/// - 支持取消（CancelToken 式）与继续（再次调用即续传）
/// - 进度回调：已下载字节、总字节、速度
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// 下载进度快照。
class DownloadProgress {
  final int received;
  final int total;
  final double speedBytesPerSec;
  final String? sourceId;
  final String? errorMessage;
  final bool done;
  final bool cancelled;

  const DownloadProgress({
    required this.received,
    required this.total,
    this.speedBytesPerSec = 0,
    this.sourceId,
    this.errorMessage,
    this.done = false,
    this.cancelled = false,
  });

  double get fraction {
    if (total <= 0) return received > 0 ? 1.0 : 0.0;
    return (received / total).clamp(0.0, 1.0);
  }

  DownloadProgress copyWith({
    int? received,
    int? total,
    double? speedBytesPerSec,
    String? sourceId,
    String? errorMessage,
    bool? done,
    bool? cancelled,
  }) =>
      DownloadProgress(
        received: received ?? this.received,
        total: total ?? this.total,
        speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
        sourceId: sourceId ?? this.sourceId,
        errorMessage: errorMessage ?? this.errorMessage,
        done: done ?? this.done,
        cancelled: cancelled ?? this.cancelled,
      );
}

/// 可取消的下载句柄。
class DownloadHandle {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class ResumableDownloader {
  ResumableDownloader._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 20),
  ));

  static const int _maxRetries = 6;
  static const Duration _baseBackoff = Duration(seconds: 2);
  static const int _minPartSizeForRange = 1024; // 小于此不尝试续传

  /// 下载单个文件，支持断点续传与多源回退。
  ///
  /// [urlProviders] 按顺序提供候选 URL（已含镜像/备用/官方）。
  /// [expectedSha256] 完整或前缀 SHA256；为 null 时跳过校验。
  /// [onProgress] 回调已下载/总字节/速度。
  static Future<File> download({
    required List<String> urls,
    required String outputPath,
    String? expectedSha256,
    void Function(DownloadProgress)? onProgress,
    DownloadHandle? handle,
    int maxRetries = _maxRetries,
  }) async {
    if (urls.isEmpty) {
      throw ArgumentError('至少需要一个下载地址');
    }

    final target = File(outputPath);
    final partPath = '$outputPath.part';
    final partFile = File(partPath);

    // 已完成且校验通过：直接返回。
    if (await target.exists() && await target.length() > 0) {
      if (expectedSha256 == null ||
          shaMatches(await _sha256Of(target), expectedSha256)) {
        onProgress?.call(DownloadProgress(
            received: await target.length(),
            total: await target.length(),
            done: true));
        return target;
      }
      await target.delete();
    }

    DioException? lastError;
    for (var urlIndex = 0; urlIndex < urls.length; urlIndex++) {
      final url = urls[urlIndex];
      try {
        await _downloadSingle(
          url: url,
          partFile: partFile,
          target: target,
          expectedSha256: expectedSha256,
          onProgress: (p) => onProgress?.call(p.copyWith(sourceId: 'src$urlIndex')),
          handle: handle,
          maxRetries: maxRetries,
        );
        return target;
      } on DownloadCancelledException {
        rethrow;
      } on ShaMismatchException {
        rethrow; // 校验失败不可重试
      } on DioException catch (e) {
        lastError = e;
        // 尝试下一个源。
        continue;
      } catch (e) {
        lastError = DioException(requestOptions: RequestOptions(), error: e);
        continue;
      }
    }
    throw DownloadFailedException(
        '所有下载源均失败: ${lastError?.message ?? lastError.toString()}');
  }

  static Future<void> _downloadSingle({
    required String url,
    required File partFile,
    required File target,
    String? expectedSha256,
    void Function(DownloadProgress)? onProgress,
    DownloadHandle? handle,
    int maxRetries = _maxRetries,
  }) async {
    final existing = await partFile.exists() ? await partFile.length() : 0;
    var received = existing;
    var total = existing;
    var lastTick = DateTime.now();
    var lastReceived = received;
    var attempt = 0;

    while (attempt <= maxRetries) {
      if (handle?.isCancelled == true) {
        throw const DownloadCancelledException();
      }
      try {
        final useRange = existing > _minPartSizeForRange;
        final headers = <String, dynamic>{};
        if (useRange) headers['range'] = 'bytes=$existing-';

        final response = await _dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers: headers,
            followRedirects: true,
            maxRedirects: 5,
          ),
        );
        final stream = response.data;
        if (stream == null) throw const DownloadFailedException('空响应');

        // 确定总大小：优先 Content-Range，其次 Content-Length。
        final contentLength =
            int.tryParse(response.headers.value('content-length') ?? '');
        final contentRange = response.headers.value('content-range');
        if (contentRange != null && contentRange.startsWith('bytes ')) {
          final endPart = contentRange.substring(contentRange.indexOf('/') + 1);
          final full = int.tryParse(endPart);
          if (full != null && full > 0) total = full;
        } else if (contentLength != null) {
          // 续传时 content-length 是剩余部分；否则是全长。
          total = useRange ? existing + contentLength : contentLength;
        }

        // 校验服务端是否真的支持 Range（206 或 200）。
        final status = response.statusCode ?? 0;
        final appendMode = status == 206 || (!useRange && status == 200);
        final sink = partFile.openWrite(mode: appendMode ? FileMode.append : FileMode.write);
        if (!appendMode && existing > 0) {
          // 不支持续传，从头写。
          received = 0;
        }

        await for (final chunk in stream.stream) {
          if (handle?.isCancelled == true) {
            await sink.close();
            throw const DownloadCancelledException();
          }
          sink.add(chunk);
          received += chunk.length;
          final now = DateTime.now();
          final dt = now.difference(lastTick).inMilliseconds;
          if (dt >= 500) {
            final speed = (received - lastReceived) * 1000 / dt;
            lastReceived = received;
            lastTick = now;
            onProgress?.call(DownloadProgress(
              received: received,
              total: total,
              speedBytesPerSec: speed,
            ));
          }
        }
        await sink.close();

        // 校验 Content-Length 是否一致（若已知）。
        if (total > 0 && received != total) {
          throw const DownloadFailedException('下载大小与 Content-Length 不一致');
        }
        onProgress?.call(DownloadProgress(
            received: received, total: total, speedBytesPerSec: 0));

        // SHA256 校验。
        if (expectedSha256 != null) {
          final actual = await _sha256Of(partFile);
          if (!shaMatches(actual, expectedSha256)) {
            throw ShaMismatchException(
                'SHA256 校验失败（期望 $expectedSha256，实际 ${actual.substring(0, min(8, actual.length))}…）');
          }
        }

        // 原子重命名。
        if (await target.exists()) await target.delete();
        await partFile.rename(target.path);
        onProgress?.call(DownloadProgress(
            received: received, total: total, done: true));
        return;
      } on DownloadCancelledException {
        rethrow;
      } on ShaMismatchException {
        rethrow; // 校验失败不可重试，立即失败
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) rethrow;
        final backoff = _baseBackoff * (1 << (attempt - 1));
        final capped = backoff > const Duration(seconds: 60)
            ? const Duration(seconds: 60)
            : backoff;
        // 保留已下载部分（不删除 .part），等待退避后继续。
        onProgress?.call(DownloadProgress(
          received: received,
          total: total,
          errorMessage: '网络中断，第 $attempt 次重试（${e.toString().split("\n").first}）',
        ));
        await Future.delayed(capped);
        // 续传：已下载部分保留。
        continue;
      }
    }
  }

  static Future<String> _sha256Of(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// 校验 SHA256 是否匹配（支持完整或前缀匹配）。公开供测试与 UI 复用。
  static bool shaMatches(String actual, String expected) {
    final a = actual.toLowerCase();
    final e = expected.toLowerCase();
    if (a == e) return true;
    if (e.length < a.length && a.startsWith(e)) return true;
    if (e.length > a.length && e.startsWith(a)) return true;
    return false;
  }
}

class DownloadFailedException implements Exception {
  final String message;
  const DownloadFailedException(this.message);
  @override
  String toString() => '下载失败: $message';
}

/// SHA256 校验失败：不可重试，直接终止。
class ShaMismatchException implements Exception {
  final String message;
  const ShaMismatchException(this.message);
  @override
  String toString() => '校验失败: $message';
}

class DownloadCancelledException implements Exception {
  const DownloadCancelledException();
  @override
  String toString() => '下载已取消';
}
