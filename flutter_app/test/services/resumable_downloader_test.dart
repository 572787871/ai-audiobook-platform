import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:ai_audiobook/services/resumable_downloader.dart';

/// 支持 Range 的最小静态文件服务器，用于验证断点续传。
class _RangeServer {
  final int port;
  final List<int> bytes;
  HttpServer? _svr;
  int requests = 0;
  _RangeServer(this.port, this.bytes);

  Future<void> start() async {
    _svr = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _svr!.listen((req) async {
      requests++;
      final range = req.headers.value('range');
      if (range != null && range.startsWith('bytes=')) {
        final spec = range.substring(6);
        final start = int.parse(spec.split('-').first);
        final end = (spec.split('-').length > 1 && spec.split('-')[1].isNotEmpty)
            ? int.parse(spec.split('-').last)
            : bytes.length - 1;
        final slice = bytes.sublist(start, end + 1);
        req.response
          ..statusCode = 206
          ..headers.contentType = ContentType.binary
          ..headers.set('Content-Range', 'bytes $start-$end/${bytes.length}')
          ..headers.set('Content-Length', '${slice.length}')
          ..add(slice);
      } else {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.binary
          ..headers.set('Content-Length', '${bytes.length}')
          ..add(bytes);
      }
      await req.response.close();
    });
  }

  Future<void> stop() async => _svr?.close();
}

void main() {
  late _RangeServer server;
  const port = 19011;
  final data = List<int>.generate(50000, (i) => i % 256);

  setUpAll(() async {
    server = _RangeServer(port, data);
    await server.start();
    await Future.delayed(const Duration(milliseconds: 200));
  });
  tearDownAll(() => server.stop());

  test('shaMatches 支持完整与前缀匹配', () {
    final full = sha256.convert(data).toString();
    expect(ResumableDownloader.shaMatches(full, full), isTrue);
    expect(ResumableDownloader.shaMatches(full, full.substring(0, 8)), isTrue);
    expect(ResumableDownloader.shaMatches(full, 'deadbeef'), isFalse);
  });

  test('完整下载并校验 SHA256', () async {
    final dir = await Directory.systemTemp.createTemp('dl_test_');
    final out = '${dir.path}/full.bin';
    final expected = sha256.convert(data).toString();
    final f = await ResumableDownloader.download(
      urls: ['http://127.0.0.1:$port/file'],
      outputPath: out,
      expectedSha256: expected,
    );
    final got = sha256.convert(await f.readAsBytes()).toString();
    expect(got, expected);
    expect(server.requests, greaterThanOrEqualTo(1));
    await dir.delete(recursive: true);
  });

  test('断点续传：保留 .part 并继续', () async {
    final dir = await Directory.systemTemp.createTemp('dl_resume_');
    final part = '${dir.path}/resume.bin.part';
    final half = data.length ~/ 2;
    final pFile = File(part);
    await pFile.writeAsBytes(data.sublist(0, half));

    final f = await ResumableDownloader.download(
      urls: ['http://127.0.0.1:$port/file'],
      outputPath: '${dir.path}/resume.bin',
    );
    final got = sha256.convert(await f.readAsBytes()).toString();
    final expected = sha256.convert(data).toString();
    expect(got, expected);
    expect(server.requests, greaterThan(1));
    await dir.delete(recursive: true);
  });

  test('取消抛出 DownloadCancelledException', () async {
    final dir = await Directory.systemTemp.createTemp('dl_cancel_');
    final handle = DownloadHandle();
    final fut = ResumableDownloader.download(
      urls: ['http://127.0.0.1:1/never'],
      outputPath: '${dir.path}/cancel.bin',
      handle: handle,
    );
    handle.cancel();
    expect(fut, throwsA(isA<DownloadCancelledException>()));
    await dir.delete(recursive: true);
  });
}
