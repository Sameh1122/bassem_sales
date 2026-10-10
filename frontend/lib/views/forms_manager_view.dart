import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FormsManagerViewScreen extends StatefulWidget {
  const FormsManagerViewScreen({super.key});

  @override
  State<FormsManagerViewScreen> createState() => FormsManagerViewScreenState();
}

class FormsManagerViewScreenState extends State<FormsManagerViewScreen> {
  List<Map<String, dynamic>> _forms = [];
  List<dynamic> _agents = [];
  bool _isLoading = true;
  String _searchQuery = '';
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
      final forms = await ApiService.fetchForms();
      final agents = await ApiService.fetchAgents();
      if (mounted) {
        setState(() {
          _forms = forms;
          _agents = agents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading forms: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showFormGeneratorDialog([Map<String, dynamic>? existingForm]) {
    final bool isEditing = existingForm != null;
    final titleController = TextEditingController(text: existingForm?['title'] ?? '');
    final descController = TextEditingController(text: existingForm?['description'] ?? '');

    // List of dynamic fields
    final List<Map<String, dynamic>> fields = existingForm != null
        ? List<Map<String, dynamic>>.from(
            (existingForm['fields'] as List? ?? []).map((f) => {
                  'id': f['id'] ?? 'f_${DateTime.now().millisecondsSinceEpoch}',
                  'label': f['label'] ?? '',
                  'type': f['type'] ?? 'text',
                  'required': f['required'] ?? false,
                  'options': List<String>.from(f['options'] ?? []),
                }))
        : [
            {
              'id': 'f_1',
              'label': 'Chiller Condition & Hygiene',
              'type': 'choose',
              'required': true,
              'options': ['Clean & Functional', 'Requires Cleaning', 'Needs Maintenance', 'Offline'],
            },
            {
              'id': 'f_2',
              'label': 'Operating Temperature (°C)',
              'type': 'text',
              'required': true,
              'options': [],
            },
            {
              'id': 'f_3',
              'label': 'Chiller Frontage Photo',
              'type': 'attachments',
              'required': true,
              'options': [],
            },
          ];

    // Assigned Agents
    final Set<int> selectedAgentIds = existingForm != null
        ? Set<int>.from((existingForm['assigned_agent_ids'] as List? ?? [])
            .map((id) => int.tryParse(id.toString()))
            .whereType<int>())
        : {};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(isEditing ? Icons.edit_note : Icons.dynamic_form, color: const Color(0xFF06B6D4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditing ? 'Edit Audit Form' : 'Dynamic Form Generator',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: math.min(680.0, MediaQuery.of(ctx).size.width - 32),
            height: math.min(640.0, MediaQuery.of(ctx).size.height * 0.8),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Form Title *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Chiller Operational & Hygiene Audit',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Instructions / Description', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Brief instructions for agents completing this visit...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Assigned Agents Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Assigned Sales Agents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            if (selectedAgentIds.length == _agents.length) {
                              selectedAgentIds.clear();
                            } else {
                              selectedAgentIds.addAll(_agents.map((a) => a['id'] as int));
                            }
                          });
                        },
                        child: Text(
                          selectedAgentIds.length == _agents.length ? 'Clear All' : 'Select All Agents',
                          style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: _agents.isEmpty
                        ? const Text('No sales agents registered yet.', style: TextStyle(color: Colors.white38, fontSize: 12))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _agents.map((agent) {
                              final int id = agent['id'];
                              final String name = agent['name'] ?? 'Agent';
                              final isSelected = selectedAgentIds.contains(id);
                              return FilterChip(
                                label: Text(name),
                                selected: isSelected,
                                selectedColor: const Color(0xFF06B6D4).withOpacity(0.3),
                                checkmarkColor: const Color(0xFF06B6D4),
                                backgroundColor: const Color(0xFF1E293B),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      selectedAgentIds.add(id);
                                    } else {
                                      selectedAgentIds.remove(id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Dynamic Field Builder Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Form Fields', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ElevatedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            fields.add({
                              'id': 'f_${DateTime.now().millisecondsSinceEpoch}',
                              'label': '',
                              'type': 'text',
                              'required': false,
                              'options': <String>['Option 1', 'Option 2'],
                            });
                          });
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Field'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Fields List
                  ...fields.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final Map<String, dynamic> f = entry.value;
                    final String type = f['type'] ?? 'text';
                    final bool isReq = f['required'] ?? false;
                    final List<String> opts = List<String>.from(f['options'] ?? []);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF06B6D4),
                                child: Text('${idx + 1}', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  initialValue: f['label'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: const InputDecoration(
                                    hintText: 'Field Label (e.g. Cleanliness, Photo, Temperature)',
                                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                                    isDense: true,
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (val) => f['label'] = val,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    fields.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white10),
                          Row(
                            children: [
                              // Type Selector
                              const Text('Type: ', style: TextStyle(color: Colors.white60, fontSize: 12)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: type,
                                    dropdownColor: const Color(0xFF1E293B),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    items: const [
                                      DropdownMenuItem(value: 'text', child: Text('Text Input')),
                                      DropdownMenuItem(value: 'choose', child: Text('Single Choice (Options)')),
                                      DropdownMenuItem(value: 'attachments', child: Text('Photo / Attachment')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          f['type'] = val;
                                          if (val == 'choose' && (f['options'] == null || (f['options'] as List).isEmpty)) {
                                            f['options'] = ['Option 1', 'Option 2'];
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Required Toggle
                              Row(
                                children: [
                                  const Text('Required', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Checkbox(
                                    value: isReq,
                                    activeColor: const Color(0xFF06B6D4),
                                    checkColor: Colors.black,
                                    onChanged: (val) {
                                      setDialogState(() => f['required'] = val ?? false);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // If choose, render Options editor
                          if (type == 'choose') ...[
                            const SizedBox(height: 10),
                            const Text('Options (agents will choose one):', style: TextStyle(color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...opts.asMap().entries.map((optEntry) {
                                  final oIdx = optEntry.key;
                                  final oVal = optEntry.value;
                                  return Chip(
                                    backgroundColor: const Color(0xFF1E293B),
                                    label: Text(oVal, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                    deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white60),
                                    onDeleted: () {
                                      setDialogState(() {
                                        opts.removeAt(oIdx);
                                        f['options'] = opts;
                                      });
                                    },
                                  );
                                }),
                                ActionChip(
                                  backgroundColor: const Color(0xFF06B6D4).withOpacity(0.2),
                                  label: const Text('+ Add Option', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12)),
                                  onPressed: () {
                                    final optController = TextEditingController();
                                    showDialog(
                                      context: ctx,
                                      builder: (optCtx) => AlertDialog(
                                        backgroundColor: const Color(0xFF1E293B),
                                        title: const Text('Add Choice Option', style: TextStyle(color: Colors.white, fontSize: 16)),
                                        content: TextField(
                                          controller: optController,
                                          autofocus: true,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: const InputDecoration(
                                            hintText: 'e.g. Excellent, Broken, In Stock...',
                                            hintStyle: TextStyle(color: Colors.white38),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(optCtx).pop(),
                                            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              final text = optController.text.trim();
                                              if (text.isNotEmpty) {
                                                setDialogState(() {
                                                  opts.add(text);
                                                  f['options'] = opts;
                                                });
                                              }
                                              Navigator.of(optCtx).pop();
                                            },
                                            child: const Text('Add'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a Form Title'), backgroundColor: Colors.orangeAccent),
                  );
                  return;
                }
                if (fields.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please add at least one field to the form'), backgroundColor: Colors.orangeAccent),
                  );
                  return;
                }

                // Check empty field labels
                for (var f in fields) {
                  if ((f['label'] ?? '').toString().trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please provide labels for all fields'), backgroundColor: Colors.orangeAccent),
                    );
                    return;
                  }
                }

                try {
                  if (isEditing) {
                    await ApiService.updateForm(
                      formId: existingForm['id'] is int ? existingForm['id'] as int : (int.tryParse(existingForm['id'].toString()) ?? 0),
                      title: title,
                      description: descController.text.trim(),
                      fields: fields,
                      assignedAgentIds: selectedAgentIds.toList(),
                    );
                  } else {
                    await ApiService.createForm(
                      title: title,
                      description: descController.text.trim(),
                      fields: fields,
                      assignedAgentIds: selectedAgentIds.toList(),
                    );
                  }
                  Navigator.of(ctx).pop();
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'Form updated successfully' : 'Form created successfully'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving form: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              icon: const Icon(Icons.save, size: 18),
              label: Text(isEditing ? 'Save Changes' : 'Create Form'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteForm(int formId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Form?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to delete this form? Existing responses will remain stored in historical records.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteForm(formId);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form deleted successfully'), backgroundColor: Color(0xFF10B981)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting form: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredForms = _forms.where((f) {
      if (_searchQuery.isEmpty) return true;
      final term = _searchQuery.toLowerCase();
      return (f['title'] ?? '').toString().toLowerCase().contains(term) ||
          (f['description'] ?? '').toString().toLowerCase().contains(term);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF10B981)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.dynamic_form, color: Colors.black, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Audit Forms Generator',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Create dynamic visit questionnaires (text, options, attachments) and assign them to sales agents.',
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showFormGeneratorDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create New Form'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search forms by title or description...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF06B6D4)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
            const SizedBox(height: 20),

            // Forms Grid / List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                  : filteredForms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_open, color: Colors.white38, size: 54),
                              const SizedBox(height: 12),
                              const Text('No forms found', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              const Text('Click "Create New Form" above to build your first audit template.', style: TextStyle(color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredForms.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final form = filteredForms[index];
                            final id = form['id'] is int ? form['id'] as int : (int.tryParse(form['id'].toString()) ?? 0);
                            final title = form['title'] ?? 'Untitled';
                            final description = form['description'] ?? '';
                            final fields = List<Map<String, dynamic>>.from(form['fields'] ?? []);
                            final assignedAgentIds = (form['assigned_agent_ids'] as List? ?? [])
                                .map((x) => int.tryParse(x.toString()))
                                .whereType<int>()
                                .toList();

                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06B6D4).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.description, color: Color(0xFF06B6D4), size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0F172A),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.white12),
                                              ),
                                              child: Text(
                                                '${fields.length} Field${fields.length == 1 ? '' : 's'}',
                                                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (description.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            description,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 12),

                                        // Fields preview badges
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: fields.map((fld) {
                                            final fType = fld['type'] ?? 'text';
                                            final fLabel = fld['label'] ?? '';
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0F172A),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    fType == 'attachments'
                                                        ? Icons.photo_camera
                                                        : fType == 'choose'
                                                            ? Icons.list_alt
                                                            : Icons.short_text,
                                                    size: 13,
                                                    color: Colors.white60,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(fLabel, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 12),

                                        // Assigned Agents Badges
                                        Row(
                                          children: [
                                            const Icon(Icons.people_alt_outlined, color: Colors.white54, size: 14),
                                            const SizedBox(width: 6),
                                            Text(
                                              assignedAgentIds.isEmpty
                                                  ? 'Assigned to: All Sales Agents'
                                                  : 'Assigned to: ${assignedAgentIds.length} Agent${assignedAgentIds.length == 1 ? '' : 's'}',
                                              style: TextStyle(
                                                color: assignedAgentIds.isEmpty ? const Color(0xFF10B981) : Colors.white60,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Actions
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Color(0xFF06B6D4)),
                                        tooltip: 'Edit Form',
                                        onPressed: () => _showFormGeneratorDialog(form),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        tooltip: 'Delete Form',
                                        onPressed: () => _deleteForm(id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
