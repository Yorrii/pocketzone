import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'models.dart';

// Android emulátor = 10.0.2.2, iOS sim/desktop = localhost
String get base =>
    Platform.isAndroid ? 'http://10.0.2.2:5001' : 'http://localhost:5001';

class Api {
  static Future<List<Pitcher>> getPitchers() async {
    final r = await http.get(Uri.parse('$base/pitchers'));
    final arr = jsonDecode(r.body) as List;
    return arr.map((e) => Pitcher.fromJson(e)).toList();
  }

  static Future<Pitcher> createPitcher(String name) async {
    final r = await http.post(Uri.parse('$base/pitchers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}));
    return Pitcher.fromJson(jsonDecode(r.body));
  }

  static Future<void> createPitch({
    required String pitcherId,
    required double x,
    required double y,
    required bool inZone,
    required String type,
    required String result,
    double? speedKph,
  }) async {
    await http.post(Uri.parse('$base/pitches'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pitcherId': pitcherId,
          'x': x,
          'y': y,
          'inZone': inZone,
          'type': type,
          'result': result,
          'speedKph': speedKph
        }));
  }

  static Future<List<Pitch>> getPitches({
    required String pitcherId,
    String? type,
    String? result,
    bool? inZone,
  }) async {
    final qp = {
      'pitcherId': pitcherId,
      if (type != null) 'type': type,
      if (result != null) 'result': result,
      if (inZone != null) 'inZone': inZone.toString(),
      'limit': '200',
    };
    final uri = Uri.parse('$base/pitches').replace(queryParameters: qp);
    final r = await http.get(uri);
    final m = jsonDecode(r.body);
    final arr = (m['items'] as List);
    return arr.map((e) => Pitch.fromJson(e)).toList();
  }
}
