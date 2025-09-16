import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import 'dart:developer' as developer;

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});
  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  List<Pitcher> pitchers = [];
  Pitcher? selected;
  String? type;
  String? result;
  bool? inZone;
  List<Pitch> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ps = await Api.getPitchers();
    setState(() {
      pitchers = ps;
      selected = ps.isNotEmpty ? ps.first : null;
    });
    _refresh();
  }

  Future<void> _refresh() async {
    if (selected == null) return;
    developer.log('Refreshing with filters: pitcherId=${selected!.id}, type=$type, result=$result, inZone=$inZone');
    final res = await Api.getPitches(
        pitcherId: selected!.id, type: type, result: result, inZone: inZone);
    setState(() => items = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Nadhozy – přehled'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(children: [
        // Filtry přes celou šířku obrazovky
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<Pitcher>(
                value: selected,
                items: pitchers
                    .map((p) =>
                        DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (v) {
                  setState(() => selected = v);
                  _refresh();
                },
                decoration: const InputDecoration(
                  labelText: 'Nadhazovač',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String?>(
                  value: type,
                  isExpanded: true,
                  items: [
                    null,
                    'fastball',
                    'changeup',
                    'riseball',
                    'dropball',
                    'curveball',
                    'screwball'
                  ]
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t ?? 'typ: všechny')))
                      .toList(),
                  onChanged: (v) {
                    setState(() => type = v);
                    _refresh();
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: DropdownButtonFormField<String?>(
                  value: result,
                  isExpanded: true,
                  items: [
                    null,
                    'strike',
                    'ball',
                    'foul',
                    'hit',
                    'in-play-out'
                  ]
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(r ?? 'výsledek: vše')))
                      .toList(),
                  onChanged: (v) {
                    setState(() => result = v);
                    _refresh();
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<bool?>(
                value: inZone,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                      value: null, child: Text('vše – zóna i mimo')),
                  DropdownMenuItem(value: true, child: Text('jen v zóně')),
                  DropdownMenuItem(
                      value: false, child: Text('jen mimo zónu')),
                ],
                onChanged: (v) {
                  setState(() => inZone = v);
                  _refresh();
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Strike zona pod filtry
        if (selected != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 30.0),
            child: AspectRatio(
              aspectRatio: 3.0 / 4.0,
              child: CustomPaint(
                painter: HeatmapPainter(items),
              ),
            ),
          ),
        const Divider(height: 0),
        Expanded(
            child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final p = items[i];
              return ListTile(
                title: Text(
                    "${p.result.toUpperCase()} • ${p.type}${p.speedKph != null ? ' • ${p.speedKph!.toStringAsFixed(0)} km/h' : ''}"),
                subtitle: Text(
                    "x=${p.x.toStringAsFixed(2)} y=${p.y.toStringAsFixed(2)} • ${p.inZone ? 'v zóně' : 'mimo'}"),
              );
            },
          ),
        )),
      ]),
    );
  }
}

class HeatmapPainter extends CustomPainter {
  final List<Pitch> pitches;

  HeatmapPainter(this.pitches);

  @override
  void paint(Canvas canvas, Size size) {
    // Shadow
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(0, 0, size.width, size.height, 
        topLeft: const Radius.circular(8), 
        topRight: const Radius.circular(8), 
        bottomLeft: const Radius.circular(8), 
        bottomRight: const Radius.circular(8)),
      Paint()..color = Colors.grey.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
    );

    // Outer border
    final borderPaint = Paint()..color = Colors.grey.shade600..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawRRect(
        RRect.fromLTRBAndCorners(0, 0, size.width, size.height, 
          topLeft: const Radius.circular(8), 
          topRight: const Radius.circular(8), 
          bottomLeft: const Radius.circular(8), 
          bottomRight: const Radius.circular(8)),
        borderPaint);

    // Strike zone - stejná logika jako v record_screen
    const pad = 0.25;
    final strikeZone = Rect.fromLTRB(
      size.width * pad, 
      size.height * pad, 
      size.width * (1-pad), 
      size.height * (1-pad)
    );
    
    final strikeZonePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(strikeZone, strikeZonePaint);

    // Grid
    final gridPaint = Paint()..color = Colors.grey.shade600..strokeWidth = 1;
    for (int i=1; i<3; i++) {
      final x = strikeZone.left + strikeZone.width*i/3;
      final y = strikeZone.top + strikeZone.height*i/3;
      canvas.drawLine(Offset(x,strikeZone.top), Offset(x,strikeZone.bottom), gridPaint);
      canvas.drawLine(Offset(strikeZone.left,y), Offset(strikeZone.right,y), gridPaint);
    }

    final pitchTypeColors = {
      'fastball': Colors.red,
      'changeup': Colors.blue,
      'riseball': Colors.green,
      'dropball': Colors.purple,
      'curveball': Colors.orange,
      'screwball': Colors.pink,
    };

    for (final pitch in pitches) {
      final pitchPaint = Paint()
        ..color = (pitchTypeColors[pitch.type] ?? Colors.grey).withOpacity(0.7);
      
      // Opravené mapování koordinátů - stejná logika jako v record_screen
      // pitch.x a pitch.y jsou v rozsahu 0-1
      final dx = pitch.x * size.width;
      final dy = pitch.y * size.height;
      
      canvas.drawCircle(Offset(dx, dy), 6, pitchPaint);
      canvas.drawCircle(Offset(dx, dy), 6, Paint()..color = Colors.white..strokeWidth = 1..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // For simplicity, always repaint
  }
}
