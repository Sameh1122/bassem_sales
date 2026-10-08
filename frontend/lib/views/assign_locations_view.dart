import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AssignLocationsViewScreen extends StatefulWidget {
  const AssignLocationsViewScreen({super.key});

  @override
  State<AssignLocationsViewScreen> createState() => AssignLocationsViewScreenState();
}

class AssignLocationsViewScreenState extends State<AssignLocationsViewScreen> {
  List<dynamic> _chillers = [];
  List<dynamic> _agents = [];
  List<dynamic> _availableBatches = [];
  dynamic _latestBatch;
  bool _isLoading = true;
  String _customerSearch = '';
  String _assignmentStatus = 'all'; // all, assigned, unassigned
  String _selectedAgentId = 'All';
  String _selectedBatchId = 'all'; // 'all', 'latest', or specific batch id
  int _totalLocationsInDb = 0;
  final Set<String> _selectedChillerCodes = {};
  final TextEditingController _searchController = TextEditingController();

  // Pagination
  int _currentPage = 0;
  int _pageSize = 50; // 25, 50, 100, -1 (all)

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void reload() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final agentsData = await ApiService.fetchAgents();
      final batchData = await ApiService.fetchLatestBatchChillers(
        search: _customerSearch,
        agentId: _selectedAgentId,
        assignmentStatus: _assignmentStatus,
        batchId: _selectedBatchId,
      );

      if (mounted) {
        setState(() {
          _agents = agentsData;
          _chillers = batchData['chillers'] ?? [];
          _latestBatch = batchData['latestBatch'];
          _availableBatches = batchData['batches'] ?? [];
          _totalLocationsInDb = batchData['totalDbLocations'] ?? _chillers.length;
          _isLoading = false;
          _currentPage = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading assignment data: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _assignSelected(List<String> chillerCodes, List<String> customerNames) async {
    if (_agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add sales agents first in the Sales Agents tab'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    int? chosenAgentId = _agents.first['id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.assignment_ind, color: Color(0xFF06B6D4), size: 24),
              SizedBox(width: 10),
              Text('Assign to Sales Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign ${chillerCodes.length} location(s) / customer(s) to:',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: chosenAgentId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    items: _agents.map<DropdownMenuItem<int>>((a) {
                      return DropdownMenuItem<int>(
                        value: a['id'],
                        child: Text('${a['name']} (${a['area'] ?? 'No Area'})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => chosenAgentId = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm Assignment', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && chosenAgentId != null) {
      try {
        final res = await ApiService.assignLocations(
          agentId: chosenAgentId!,
          chillerCodes: chillerCodes,
          customerNames: customerNames,
        );
        setState(() {
          _selectedChillerCodes.clear();
        });
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Assigned successfully'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Assignment error: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _unassignCustomer(String customerName, String chillerCode) async {
    try {
      await ApiService.unassignLocation(customerName: customerName, chillerCode: chillerCode);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unassigned "$customerName"'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unassign error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pagination slicing
    final int totalCount = _chillers.length;
    final int effectivePageSize = _pageSize == -1 ? (totalCount > 0 ? totalCount : 1) : _pageSize;
    final int totalPages = (totalCount / effectivePageSize).ceil().clamp(1, 999999);
    final int safeCurrentPage = _currentPage.clamp(0, totalPages - 1);
    final int startIndex = safeCurrentPage * effectivePageSize;
    final int endIndex = (startIndex + effectivePageSize).clamp(0, totalCount);
    final List<dynamic> pagedChillers = totalCount > 0 ? _chillers.sublist(startIndex, endIndex) : [];

    // Header batch items
    final List<DropdownMenuItem<String>> batchDropdownItems = [
      DropdownMenuItem(
        value: 'all',
        child: Text('All Locations (${_totalLocationsInDb > 0 ? _totalLocationsInDb : totalCount} Total)'),
      ),
    ];
    for (final b in _availableBatches) {
      final bId = b['id'].toString();
      final fname = (b['filename'] ?? 'Batch #$bId').toString();
      final rows = b['total_rows'] ?? b['valid_rows'] ?? '';
      batchDropdownItems.add(DropdownMenuItem(
        value: bId,
        child: Text('Batch #$bId: $fname ${rows != '' ? '($rows rows)' : ''}'),
      ));
    }

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_ind, color: Color(0xFF06B6D4), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Assign Locations to Sales Agents',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Target Batch Selector
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Colors.white54, size: 16),
                      const Text('Target Batch: ', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.35)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: batchDropdownItems.any((item) => item.value == _selectedBatchId) ? _selectedBatchId : 'all',
                            dropdownColor: const Color(0xFF1E293B),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF06B6D4)),
                            style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
                            items: batchDropdownItems,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedBatchId = val;
                                  _currentPage = 0;
                                  _selectedChillerCodes.clear();
                                });
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  if (_selectedChillerCodes.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        final selectedRows = _chillers.where((c) => _selectedChillerCodes.contains(c['chillerCode'])).toList();
                        final codes = selectedRows.map<String>((c) => (c['chillerCode'] ?? '').toString()).toList();
                        final names = selectedRows.map<String>((c) => (c['customerName'] ?? '').toString()).toList();
                        _assignSelected(codes, names);
                      },
                      icon: const Icon(Icons.group_add, color: Colors.black, size: 18),
                      label: Text(
                        'Assign Selected (${_selectedChillerCodes.length})',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() => _selectedChillerCodes.clear()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      child: const Text('Deselect All'),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search by Customer Name
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 180, maxWidth: 320),
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      setState(() {
                        _customerSearch = v;
                        _currentPage = 0;
                      });
                      _loadData();
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by Customer Name or Code...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                      suffixIcon: _customerSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _customerSearch = '';
                                  _currentPage = 0;
                                });
                                _loadData();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                    ),
                  ),
                ),
              ),

