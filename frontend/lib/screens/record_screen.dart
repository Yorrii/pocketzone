import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../models.dart';

const pitchTypes = ['fastball','changeup','riseball','dropball','curveball','screwball'];
const results = ['strike','ball','foul','hit','in-play-out'];

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});
  @override State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  List<Pitcher> pitchers = [];
  Pitcher? selected;
  Offset? _tapPosition;
  bool _isRecordingPitch = false;

  // Pitch data
  late String _pitchType;
  late String _pitchResult;
  double? _pitchSpeed;
  late double _x01;
  late double _y01;
  late bool _inZone;

  final _speedController = TextEditingController();


  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final ps = await Api.getPitchers();
    setState(() { pitchers = ps; if (ps.isNotEmpty) selected = ps.first; });
  }

  Future<void> _createPitcherDialog() async {
    final ctrl = TextEditingController();
    String? errorText;
    final ok = await showDialog<bool>(context: context, builder: (c) {
      return StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Nový nadhazovač'),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'Jméno',
              errorText: errorText,
            ),
            onChanged: (value) {
              if (RegExp(r'[0-9]').hasMatch(value)) {
                setStateDialog(() => errorText = 'Jméno nesmí obsahovat čísla');
              } else {
                setStateDialog(() => errorText = null);
              }
            },
          ),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(c, false), child: const Text('Zrušit')),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty || RegExp(r'[0-9]').hasMatch(ctrl.text.trim())) {
                  setStateDialog(() => errorText = 'Jméno nesmí obsahovat čísla');
                } else {
                  Navigator.pop(c, true);
                }
              },
              child: const Text('Vytvořit')),
          ],
        ),
      );
    });
    if (ok == true && ctrl.text.trim().isNotEmpty && !RegExp(r'[0-9]').hasMatch(ctrl.text.trim())) {
      final p = await Api.createPitcher(ctrl.text.trim());
      setState(() { pitchers.insert(0, p); selected = p; });
    }
  }

  void _tapAt(Offset local, Size box) {
    if (selected == null || !_isRecordingPitch) return;

    _x01 = (local.dx / box.width).clamp(0, 1);
    _y01 = (local.dy / box.height).clamp(0, 1);

    const pad = 0.25; // okraje mimo strike zónu
    _inZone = (_x01 >= pad && _x01 <= 1-pad && _y01 >= pad && _y01 <= 1-pad);

    setState(() {
      _tapPosition = local;
      _isRecordingPitch = true;
      _pitchType = pitchTypes.first;
      _pitchResult = _inZone ? 'strike' : 'ball';
      _pitchSpeed = null;
      _speedController.clear();
    });
  }

  Future<void> _savePitch() async {
    if (selected == null) return;
    await Api.createPitch(
      pitcherId: selected!.id,
      x: _x01,
      y: _y01,
      inZone: _inZone,
      type: _pitchType,
      result: _pitchResult,
      speedKph: _pitchSpeed,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nadhoz uložen')));
    }
    _cancelPitch();
  }

  void _cancelPitch() {
    setState(() {
      _isRecordingPitch = false;
      _tapPosition = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Zápis nadhozů'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(onPressed: _createPitcherDialog, icon: const Icon(Icons.person_add), tooltip: 'Přidat nadhazovače'),
          IconButton(onPressed: ()=> context.push('/list'), icon: const Icon(Icons.list))
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Filtry přes celou šířku obrazovky
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nadhazovač', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<Pitcher>(
                  value: selected,
                  items: pitchers.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                  onChanged: (v)=> setState(()=> selected = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  hint: const Text('Vyberte nadhazovače'),
                ),
              ],
            ),
          ),
          // Strike zona se zobrazí pouze pokud je vybrán nadhazovač
          if (selected != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 30.0),
              child: AspectRatio(
                aspectRatio: 3.0 / 4.0,
                child: LayoutBuilder(builder: (ctx, cons) {
                  return GestureDetector(
                    onTapDown: (d) {
                      if (!_isRecordingPitch) {
                        setState(() {
                          _isRecordingPitch = true;
                        });
                      }
                       _tapAt(d.localPosition, Size(cons.maxWidth, cons.maxHeight));
                    },
                    child: CustomPaint(
                      painter: _StrikeZonePainter(tapPosition: _tapPosition),
                      child: Container(),
                    ),
                  );
                }),
              ),
            ),
          if (_isRecordingPitch)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text('Zapsat nadhoz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Výsledek'),
                Wrap(spacing: 8, children: results.map((r) =>
                  ChoiceChip(label: Text(r), selected: _pitchResult==r, onSelected: (_)=> setState(()=> _pitchResult=r))
                ).toList()),
                const SizedBox(height: 12),
                const Text('Typ'),
                Wrap(spacing: 8, children: pitchTypes.map((t) =>
                  ChoiceChip(label: Text(t), selected: _pitchType==t, onSelected: (_)=> setState(()=> _pitchType=t))
                ).toList()),
                const SizedBox(height: 12),
                TextField(
                  controller: _speedController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*[.,]?[0-9]*')),
                  ],
                  decoration: const InputDecoration(labelText: 'Rychlost (km/h)'),
                  onChanged: (v) => _pitchSpeed = double.tryParse(v.replaceAll(',', '.')),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _cancelPitch, child: const Text('Zrušit'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: _savePitch, child: const Text('Uložit'))),
                ]),
              ],),
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

class _StrikeZonePainter extends CustomPainter {
  final Offset? tapPosition;
  _StrikeZonePainter({this.tapPosition});

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.grey.shade300..strokeWidth = 1..style = PaintingStyle.stroke;

    // Shadow
    c.drawRRect(
      RRect.fromLTRBAndCorners(0, 0, s.width, s.height, topLeft: const Radius.circular(8), topRight: const Radius.circular(8), bottomLeft: const Radius.circular(8), bottomRight: const Radius.circular(8)),
      Paint()..color = Colors.grey.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
    );

    // Outer border
    c.drawRRect(
        RRect.fromLTRBAndCorners(0, 0, s.width, s.height, topLeft: const Radius.circular(8), topRight: const Radius.circular(8), bottomLeft: const Radius.circular(8), bottomRight: const Radius.circular(8)),
        p..color = Colors.grey.shade600..strokeWidth = 2);


    const pad = 0.25;
    // Strike zone
    final strikeZone = Rect.fromLTRB(s.width * pad, s.height * pad, s.width * (1-pad), s.height* (1-pad));
    c.drawRect(strikeZone, p..color = Colors.black..strokeWidth = 3);

    // Grid
    final gridPaint = Paint()..color = Colors.grey.shade600..strokeWidth = 1;
    for (int i=1;i<3;i++) {
      final x = strikeZone.left + strikeZone.width*i/3;
      final y = strikeZone.top + strikeZone.height*i/3;
      c.drawLine(Offset(x,strikeZone.top), Offset(x,strikeZone.bottom), gridPaint);
      c.drawLine(Offset(strikeZone.left,y), Offset(strikeZone.right,y), gridPaint);
    }
    
    if (tapPosition != null) {
      c.drawCircle(tapPosition!, 8, Paint()..color = Colors.red.shade700..style = PaintingStyle.fill);
      c.drawCircle(tapPosition!, 8, Paint()..color = Colors.white..strokeWidth=1..style = PaintingStyle.stroke);
    }
  }
  @override bool shouldRepaint(covariant _StrikeZonePainter oldDelegate) => oldDelegate.tapPosition != tapPosition;
}
