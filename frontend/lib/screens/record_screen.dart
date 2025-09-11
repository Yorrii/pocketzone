import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final ps = await Api.getPitchers();
    setState(() { pitchers = ps; if (ps.isNotEmpty) selected = ps.first; });
  }

  Future<void> _createPitcherDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) {
      return AlertDialog(
        title: const Text('Nový nadhazovač'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Jméno')),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c, false), child: const Text('Zrušit')),
          FilledButton(onPressed: ()=> Navigator.pop(c, true), child: const Text('Vytvořit')),
        ],
      );
    });
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final p = await Api.createPitcher(ctrl.text.trim());
      setState(() { pitchers.insert(0, p); selected = p; });
    }
  }

  Future<void> _tapAt(Offset local, Size box) async {
    if (selected == null) return;

    final x01 = (local.dx / box.width).clamp(0, 1);
    final y01 = (local.dy / box.height).clamp(0, 1);

    const pad = 0.1; // okraje mimo strike zónu
    final inZone = (x01 >= pad && x01 <= 1-pad && y01 >= pad && y01 <= 1-pad);

    String type = pitchTypes.first;
    String result = inZone ? 'strike' : 'ball';
    double? speed;

    final saved = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (ctx) {
        final spCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(builder: (ctx, setSt) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Zapsat nadhoz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Výsledek'),
                Wrap(spacing: 8, children: results.map((r) =>
                  ChoiceChip(label: Text(r), selected: result==r, onSelected: (_)=> setSt(()=> result=r))
                ).toList()),
                const SizedBox(height: 12),
                const Text('Typ'),
                Wrap(spacing: 8, children: pitchTypes.map((t) =>
                  ChoiceChip(label: Text(t), selected: type==t, onSelected: (_)=> setSt(()=> type=t))
                ).toList()),
                const SizedBox(height: 12),
                TextField(controller: spCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Rychlost (km/h)'),
                  onChanged: (v)=> speed = double.tryParse(v)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Zrušit'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Uložit'))),
                ]),
              ]),
            );
          }),
        );
      });

    if (saved == true) {
      await Api.createPitch(
        pitcherId: selected!.id,
        x: x01.toDouble(), y: y01.toDouble(), inZone: inZone,
        type: type, result: result, speedKph: speed,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nadhoz uložen')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zápis nadhozů'),
        actions: [IconButton(onPressed: ()=> context.push('/list'), icon: const Icon(Icons.list))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPitcherDialog, icon: const Icon(Icons.person_add), label: const Text('Přidat nadhazovače')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: DropdownButtonFormField<Pitcher>(
            value: selected,
            items: pitchers.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
            onChanged: (v)=> setState(()=> selected = v),
            decoration: const InputDecoration(labelText: 'Nadhazovač'),
          ),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (ctx, cons) {
                return GestureDetector(
                  onTapDown: (d)=> _tapAt(d.localPosition, Size(cons.maxWidth, cons.maxHeight)),
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFF0b0f18),
                      borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white)),
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(4)),
                      child: CustomPaint(painter: _GridPainter()),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.grey..strokeWidth = 1..style = PaintingStyle.stroke;
    for (int i=1;i<3;i++) {
      final x = s.width*i/3, y = s.height*i/3;
      c.drawLine(Offset(x,0), Offset(x,s.height), p);
      c.drawLine(Offset(0,y), Offset(s.width,y), p);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