                // Assignment Status Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _assignmentStatus,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'assigned', child: Text('Assigned Only')),
                        DropdownMenuItem(value: 'unassigned', child: Text('Unassigned Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _assignmentStatus = val;
                            _currentPage = 0;
                          });
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),

                // Agent Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAgentId,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Agents')),
                        ..._agents.map<DropdownMenuItem<String>>((a) {
                          return DropdownMenuItem<String>(
                            value: a['id'].toString(),
                            child: Text('Agent: ${a['name']}'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAgentId = val;
                            _currentPage = 0;
                          });
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),

                // Select All across entire filter button
                if (totalCount > 0)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_selectedChillerCodes.length == totalCount) {
                          _selectedChillerCodes.clear();
                        } else {
                          for (final c in _chillers) {
                            final code = (c['chillerCode'] ?? '').toString();
                            if (code.isNotEmpty) _selectedChillerCodes.add(code);
                          }
                        }
                      });
                    },
                    icon: Icon(
                      _selectedChillerCodes.length == totalCount ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 16,
                      color: const Color(0xFF06B6D4),
                    ),
                    label: Text(
                      _selectedChillerCodes.length == totalCount ? 'Deselect All ($totalCount)' : 'Select All $totalCount',
                      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF06B6D4)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),

                // Location Count Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$totalCount Locations Found',
                    style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Chillers / Locations Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                : _chillers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.location_off, size: 54, color: Colors.white24),
                            SizedBox(height: 12),
                            Text('No locations found for this filter', style: TextStyle(color: Colors.white54, fontSize: 16)),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                                showCheckboxColumn: true,
                                columns: const [
                                  DataColumn(label: Text('Customer Name', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Chiller Code', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Branch / Area', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Customer Type', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Assigned Agent', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Action', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                                ],
                                rows: pagedChillers.map((c) {
                                  final String code = (c['chillerCode'] ?? '').toString();
                                  final String custName = (c['customerName'] ?? 'Unnamed').toString();
                                  final String branch = (c['branch'] ?? 'N/A').toString();
                                  final String custType = (c['customerType'] ?? 'N/A').toString();
                                  final String? agentName = c['assignedAgentName'];
                                  final String? agentArea = c['assignedAgentArea'];
                                  final bool isAssigned = agentName != null && agentName.isNotEmpty;
                                  final bool isSelected = _selectedChillerCodes.contains(code);

                                  return DataRow(
                                    selected: isSelected,
                                    onSelectChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedChillerCodes.add(code);
                                        } else {
                                          _selectedChillerCodes.remove(code);
                                        }
                                      });
                                    },
                                    cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            const Icon(Icons.business, size: 16, color: Colors.white54),
                                            const SizedBox(width: 8),
                                            Text(custName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(code, style: const TextStyle(color: Colors.cyan))),
                                      DataCell(Text(branch, style: const TextStyle(color: Colors.white70))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                          child: Text(custType, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                        ),
                                      ),
                                      DataCell(
                                        isAssigned
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.person, size: 14, color: Color(0xFF10B981)),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      agentName,
                                                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                    if (agentArea != null && agentArea.isNotEmpty) ...[
                                                      const SizedBox(width: 4),
                                                      Text('($agentArea)', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                                    ],
                                                  ],
                                                ),
                                              )
                                            : Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('Unassigned', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                                              ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            ElevatedButton(
                                              onPressed: () => _assignSelected([code], [custName]),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF06B6D4),
                                                foregroundColor: Colors.black,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: Text(isAssigned ? 'Reassign' : 'Assign Agent', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                            if (isAssigned) ...[
                                              const SizedBox(width: 6),
                                              IconButton(
                                                tooltip: 'Unassign this customer',
                                                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                                onPressed: () => _unassignCustomer(custName, code),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),

          // Pagination Bar
          if (totalCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Rows per page: ', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _pageSize,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            items: const [
                              DropdownMenuItem(value: 25, child: Text('25')),
                              DropdownMenuItem(value: 50, child: Text('50')),
                              DropdownMenuItem(value: 100, child: Text('100')),
                              DropdownMenuItem(value: -1, child: Text('All')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _pageSize = val;
                                  _currentPage = 0;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Showing ${totalCount == 0 ? 0 : startIndex + 1} - $endIndex of $totalCount locations',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'First Page',
                        icon: const Icon(Icons.first_page, size: 20, color: Colors.white70),
                        onPressed: safeCurrentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                      ),
                      IconButton(
                        tooltip: 'Previous Page',
                        icon: const Icon(Icons.chevron_left, size: 20, color: Colors.white70),
                        onPressed: safeCurrentPage > 0 ? () => setState(() => _currentPage = safeCurrentPage - 1) : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Page ${safeCurrentPage + 1} of $totalPages',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next Page',
                        icon: const Icon(Icons.chevron_right, size: 20, color: Colors.white70),
                        onPressed: safeCurrentPage < totalPages - 1 ? () => setState(() => _currentPage = safeCurrentPage + 1) : null,
                      ),
                      IconButton(
                        tooltip: 'Last Page',
                        icon: const Icon(Icons.last_page, size: 20, color: Colors.white70),
                        onPressed: safeCurrentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
