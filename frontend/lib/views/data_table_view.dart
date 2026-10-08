import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage.dart';

class DataTableViewScreen extends StatefulWidget {
  const DataTableViewScreen({super.key});

  @override
  State<DataTableViewScreen> createState() => DataTableViewScreenState();
}

class DataTableViewScreenState extends State<DataTableViewScreen> {
  List<dynamic> _chillers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedEfficiency = 'All';
  String _selectedCustomerType = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Pagination state
  int _currentPage = 0;
  int _rowsPerPage = 50;
  final List<int> _rowsPerPageOptions = [25, 50, 100, 250];

  @override
  void initState() {
    super.initState();
    _loadData(forceApi: true);
  }

  void reload({bool forceApi = false}) {
    _loadData(forceApi: forceApi);
  }

  Future<void> _loadData({bool forceApi = false}) async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchChillers(
        search: '',
        forceApi: forceApi,
      );
      if (mounted) {
        setState(() {
          _chillers = data;
          _isLoading = false;
          _currentPage = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.clearChillers();
      _loadData(forceApi: true);
    }
  }

  List<String> _extractColumns(List<dynamic> chillers) {
    if (chillers.isEmpty) {
      return ['Chiller Code', 'Customer Name', 'Branch', 'Customer Type', 'Month Ach. Status', 'Latitude', 'Longitude'];
    }

    final Set<String> foundKeys = {};
    for (final c in chillers) {
      if (c['rawData'] is Map) {
        final Map raw = c['rawData'];
        for (final k in raw.keys) {
          final strKey = k.toString().trim();
          if (strKey.isNotEmpty) foundKeys.add(strKey);
        }
      }
    }

    // Preferred column display sequence
    final List<String> preferredOrder = [
      'Chiller Code',
      'Customer Name',
      'Customer Code',
      'Branch',
      'Customer Type',
      'Month Ach. Status',
      'Chiller Status',
      'Chiller Type',
      'Chiller Configuration',
      'Condiiton',
      'Condition',
      'Customer Address',
      'Mobile Number',
      'Truck Code',
      'SR Name',
      'SSV Name',
      'Visit Day',
      'Latitude',
      'Longitude',
      'Serial Number',
      'Action Date',
      'Received Date',
      'Jan 2026 Invoice',
      'Feb 2026 Invoice',
      'Mar 2026 Invoice',
      'Apr 2026 Invoice',
      'May 2026 Invoice',
      'June 2026 Invoice',
      'July 2026 Invoice',
      'Aug 2026 Invoice',
      'Sep 2026 Invoice',
      'Oct 2026 Invoice',
      'Nov 2026 Invoice',
      'Dec 2026 Invoice',
      'YTD',
      'Average / Month',
      'Notes',
    ];

    final List<String> orderedColumns = [];
    for (final col in preferredOrder) {
      if (foundKeys.contains(col)) {
        orderedColumns.add(col);
        foundKeys.remove(col);
      }
    }

    // Append any extra/custom columns from the newly uploaded sheet
    final remainingKeys = foundKeys.toList()..sort();
    orderedColumns.addAll(remainingKeys);

    if (orderedColumns.isEmpty) {
      return ['Chiller Code', 'Customer Name', 'Branch', 'Customer Type', 'Month Ach. Status', 'Latitude', 'Longitude'];
    }

    return orderedColumns;
  }

  String _getCellValue(dynamic chiller, String col) {
    if (chiller == null) return '-';
    if (chiller['rawData'] is Map) {
      final raw = chiller['rawData'] as Map;
      if (raw.containsKey(col)) {
        final val = raw[col];
        if (val != null) {
          final s = val.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
    }

    // Fallbacks for core model properties
    final lowerCol = col.toLowerCase();
    if (lowerCol == 'chiller code' || lowerCol == 'code') {
      return (chiller['chillerCode'] ?? '-').toString();
    } else if (lowerCol == 'customer name') {
      return (chiller['customerName'] ?? '-').toString();
    } else if (lowerCol == 'branch') {
      return (chiller['branch'] ?? '-').toString();
    } else if (lowerCol == 'customer type') {
      return (chiller['customerType'] ?? '-').toString();
    } else if (lowerCol == 'efficiency' || lowerCol == 'month ach. status') {
      return (chiller['efficiency'] ?? '-').toString();
    } else if (lowerCol == 'chiller status') {
      return (chiller['chillerStatus'] ?? '-').toString();
    } else if (lowerCol == 'chiller type') {
      return (chiller['chillerType'] ?? '-').toString();
    } else if (lowerCol == 'condition' || lowerCol == 'condiiton') {
      return (chiller['condition'] ?? '-').toString();
    } else if (lowerCol == 'latitude') {
      return (chiller['latitude'] ?? '-').toString();
    } else if (lowerCol == 'longitude') {
      return (chiller['longitude'] ?? '-').toString();
    }
    return '-';
  }

  List<dynamic> get _filteredChillers {
    return _chillers.where((c) {
      if (_selectedEfficiency != 'All') {
        final eff = (c['efficiency'] ?? '').toString().toLowerCase();
        if (eff != _selectedEfficiency.toLowerCase()) return false;
      }
      if (_selectedCustomerType != 'All') {
        final type = (c['customerType'] ?? '').toString().toLowerCase();
        if (type != _selectedCustomerType.toLowerCase()) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final code = (c['chillerCode'] ?? '').toString().toLowerCase();
        final name = (c['customerName'] ?? '').toString().toLowerCase();
        final branch = (c['branch'] ?? '').toString().toLowerCase();
        final addr = _getCellValue(c, 'Customer Address').toLowerCase();
        final phone = _getCellValue(c, 'Mobile Number').toLowerCase();
        final sr = _getCellValue(c, 'SR Name').toLowerCase();
        if (!code.contains(q) && !name.contains(q) && !branch.contains(q) && !addr.contains(q) && !phone.contains(q) && !sr.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _exportToCsv() {
    if (_chillers.isEmpty) return;
    final cols = _extractColumns(_chillers);
    final buffer = StringBuffer();

    // CSV Header row
    buffer.writeln(cols.map((c) => '"${c.replaceAll('"', '""')}"').join(','));

    // CSV Data rows (export active filtered set)
    for (final item in _filteredChillers) {
      final row = cols.map((col) {
        final val = _getCellValue(item, col);
        final cleanVal = val == '-' ? '' : val;
        return '"${cleanVal.replaceAll('"', '""')}"';
      }).join(',');
      buffer.writeln(row);
    }

    final filename = 'Chillers_Database_Export_${DateTime.now().millisecondsSinceEpoch}.csv';
    downloadBlob(filename, buffer.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📥 Exported ${_filteredChillers.length} records to $filename'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Widget _buildCellContent(String col, String val) {
    if (col == 'Month Ach. Status' || col == 'Efficiency') {
      Color badgeColor;
      Color textColor = Colors.white;
      if (val.toLowerCase() == 'performing') {
        badgeColor = const Color(0xFF10B981);
      } else if (val.toLowerCase() == 'non-performing') {
        badgeColor = Colors.orangeAccent;
      } else if (val.toLowerCase() == 'zero') {
        badgeColor = Colors.redAccent.withValues(alpha: 0.8);
      } else {
        badgeColor = Colors.grey.withValues(alpha: 0.5);
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeColor.withValues(alpha: 0.6)),
        ),
        child: Text(
          val,
          style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (col == 'Chiller Code') {
      return Text(
        val,
        style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 13),
      );
    }

    if (col == 'Customer Name') {
      return Text(
        val,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
      );
    }

    return Text(
      val,
      style: TextStyle(color: val == '-' ? Colors.white30 : Colors.white70, fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredChillers;
    final totalRows = filtered.length;
    final totalPages = (totalRows / _rowsPerPage).ceil().clamp(1, 99999);
    final safePage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = safePage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalRows);
    final pageRows = totalRows > 0 ? filtered.sublist(startIndex, endIndex) : [];
    final columns = _extractColumns(_chillers);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Title & Action Bar
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_chart, color: Colors.cyan, size: 26),
                        const SizedBox(width: 8),
                        Text(
                          'Active Dataset Table (${_chillers.length} Records)',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete records from latest uploaded Excel sheet with all dynamic columns (${columns.length} columns discovered).',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Refresh Button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _loadData(forceApi: true),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh DB'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.cyan,
                        side: const BorderSide(color: Colors.cyan),
                      ),
                    ),

                    // Export CSV Button
                    ElevatedButton.icon(
                      onPressed: _chillers.isEmpty ? null : _exportToCsv,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                      ),
                    ),

                    // Clear All DB Data
                    OutlinedButton.icon(
                      onPressed: _clearAllData,
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 16),
                      label: const Text('Clear All DB', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search & Filter Toolbar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search Box
                  SizedBox(
                    width: isMobile ? double.infinity : 280,
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search code, name, branch, address...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                        prefixIcon: const Icon(Icons.search, color: Colors.cyan, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _currentPage = 0;
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),

                  // Efficiency Filter Dropdown
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Efficiency: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedEfficiency,
                          dropdownColor: const Color(0xFF1E293B),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: ['All', 'Performing', 'Non-Performing', 'Zero'].map((eff) {
                            return DropdownMenuItem(value: eff, child: Text(eff));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedEfficiency = val;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  // Customer Type Filter Dropdown
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Type: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedCustomerType,
                          dropdownColor: const Color(0xFF1E293B),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: ['All', 'Retail', 'LS', 'SM', 'LG'].map((t) {
                            return DropdownMenuItem(value: t, child: Text(t));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCustomerType = val;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  // Records counter badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Showing $totalRows of ${_chillers.length}',
                      style: const TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main Table Section
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(60),
                  child: CircularProgressIndicator(color: Colors.cyan),
                ),
              )
            else if (_chillers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(50),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.cloud_upload_outlined, color: Colors.cyan, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No records currently in database.',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Navigate to the "Upload & Validate" tab to import your latest Excel sheet.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              )
            else ...[
              // Scrollable Responsive Data Table
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: screenWidth - 40),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFF0B132B)),
                        dataRowMinHeight: 46,
                        dataRowMaxHeight: 52,
                        horizontalMargin: 16,
                        columnSpacing: 22,
                        columns: columns.map((col) {
                          return DataColumn(
                            label: Text(
                              col,
                              style: const TextStyle(
                                color: Color(0xFF06B6D4),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
                        rows: pageRows.map((c) {
                          return DataRow(
                            cells: columns.map((col) {
                              final cellVal = _getCellValue(c, col);
                              return DataCell(_buildCellContent(col, cellVal));
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Pagination Controls Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    // Rows per page dropdown
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Rows per page: ', style: TextStyle(color: Colors.white60, fontSize: 13)),
                        DropdownButton<int>(
                          value: _rowsPerPage,
                          dropdownColor: const Color(0xFF1E293B),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Colors.cyan, fontSize: 13, fontWeight: FontWeight.bold),
                          items: _rowsPerPageOptions.map((opt) {
                            return DropdownMenuItem(value: opt, child: Text('$opt'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _rowsPerPage = val;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ],
                    ),

                    // Page status
                    Text(
                      totalRows > 0
                          ? 'Showing ${startIndex + 1} - $endIndex of $totalRows'
                          : 'No matching records',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),

                    // Navigation buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'First Page',
                          icon: const Icon(Icons.first_page, size: 20),
                          color: safePage > 0 ? Colors.cyan : Colors.white24,
                          onPressed: safePage > 0 ? () => setState(() => _currentPage = 0) : null,
                        ),
                        IconButton(
                          tooltip: 'Previous Page',
                          icon: const Icon(Icons.chevron_left, size: 20),
                          color: safePage > 0 ? Colors.cyan : Colors.white24,
                          onPressed: safePage > 0 ? () => setState(() => _currentPage = safePage - 1) : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Page ${safePage + 1} of $totalPages',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next Page',
                          icon: const Icon(Icons.chevron_right, size: 20),
                          color: safePage < totalPages - 1 ? Colors.cyan : Colors.white24,
                          onPressed: safePage < totalPages - 1 ? () => setState(() => _currentPage = safePage + 1) : null,
                        ),
                        IconButton(
                          tooltip: 'Last Page',
                          icon: const Icon(Icons.last_page, size: 20),
                          color: safePage < totalPages - 1 ? Colors.cyan : Colors.white24,
                          onPressed: safePage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
