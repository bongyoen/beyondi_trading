import 'dart:convert';
import 'dart:io';

/// 구형 캐시 파일(candle_{symbol}_{날짜}_1d.json)을
/// 신규 _full_ 포맷(candle_{symbol}_full_1d.json)으로 일괄 변환.
void main() {
  final dir = '${Platform.environment['APPDATA'] ?? ''}\\com.example\\beyondi_trading';
  final d = Directory(dir);
  if (!d.existsSync()) {
    print('캐시 디렉토리 없음: $dir');
    return;
  }

  // 구형 파일 스캔
  final oldFiles = d.listSync().whereType<File>()
      .where((f) => f.path.contains('candle_') && !f.path.contains('_full_') && f.path.endsWith('_1d.json'))
      .toList();
  print('>>> 구형 파일 ${oldFiles.length}개 발견\n');

  if (oldFiles.isEmpty) { print('변환할 파일 없음'); return; }

  // 종목별 그룹화
  final groups = <String, List<File>>{};
  for (final f in oldFiles) {
    final name = f.path.split('\\').last;
    final match = RegExp(r'^candle_(\d{6})_').firstMatch(name);
    if (match == null) continue;
    final symbol = match.group(1)!;
    groups.putIfAbsent(symbol, () => []).add(f);
  }

  print('>>> ${groups.length}개 종목 변환 시작\n');

  int converted = 0;
  int skipped = 0;
  int deleted = 0;

  for (final entry in groups.entries) {
    final symbol = entry.key;
    final files = entry.value;
    final fullPath = '$dir\\candle_${symbol}_full_1d.json';
    final fullFile = File(fullPath);

    // 이미 _full_ 파일 있음 → 구형만 삭제
    if (fullFile.existsSync()) {
      for (final f in files) {
        try { f.deleteSync(); deleted++; } catch (_) {}
      }
      skipped++;
      continue;
    }

    // 모든 구형 파일 읽어서 병합 (같은 종목 여러 날짜 파일)
    try {
      final allData = <Map<String, dynamic>>[];
      for (final f in files) {
        final raw = jsonDecode(f.readAsStringSync()) as List<dynamic>;
        allData.addAll(raw.cast<Map<String, dynamic>>());
      }
      // 중복 제거 (같은 timestamp)
      allData.sort((a, b) => (a['t'] as String).compareTo(b['t'] as String));
      final seen = <String>{};
      allData.retainWhere((e) => seen.add(e['t'] as String));
      final json = jsonEncode(allData);
      fullFile.writeAsStringSync(json);
      // 원본 삭제
      for (final f in files) {
        try { f.deleteSync(); deleted++; } catch (_) {}
      }
      converted++;
      print('  [${converted.toString().padLeft(3)}] $symbol: ${files.length}개 파일 → _full_ (${json.length.toString().padLeft(8)} bytes, ${allData.length}캔들)');
    } catch (e) {
      print('  [FAIL] $symbol: $e');
    }
  }

  print('\n>>> 변환 완료');
  print('  변환: $converted 종목');
  print('  스킵(이미 _full_): $skipped 종목');
  print('  삭제된 구형 파일: $deleted 개');
}
