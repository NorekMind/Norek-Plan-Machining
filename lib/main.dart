// lib/main.dart - Norek CNC Planner (copy-paste)
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const NorekApp());

class NorekApp extends StatelessWidget {
  const NorekApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Norek CNC Planner',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E88E5),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E88E5)),
      ),
      home: const CNCPlannerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Machine {
  String name;
  double power;
  double price;
  double tooling;
  double operatorSalary;
  double foodPerDay;
  Machine({
    required this.name,
    required this.power,
    required this.price,
    required this.tooling,
    required this.operatorSalary,
    required this.foodPerDay,
  });
  Map<String, dynamic> toJson() => {
        'name': name,
        'power': power,
        'price': price,
        'tooling': tooling,
        'operatorSalary': operatorSalary,
        'foodPerDay': foodPerDay,
      };
  static Machine fromJson(Map<String, dynamic> j) {
    return Machine(
      name: j['name'],
      power: (j['power'] as num).toDouble(),
      price: (j['price'] as num).toDouble(),
      tooling: (j['tooling'] as num).toDouble(),
      operatorSalary: (j['operatorSalary'] as num).toDouble(),
      foodPerDay: (j['foodPerDay'] as num).toDouble(),
    );
  }
}

class CNCPlannerPage extends StatefulWidget {
  const CNCPlannerPage({super.key});
  @override
  State<CNCPlannerPage> createState() => _CNCPlannerPageState();
}

class _CNCPlannerPageState extends State<CNCPlannerPage> {
  double tariff = 1450;
  int daysPerMonth = 26;
  int hoursPerDay = 8;
  int workingHoursPerYear = 2000;
  int depreciationYears = 10;
  double otWeekdayMult = 1.5;
  double otWeekendMult = 2.0;

  List<Machine> presets = [];
  late Machine current;

  @override
  void initState() {
    super.initState();
    presets = [
      Machine(name: 'CK6132 (Lathe)', power: 6.0, price: 250000000, tooling: 15000, operatorSalary: 5000000, foodPerDay: 50000),
      Machine(name: 'VMC-850II (Milling)', power: 15.0, price: 900000000, tooling: 25000, operatorSalary: 6500000, foodPerDay: 50000),
    ];
    current = presets.first;
    _loadPresets();
  }

  Future<String> _localPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<File> _presetsFile() async {
    final path = await _localPath();
    return File('$path/norek_presets.json');
  }

