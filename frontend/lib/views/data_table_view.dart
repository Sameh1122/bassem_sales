import 'dart:collection';
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

  // Search & Filter state
  String _globalSearchQuery = '';
  final TextEditingController _globalSearchController = TextEditingController();
  final Map<String, String> _columnFilters = {}; // colName -> filterValue
  final Set<String> _hiddenColumns = {}; // columns user chose to hide

  // Selected column for the quick filter toolbar
  String? _selectedToolbarColumn;
  final TextEditingController _toolbarFilterController = TextEditingController();

  // Sorting state
  String? _sortColumn;
  bool _sortAscending = true;

  // Pagination state
  int _currentPage = 0;
  int _rowsPerPage = 50;
  final List<int> _rowsPerPageOptions = [25, 50, 100, 250, 500];

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

  // Extract ALL columns present across all records in rawData and top-level properties
  List<String> _extractColumns(List<dynamic> chillers) {
    if (chillers.isEmpty) {
      return ['Chiller Code', 'Customer Name', 'Branch', 'Customer Type', 'Month Ach. Status', 'Latitude', 'Longitude'];
    }

    final LinkedHashSet<String> allKeys = LinkedHashSet<String>();

    for (final c in chillers) {
      if (c['rawData'] is Map) {
        final Map raw = c['rawData'];
        for (final k in raw.keys) {
          final strKey = k.toString().trim();
          if (strKey.isNotEmpty) {
            allKeys.add(strKey);
          }
        }
      }
    }

    // If rawData had no keys, fallback to standard properties
    if (allKeys.isEmpty) {
      return [
        'Chiller Code',
        'Customer Name',
        'Branch',
        'Customer Type',
        'Month Ach. Status',
        'Chiller Status',
        'Chiller Type',
        'Condition',
        'Latitude',
        'Longitude'
      ];
    }

    return allKeys.toList();
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
      // Case-insensitive check
      final targetLower = col.trim().toLowerCase();
      for (final entry in raw.entries) {
        if (entry.key.toString().trim().toLowerCase() == targetLower) {
          final val = entry.value;
          if (val != null) {
            final s = val.toString().trim();
            if (s.isNotEmpty) return s;
          }
        }
      }
    }

    // Fallbacks for core model properties
    final lowerCol = col.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    if (lowerCol == 'chillercode' || lowerCol == 'code') {
      return (chiller['chillerCode'] ?? chiller['chiller_code'] ?? '-').toString();
    } else if (lowerCol == 'customername' || lowerCol == 'name') {
      return (chiller['customerName'] ?? chiller['customer_name'] ?? '-').toString();
    } else if (lowerCol == 'branch') {
      return (chiller['branch'] ?? '-').toString();
    } else if (lowerCol == 'customertype') {
      return (chiller['customerType'] ?? chiller['customer_type'] ?? '-').toString();
    } else if (lowerCol == 'efficiency' || lowerCol == 'monthachstatus') {
      return (chiller['efficiency'] ?? '-').toString();
    } else if (lowerCol == 'chillerstatus') {
      return (chiller['chillerStatus'] ?? chiller['chiller_status'] ?? '-').toString();
    } else if (lowerCol == 'chillertype') {
      return (chiller['chillerType'] ?? chiller['chiller_type'] ?? '-').toString();
    } else if (lowerCol == 'condition' || lowerCol == 'condiiton') {
      return (chiller['condition'] ?? '-').toString();
    } else if (lowerCol == 'latitude') {
      return (chiller['latitude'] ?? '-').toString();
    } else if (lowerCol == 'longitude') {
      return (chiller['longitude'] ?? '-').toString();
    }
    return '-';
  }

  double? _tryParseDouble(String val) {
    if (val.isEmpty || val == '-') return null;
    final clean = val.replaceAll(',', '').replaceAll(' ', '').replaceAll('EGP', '');
    return double.tryParse(clean);
  }

  List<dynamic> _getFilteredAndSortedChillers(List<String> allColumns) {
    // 1. Filter
    final filtered = _chillers.where((c) {
      // Global search across ALL columns
      if (_globalSearchQuery.isNotEmpty) {
        final q = _globalSearchQuery.toLowerCase();
        bool anyMatch = false;
        for (final col in allColumns) {
          final val = _getCellValue(c, col).toLowerCase();
          if (val.contains(q)) {
            anyMatch = true;
            break;
          }
        }
        if (!anyMatch) return false;
      }

      // Column-specific filters
      for (final entry in _columnFilters.entries) {
        final col = entry.key;
        final fVal = entry.value.trim().toLowerCase();
        if (fVal.isEmpty) continue;

        final cellVal = _getCellValue(c, col).trim().toLowerCase();
        if (!cellVal.contains(fVal)) {
          return false;
        }
      }

      return true;
    }).toList();

    // 2. Sort
    if (_sortColumn != null) {
      filtered.sort((a, b) {
        final valA = _getCellValue(a, _sortColumn!);
        final valB = _getCellValue(b, _sortColumn!);

        final numA = _tryParseDouble(valA);
        final numB = _tryParseDouble(valB);

        int cmp;
        if (numA != null && numB != null) {
          cmp = numA.compareTo(numB);
        } else {
          cmp = valA.compareTo(valB);
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    return filtered;
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        if (_sortAscending) {
          _sortAscending = false;
        } else {
          _sortColumn = null; // reset sort
          _sortAscending = true;
        }
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  void _openColumnFilterDialog(String column) {
    final currentFilter = _columnFilters[column] ?? '';
    final controller = TextEditingController(text: currentFilter);

    // Get top unique values for this column from the dataset
    final Map<String, int> valueCounts = {};
    for (final c in _chillers) {
      final val = _getCellValue(c, column);
      if (val != '-' && val.isNotEmpty) {
        valueCounts[val] = (valueCounts[val] ?? 0) + 1;
      }
    }
    final sortedValues = valueCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topValues = sortedValues.take(25).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: [
              const Icon(Icons.filter_alt, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Filter: $column', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Type to filter $column...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                      prefixIcon: const Icon(Icons.search, color: Colors.cyan, size: 18),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                              onPressed: () {
                                controller.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 14),
                  if (topValues.isNotEmpty) ...[
                    Text('Quick Select (${topValues.length} distinct values):', style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: topValues.map((entry) {
                        final isSelected = controller.text.trim().toLowerCase() == entry.key.toLowerCase();
                        return InkWell(
                          onTap: () {
                            controller.text = isSelected ? '' : entry.key;
                            setDialogState(() {});
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.cyan.withValues(alpha: 0.3) : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isSelected ? Colors.cyan : Colors.white24),
                            ),
                            child: Text(
                              '${entry.key} (${entry.value})',
                              style: TextStyle(
                                color: isSelected ? Colors.cyan : Colors.white70,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (_columnFilters.containsKey(column))
              TextButton(
                onPressed: () {
                  setState(() {
                    _columnFilters.remove(column);
                    _currentPage = 0;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Clear Filter', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                final val = controller.text.trim();
                setState(() {
                  if (val.isEmpty) {
                    _columnFilters.remove(column);
                  } else {
                    _columnFilters[column] = val;
                  }
                  _currentPage = 0;
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.black),
              child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openManageColumnsDialog(List<String> allColumns) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Show / Hide Columns', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      setDialogState(() => _hiddenColumns.clear());
                      setState(() {});
                    },
                    child: const Text('Show All', style: TextStyle(color: Colors.cyan, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            height: 400,
            child: ListView.builder(
              itemCount: allColumns.length,
              itemBuilder: (ctx, i) {
                final col = allColumns[i];
                final isVisible = !_hiddenColumns.contains(col);
                return CheckboxListTile(
                  dense: true,
                  activeColor: Colors.cyan,
                  title: Text(col, style: TextStyle(color: isVisible ? Colors.white : Colors.white38, fontSize: 13)),
                  value: isVisible,
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        _hiddenColumns.remove(col);
                      } else {
                        // Prevent hiding all columns
                        if (allColumns.length - _hiddenColumns.length > 1) {
                          _hiddenColumns.add(col);
                        }
                      }
                    });
                    setState(() {});
                  },
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.black),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _exportToCsv(List<String> columns) {
    if (_chillers.isEmpty) return;
    final filtered = _getFilteredAndSortedChillers(columns);
    final buffer = StringBuffer();

    // CSV Header row
    buffer.writeln(columns.map((c) => '"${c.replaceAll('"', '""')}"').join(','));

    // CSV Data rows
    for (final item in filtered) {
      final row = columns.map((col) {
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
        content: Text('📥 Exported ${filtered.length} records to $filename'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Widget _buildCellContent(String col, String val) {
    final lowerCol = col.toLowerCase();
    if (lowerCol == 'month ach. status' || lowerCol == 'efficiency') {
      Color badgeColor;
      if (val.toLowerCase() == 'performing') {
        badgeColor = const Color(0xFF10B981);
      } else if (val.toLowerCase() == 'non-performing') {
        badgeColor = Colors.orangeAccent;
      } else if (val.toLowerCase() == 'zero') {
        badgeColor = Colors.redAccent.withValues(alpha: 0.85);
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

    if (lowerCol.contains('chiller code') || lowerCol == 'code') {
      return Text(
        val,
        style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 13),
      );
    }

    if (lowerCol.contains('customer name')) {
      return Text(
        val,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
      );
    }

    if (lowerCol.contains('invoice') || lowerCol == 'ytd' || lowerCol.contains('average')) {
      return Text(
        val,
        style: TextStyle(
          color: (val != '-' && val != '0' && val.isNotEmpty) ? const Color(0xFF10B981) : Colors.white38,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      );
    }

    return Text(
      val,
      style: TextStyle(color: val == '-' ? Colors.white30 : Colors.white70, fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allColumns = _extractColumns(_chillers);
    final visibleColumns = allColumns.where((c) => !_hiddenColumns.contains(c)).toList();
    final filtered = _getFilteredAndSortedChillers(allColumns);
    final totalRows = filtered.length;
    final totalPages = (totalRows / _rowsPerPage).ceil().clamp(1, 99999);
    final safePage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = safePage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalRows);
    final pageRows = totalRows > 0 ? filtered.sublist(startIndex, endIndex) : [];
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Title & Header Action Bar
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
                          'Complete Excel Dataset (${_chillers.length} Records)',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All ${allColumns.length} spreadsheet columns loaded. Fully searchable and filterable across all data fields.',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Column Visibility Button
                    OutlinedButton.icon(
                      onPressed: () => _openManageColumnsDialog(allColumns),
                      icon: const Icon(Icons.view_column, size: 16, color: Colors.cyan),
                      label: Text('Columns (${visibleColumns.length}/${allColumns.length})', style: const TextStyle(color: Colors.cyan)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.cyan)),
                    ),

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
                      onPressed: _chillers.isEmpty ? null : () => _exportToCsv(visibleColumns),
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
                      label: const Text('Clear DB', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Comprehensive Search & Filter Toolbar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Universal Search Box (searches ALL 36+ columns)
                      SizedBox(
                        width: isMobile ? double.infinity : 320,
                        height: 40,
                        child: TextField(
                          controller: _globalSearchController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search ALL columns simultaneously...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                            prefixIcon: const Icon(Icons.search, color: Colors.cyan, size: 18),
                            suffixIcon: _globalSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                                    onPressed: () {
                                      _globalSearchController.clear();
                                      setState(() {
                                        _globalSearchQuery = '';
                                        _currentPage = 0;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _globalSearchQuery = val.trim();
                              _currentPage = 0;
                            });
                          },
                        ),
                      ),

                      // Column-Specific Filter Selector
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Column: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedToolbarColumn ?? (allColumns.isNotEmpty ? allColumns.first : null),
                              dropdownColor: const Color(0xFF1E293B),
                              underline: const SizedBox(),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: allColumns.map((col) {
                                return DropdownMenuItem(value: col, child: Text(col));
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedToolbarColumn = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 180,
                            height: 40,
                            child: TextField(
                              controller: _toolbarFilterController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Filter value...',
                                hintStyle: TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: Color(0xFF0F172A),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.white24)),
                              ),
                              onSubmitted: (val) {
                                final col = _selectedToolbarColumn ?? (allColumns.isNotEmpty ? allColumns.first : null);
                                if (col != null && val.trim().isNotEmpty) {
                                  setState(() {
                                    _columnFilters[col] = val.trim();
                                    _toolbarFilterController.clear();
                                    _currentPage = 0;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: () {
                              final col = _selectedToolbarColumn ?? (allColumns.isNotEmpty ? allColumns.first : null);
                              final val = _toolbarFilterController.text.trim();
                              if (col != null && val.isNotEmpty) {
                                setState(() {
                                  _columnFilters[col] = val;
                                  _toolbarFilterController.clear();
                                  _currentPage = 0;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            child: const Text('Add Filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),

                      // Match counter badge
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

                  // Active Filters Bar (Chips)
                  if (_globalSearchQuery.isNotEmpty || _columnFilters.isNotEmpty || _sortColumn != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Active Filters:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        if (_globalSearchQuery.isNotEmpty)
                          Chip(
                            backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                            side: const BorderSide(color: Colors.cyan),
                            label: Text('Global: "$_globalSearchQuery"', style: const TextStyle(color: Colors.cyan, fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 14, color: Colors.cyan),
                            onDeleted: () {
                              _globalSearchController.clear();
                              setState(() {
                                _globalSearchQuery = '';
                                _currentPage = 0;
                              });
                            },
                          ),
                        ..._columnFilters.entries.map((entry) {
                          return Chip(
                            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            label: Text('${entry.key}: "${entry.value}"', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF10B981)),
                            onDeleted: () {
                              setState(() {
                                _columnFilters.remove(entry.key);
                                _currentPage = 0;
                              });
                            },
                          );
                        }),
                        if (_sortColumn != null)
                          Chip(
                            backgroundColor: Colors.purpleAccent.withValues(alpha: 0.2),
                            side: const BorderSide(color: Colors.purpleAccent),
                            label: Text('Sorted: $_sortColumn (${_sortAscending ? "▲ Asc" : "▼ Desc"})', style: const TextStyle(color: Colors.purpleAccent, fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 14, color: Colors.purpleAccent),
                            onDeleted: () {
                              setState(() => _sortColumn = null);
                            },
                          ),
                        TextButton(
                          onPressed: () {
                            _globalSearchController.clear();
                            _toolbarFilterController.clear();
                            setState(() {
                              _globalSearchQuery = '';
                              _columnFilters.clear();
                              _sortColumn = null;
                              _currentPage = 0;
                            });
                          },
                          child: const Text('Clear All Filters', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Table Content
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
                        columnSpacing: 18,
                        columns: visibleColumns.map((col) {
                          final isSorted = _sortColumn == col;
                          final hasFilter = _columnFilters.containsKey(col);

                          return DataColumn(
                            label: InkWell(
                              onTap: () => _onSort(col),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    col,
                                    style: TextStyle(
                                      color: hasFilter ? Colors.yellowAccent : const Color(0xFF06B6D4),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (isSorted) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                      size: 14,
                                      color: Colors.cyan,
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(
                                      hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                                      size: 15,
                                      color: hasFilter ? Colors.yellowAccent : Colors.white38,
                                    ),
                                    tooltip: 'Filter $col',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                    onPressed: () => _openColumnFilterDialog(col),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        rows: pageRows.map((c) {
                          return DataRow(
                            cells: visibleColumns.map((col) {
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

