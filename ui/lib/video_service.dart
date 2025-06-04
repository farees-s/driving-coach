import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class VideoService {
    static Future<String> processVideo(File video) async {
        final uri = Uri.parse('http://127.0.0.1:9000/process'); // uri for request
        final request = http.MultipartRequest('POST', uri);
        final multipartFile = await http.MultipartFile.fromPath( // multipart file
            'video',
            video.path,
            filename: p.basename(video.path),
        );
        request.files.add(multipartFile);
        final response = await request.send(); // reuqest sent

        if (response.statusCode != 200) {
            throw Exception('Backend error ${response.statusCode}');
        }
        final responseString = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(responseString) as Map<String, dynamic>; // decode json reponse
        final laneCsv = jsonResponse['lane_csv'] as String; // exctract lane_csv
        return laneCsv;
    }
}
