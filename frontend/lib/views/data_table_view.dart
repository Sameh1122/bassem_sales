import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DataTableViewScreen extends StatefulWidget {
  const DataTableViewScreen({super.key});

  @override
  State<DataTableViewScreen> createState() => _DataTableViewScreenState();
}

class _DataTableViewScreenState extends State<DataTableViewScreen> {
  List<dynamic> _chillers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchChillers(search: _searchQuery);
      setState(() {
        _chillers = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data table: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Clear Database Records', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to clear all active dataset records from SQLite?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Clear All Data')),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.clearChillers();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Search + Clear Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🗃️ Active Dataset Table (${_chillers.length} Records)',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('Complete database records stored in SQLite.', style: TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 250,
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search records...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: Colors.cyan, size: 18),
                            onPressed: () {
                              setState(() => _searchQuery = _searchController.text.trim());
                              _loadData();
                            },
                          ),
                        ),
                        onSubmitted: (val) {
                          setState(() => _searchQuery = val.trim());
                          _loadData();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _clearAllData,
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
                      label: const Text('Clear All DB Data', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Colors.cyan)))
            else if (_chillers.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                child: const Center(
                  child: Text('No records currently in database. Navigate to Upload tab to import data.', style: TextStyle(color: Colors.white60)),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columns: const [
                      DataColumn(label: Text('Code', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Branch', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Customer Name', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Customer Type', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Efficiency', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Chiller Status', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Condition', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Latitude', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Longitude', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                    ],
                    rows: _chillers.map((c) {
                      return DataRow(
                        cells: [
                          DataCell(Text(c['chillerCode'] ?? '-', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataCell(Text(c['branch'] ?? '-', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(c['customerName'] ?? '-', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(c['customerType'] ?? '-', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(c['efficiency'] ?? '-', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(c['chillerStatus'] ?? '-', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(c['condition'] ?? '-', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text('${c['latitude'] ?? '-'}', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text('${c['longitude'] ?? '-'}', style: const TextStyle(color: Colors.white70))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
