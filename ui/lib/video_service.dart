import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class VideoService {
  static Future<String> processVideo(File video) async {
    final uri = Uri.parse('http://127.0.0.1:9000/process');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath(
          'video', video.path, filename: p.basename(video.path)));
    final resp = await req.send();
    if (resp.statusCode != 200) {
      throw Exception('Backend error ${resp.statusCode}');
    }
    final json =
        jsonDecode(await resp.stream.bytesToString()) as Map<String, dynamic>;
    return json['lane_csv'] as String;
  }
}
