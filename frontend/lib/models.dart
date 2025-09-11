class Pitcher {
  final String id;
  final String name;
  Pitcher({required this.id, required this.name});

  factory Pitcher.fromJson(Map<String, dynamic> j)
    => Pitcher(id: j["_id"], name: j["name"]);
}

class Pitch {
  final String id;
  final String pitcherId;
  final double x, y;
  final bool inZone;
  final String type;
  final String result;
  final double? speedKph;
  final DateTime ts;

  Pitch({
    required this.id,
    required this.pitcherId,
    required this.x,
    required this.y,
    required this.inZone,
    required this.type,
    required this.result,
    this.speedKph,
    required this.ts,
  });

  factory Pitch.fromJson(Map<String, dynamic> j) => Pitch(
    id: j["_id"],
    pitcherId: j["pitcherId"],
    x: (j["x"] as num).toDouble(),
    y: (j["y"] as num).toDouble(),
    inZone: j["inZone"] as bool,
    type: j["type"],
    result: j["result"],
    speedKph: (j["speedKph"] as num?)?.toDouble(),
    ts: DateTime.parse(j["ts"] ?? DateTime.now().toIso8601String()),
  );
}