  Future<void> _savePresets() async {
    try {
      final file = await _presetsFile();
      final jsonList = presets.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presets saved locally')));
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadPresets() async {
    try {
      final file = await _presetsFile();
      if (await file.exists()) {
        final s = await file.readAsString();
        final List j = jsonDecode(s);
        setState(() {
          presets = j.map((e) => Machine.fromJson(e)).toList();
          current = presets.first;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  double operatorPerHour(double monthlySalary, double foodPerDay) {
    double daily = monthlySalary / daysPerMonth;
    double hourly = daily / hoursPerDay;
    double foodHr = foodPerDay / hoursPerDay;
    return hourly + foodHr;
  }

  double elecPerHour(double powerKw) => powerKw * tariff;
  double deprPerHour(double price) => price / (depreciationYears * workingHoursPerYear);

  Map<String, double> calculate(Machine m) {
    double opHr = operatorPerHour(m.operatorSalary, m.foodPerDay);
    double elecHr = elecPerHour(m.power);
    double deprHr = deprPerHour(m.price);
    double toolHr = m.tooling;
    double base = elecHr + opHr + deprHr + toolHr;
    double perDay = base * hoursPerDay;
    double perMonth = base * (daysPerMonth * hoursPerDay);
    double otWeekOpOnly = elecHr + (opHr * otWeekdayMult) + deprHr + toolHr;
    double otWeekendOpOnly = elecHr + (opHr * otWeekendMult) + deprHr + toolHr;
    return {
      'elecHr': elecHr,
      'opHr': opHr,
      'deprHr': deprHr,
      'toolHr': toolHr,
      'baseHr': base,
      'perDay': perDay,
      'perMonth': perMonth,
      'otWeekOpOnly': otWeekOpOnly,
      'otWeekendOpOnly': otWeekendOpOnly
    };
  }

  String f(double v) {
    final rounded = v.round();
    final s = rounded.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return "Rp " + s.replaceAllMapped(reg, (m) => '${m[1]}.');
  }

  void _showAddPreset() {
    final nameC = TextEditingController();
    final powerC = TextEditingController();
    final priceC = TextEditingController();
    final toolC = TextEditingController();
    final salaryC = TextEditingController();
    final foodC = TextEditingController();

    showDialog(context: context, builder: (_) {
      return AlertDialog(
        title: const Text('Tambah Preset Mesin'),
        content: SingleChildScrollView(
          child: Column(children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama Mesin')),
            TextField(controller: powerC, decoration: const InputDecoration(labelText: 'Daya (kW)'), keyboardType: TextInputType.number),
            TextField(controller: priceC, decoration: const InputDecoration(labelText: 'Harga Mesin (Rp)'), keyboardType: TextInputType.number),
            TextField(controller: toolC, decoration: const InputDecoration(labelText: 'Tooling (Rp/hr)'), keyboardType: TextInputType.number),
            TextField(controller: salaryC, decoration: const InputDecoration(labelText: 'Gaji Operator (Rp/bln)'), keyboardType: TextInputType.number),
            TextField(controller: foodC, decoration: const InputDecoration(labelText: 'Uang Makan (Rp/hari)'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () {
            final m = Machine(
              name: nameC.text.isEmpty ? 'New Machine' : nameC.text,
              power: double.tryParse(powerC.text) ?? 1.0,
              price: double.tryParse(priceC.text) ?? 1000000,
              tooling: double.tryParse(toolC.text) ?? 0,
              operatorSalary: double.tryParse(salaryC.text) ?? 0,
              foodPerDay: double.tryParse(foodC.text) ?? 0,
            );
            setState(() {
              presets.add(m);
              current = m;
            });
            Navigator.pop(context);
          }, child: const Text('Tambah'))
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = calculate(current);
    return Scaffold(
      appBar: AppBar(title: Row(children: const [Icon(Icons.precision_manufacturing), SizedBox(width:8), Text('Norek CNC Planner')])),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length + 1,
              itemBuilder: (_, i) {
                if (i == presets.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal:8.0),
                    child: ElevatedButton.icon(onPressed: _showAddPreset, icon: const Icon(Icons.add), label: const Text('Tambah')),
                  );
                }
                final m = presets[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal:6.0),
                  child: ChoiceChip(label: Text(m.name), selected: current==m, onSelected: (_) => setState(()=> current = m)),
                );
              },
            ),
          ),
          const SizedBox(height:12),
          Expanded(
            child: ListView(children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(children: [
                    Row(children: [Expanded(child: Text('Tarif listrik (Rp/kWh)')), SizedBox(width:120, child: TextFormField(initialValue: tariff.toStringAsFixed(0), keyboardType: TextInputType.number, onChanged: (s)=> setState(()=> tariff = double.tryParse(s) ?? tariff)))]),
                    const SizedBox(height:8),
                    Row(children: [Expanded(child: Text('Hari kerja / bulan')), SizedBox(width:120, child: TextFormField(initialValue: daysPerMonth.toString(), keyboardType: TextInputType.number, onChanged: (s)=> setState(()=> daysPerMonth = int.tryParse(s) ?? daysPerMonth)))]),
                    const SizedBox(height:8),
                    Row(children: [Expanded(child: Text('Jam kerja / hari')), SizedBox(width:120, child: TextFormField(initialValue: hoursPerDay.toString(), keyboardType: TextInputType.number, onChanged: (s)=> setState(()=> hoursPerDay = int.tryParse(s) ?? hoursPerDay)))]),
                    const SizedBox(height:8),
                    Row(children: [Expanded(child: Text('Umur depresiasi (tahun)')), SizedBox(width:120, child: TextFormField(initialValue: depreciationYears.toString(), keyboardType: TextInputType.number, onChanged: (s)=> setState(()=> depreciationYears = int.tryParse(s) ?? depreciationYears)))]),
                    const SizedBox(height:12),
                    ElevatedButton.icon(onPressed: _savePresets, icon: const Icon(Icons.save), label: const Text('Simpan Preset (lokal)')),
                  ]),
                ),
              ),
              const SizedBox(height:12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(children: [
                    Text(current.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height:8),
                    Row(children: [Expanded(child: Text('Power (kW)')), SizedBox(width:120, child: TextFormField(initialValue: current.power.toString(), keyboardType: TextInputType.numberWithOptions(decimal:true), onChanged: (s)=> setState(()=> current.power = double.tryParse(s) ?? current.power)))]),
                    const SizedBox(height:8),
                    Row(children: [Expanded(child: Text('Harga Mesin (Rp)')), SizedBox(width:160, child: TextFormField(initialValue: current.price.toStringAsFixed(0), keyboardType: TextInputType.number, onChanged: (s)=> setState(()=> current.price = double.tryParse(s) ?? current.price)))]),
                    const SizedBox(height:8),
                    Row(children: [Expanded(child: Text('Tooling (Rp/hr)')), SizedBox(width:120, child: TextFormField(initialValue: current.tooling.toStringAsFixed(0), keyboardType: TextInputType.number, onChanged: (s)=> setState(()=> current.tooling = double.tryParse(s) ?? current.tooling)))]),
                    const SizedBox(height:8),
                    Row(children: [Expanded(child: Text('Gaji Operator (Rp/bln)')), SizedBox(width:160, child: TextFormField(initialValue: current.operatorSalary.toStringAsFixed(0), keyboardType: TextInputType.number, onChanged: (s)=> setState(()=> current.operatorSalary = double.tryParse(s) ?? current.operatorSalary)))]),
                    const SizedBox(height:8),
                    Row(children: [Expanded(child: Text('Uang Makan (Rp/hari)')), SizedBox(width:120, child: TextFormField(initialValue: current.foodPerDay.toStringAsFixed(0), keyboardType: TextInputType.number, onChanged: (s)=> setState(()=> current.foodPerDay = double.tryParse(s) ?? current.foodPerDay)))]),
                  ]),
                ),
              ),
              const SizedBox(height:12),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Hasil Perhitungan', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height:8),
                    Text('Listrik: ${f(r['elecHr']!)} / jam'),
                    Text('Operator: ${f(r['opHr']!)} / jam'),
                    Text('Depresiasi: ${f(r['deprHr']!)} / jam'),
                    Text('Tooling: ${f(r['toolHr']!)} / jam'),
                    const Divider(),
                    Text('Total (Base): ${f(r['baseHr']!)} / jam', style: const TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height:8),
                    Text('Per hari (${8} jam): ${f(r['perDay']!)}'),
                    Text('Per bulan (${26} hari): ${f(r['perMonth']!)}'),
                    SizedBox(height:8),
                    Text('OT Weekday (operator-only): ${f(r['otWeekOpOnly']!)} / jam'),
                    Text('OT Weekend (operator-only): ${f(r['otWeekendOpOnly']!)} / jam'),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
