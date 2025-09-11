import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';
import '../models.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});
  @override State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  List<Pitcher> pitchers = [];
  Pitcher? selected;
  String? type;
  String? result;
  bool? inZone;
  List<Pitch> items = [];

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final ps = await Api.getPitchers();
    setState(() { pitchers = ps; selected = ps.isNotEmpty ? ps.first : null; });
    _refresh();
  }

  Future<void> _refresh() async {
    if (selected == null) return;
    final res = await Api.getPitches(
      pitcherId: selected!.id, type: type, result: result, inZone: inZone);
    setState(() => items = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nadhozy – přehled')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            DropdownButtonFormField<Pitcher>(
              value: selected,
              items: pitchers.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              onChanged: (v){ setState(()=> selected=v); _refresh(); },
              decoration: const InputDecoration(labelText: 'Nadhazovač'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String?>(
                value: type, isExpanded: true,
                items: [null,'fastball','changeup','riseball','dropball','curveball','screwball']
                  .map((t)=> DropdownMenuItem(value: t, child: Text(t??'typ: všechny'))).toList(),
                onChanged: (v){ setState(()=> type=v); _refresh(); },
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String?>(
                value: result, isExpanded: true,
                items: [null,'strike','ball','foul','hit','in-play-out']
                  .map((r)=> DropdownMenuItem(value: r, child: Text(r??'výsledek: vše'))).toList(),
                onChanged: (v){ setState(()=> result=v); _refresh(); },
              )),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<bool?>(
              value: inZone, isExpanded: true,
              items: const [
                DropdownMenuItem(value: null, child: Text('vše – zóna i mimo')),
                DropdownMenuItem(value: true, child: Text('jen v zóně')),
                DropdownMenuItem(value: false, child: Text('jen mimo zónu')),
              ],
              onChanged: (v){ setState(()=> inZone=v); _refresh(); },
            ),
          ]),
        ),
        const Divider(height: 0),
        Expanded(child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final p = items[i];
              return ListTile(
                title: Text("${p.result.toUpperCase()} • ${p.type}"
                    "${p.speedKph!=null ? ' • ${p.speedKph!.toStringAsFixed(0)} km/h' : ''}"),
                subtitle: Text("x=${p.x.toStringAsFixed(2)} y=${p.y.toStringAsFixed(2)} • ${p.inZone ? 'v zóně' : 'mimo'}"),
              );
            },
          ),
        )),
      ]),
    );
  }
}
