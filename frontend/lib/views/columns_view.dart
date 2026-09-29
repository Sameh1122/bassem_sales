import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ColumnsViewScreen extends StatefulWidget {
  const ColumnsViewScreen({super.key});

  @override
  State<ColumnsViewScreen> createState() => _ColumnsViewScreenState();
}

class _ColumnsViewScreenState extends State<ColumnsViewScreen> {
  List<dynamic> _columns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadColumns();
  }

  Future<void> _loadColumns() async {
    setState(() => _isLoading = true);
    try {
      final cols = await ApiService.getColumns();
      setState(() {
        _columns = cols;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading columns: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _toggleColumn(int id, {bool? isActive, bool? isRequired}) async {
    try {
      await ApiService.toggleColumnStatus(id, isActive: isActive, isRequired: isRequired);
      _loadColumns();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showAddColumnModal() {
    final keyController = TextEditingController();
    final labelController = TextEditingController();
    String dataType = 'string';
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Custom Column Definition', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Excel Header Key (Exact Header Name)',
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Display Label',
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Data Type:', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: dataType,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.cyan),
                      items: ['string', 'number', 'date', 'coords'].map((t) {
                        return DropdownMenuItem(value: t, child: Text(t));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => dataType = val);
                      },
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Required Field for Validation', style: TextStyle(color: Colors.white)),
                  value: isRequired,
                  activeColor: Colors.cyan,
                  onChanged: (val) => setModalState(() => isRequired = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (keyController.text.trim().isEmpty || labelController.text.trim().isEmpty) return;
                await ApiService.addColumn(
                  keyName: keyController.text.trim(),
                  displayLabel: labelController.text.trim(),
                  dataType: dataType,
                  isRequired: isRequired,
                );
                if (mounted) Navigator.pop(context);
                _loadColumns();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              child: const Text('Add Column', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddColumnModal,
        backgroundColor: Colors.cyan,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Add Custom Column', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              '⚙️ Column Management & Schema Studio',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Customize active columns, set required fields for data validation, or omit unnecessary columns for future uploads.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Colors.cyan)))
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 60,
                  columns: const [
                    DataColumn(label: Text('#', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Excel Key Name', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Display Label', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Data Type', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Required Flag', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Active / Omit Column', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                  ],
                  rows: _columns.map((c) {
                    final int id = c['id'];
                    final bool isActive = c['is_active'] == 1;
                    final bool isRequired = c['is_required'] == 1;

                    return DataRow(
                      cells: [
                        DataCell(Text('${c['display_order']}', style: const TextStyle(color: Colors.white38))),
                        DataCell(Text(c['key_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataCell(Text(c['display_label'], style: const TextStyle(color: Colors.white70))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text(c['data_type'], style: const TextStyle(color: Colors.purpleAccent, fontSize: 11)),
                          ),
                        ),
                        DataCell(
                          Switch(
                            value: isRequired,
                            activeColor: Colors.amber,
                            onChanged: (val) => _toggleColumn(id, isRequired: val),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              Switch(
                                value: isActive,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) => _toggleColumn(id, isActive: val),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isActive ? 'Active' : 'Omitted',
                                style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
