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
  dynamic _latestBatch;
  bool _isLoading = true;
  String _customerSearch = '';
  String _assignmentStatus = 'all'; // all, assigned, unassigned
  String _selectedAgentId = 'All';
  final Set<String> _selectedChillerCodes = {};
  final TextEditingController _searchController = TextEditingController();

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
      );

      if (mounted) {
        setState(() {
          _agents = agentsData;
          _chillers = batchData['chillers'] ?? [];
          _latestBatch = batchData['latestBatch'];
          _isLoading = false;
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
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: _agents.map<DropdownMenuItem<int>>((a) {
                      return DropdownMenuItem<int>(
                        value: a['id'],
                        child: Text('${a['name']} — (${a['area']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => chosenAgentId = val);
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
    final batchFilename = _latestBatch != null ? _latestBatch['filename'] : 'No Batch Uploaded';
    final batchUploadedAt = _latestBatch != null ? _latestBatch['uploaded_at'] : '';

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Target Batch: ', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _latestBatch != null ? 'Last Uploaded: #$batchFilename ($batchUploadedAt)' : 'No uploads available',
                          style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
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
                    const SizedBox(width: 12),
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
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Card
          Container(
            padding: const EdgeInsets.all(16),
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
                SizedBox(
                  width: 300,
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      setState(() => _customerSearch = v);
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
                                setState(() => _customerSearch = '');
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
                          setState(() => _assignmentStatus = val);
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
                          setState(() => _selectedAgentId = val);
                          _loadData();
                        }
                      },
                    ),
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
                    '${_chillers.length} Locations in Batch',
                    style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

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
                                rows: _chillers.map((c) {
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
        ],
      ),
    );
  }
}
