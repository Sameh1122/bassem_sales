import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class FormFillerDialog extends StatefulWidget {
  final Map<String, dynamic> chiller;
  final VoidCallback onSubmitted;

  const FormFillerDialog({
    super.key,
    required this.chiller,
    required this.onSubmitted,
  });

  @override
  State<FormFillerDialog> createState() => _FormFillerDialogState();
}

class _FormFillerDialogState extends State<FormFillerDialog> {
  bool _isLoadingForms = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _forms = [];
  Map<String, dynamic>? _selectedForm;

  // Form answer states keyed by field ID
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};
  final List<String> _attachmentUrls = [];
  bool _isUploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableForms();
  }

  @override
  void dispose() {
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAvailableForms() async {
    setState(() => _isLoadingForms = true);
    try {
      final forms = await ApiService.fetchForms();
      if (mounted) {
        setState(() {
          _forms = forms;
          _isLoadingForms = false;
          if (_forms.isNotEmpty) {
            _selectForm(_forms.first);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingForms = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load forms: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _selectForm(Map<String, dynamic> form) {
    setState(() {
      _selectedForm = form;
      _answers.clear();
      _textControllers.clear();
      _attachmentUrls.clear();

      final fields = List<Map<String, dynamic>>.from(form['fields'] ?? []);
      for (var f in fields) {
        final id = f['id']?.toString() ?? '';
        final type = f['type']?.toString() ?? 'text';
        if (type == 'text') {
          _textControllers[id] = TextEditingController();
        } else if (type == 'choose') {
          final options = List<String>.from(f['options'] ?? []);
          _answers[id] = options.isNotEmpty ? options.first : '';
        }
      }
    });
  }

  Future<void> _pickAndUploadAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'webp', 'pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('Could not read file data from device');
      }

      setState(() => _isUploadingAttachment = true);

      final mimeType = file.extension?.toLowerCase() == 'pdf' ? 'application/pdf' : 'image/jpeg';
      final base64Str = 'data:$mimeType;base64,${base64Encode(file.bytes!)}';

      final url = await ApiService.uploadAttachment(
        base64Data: base64Str,
        filename: file.name,
      );

      if (mounted) {
        setState(() {
          _attachmentUrls.add(url);
          _isUploadingAttachment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment uploaded successfully'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attachment upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_selectedForm == null) return;

    final fields = List<Map<String, dynamic>>.from(_selectedForm!['fields'] ?? []);
    final Map<String, dynamic> finalAnswers = {};

    // Validate required fields
    for (var f in fields) {
      final id = f['id']?.toString() ?? '';
      final label = f['label']?.toString() ?? 'Field';
      final isRequired = f['required'] == true;
      final type = f['type']?.toString() ?? 'text';

      if (type == 'text') {
        final val = _textControllers[id]?.text.trim() ?? '';
        if (isRequired && val.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please fill required field: $label'), backgroundColor: Colors.orangeAccent),
          );
          return;
        }
        finalAnswers[id] = val;
      } else if (type == 'choose') {
        final val = _answers[id]?.toString().trim() ?? '';
        if (isRequired && val.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select an option for: $label'), backgroundColor: Colors.orangeAccent),
          );
          return;
        }
        finalAnswers[id] = val;
      } else if (type == 'attachments') {
        if (isRequired && _attachmentUrls.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please attach at least one photo for: $label'), backgroundColor: Colors.orangeAccent),
          );
          return;
        }
        finalAnswers[id] = _attachmentUrls;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final chillerCode = (widget.chiller['chillerCode'] ?? '').toString();
      final customerName = (widget.chiller['customerName'] ?? '').toString();
      final formId = _selectedForm!['id'] is int ? _selectedForm!['id'] as int : (int.tryParse(_selectedForm!['id'].toString()) ?? 0);

      await ApiService.submitFormResponse(
        formId: formId,
        chillerCode: chillerCode,
        customerName: customerName,
        answers: finalAnswers,
        attachments: _attachmentUrls,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop();
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Visit form submitted successfully! Status updated on map.'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chillerCode = widget.chiller['chillerCode'] ?? 'N/A';
    final customerName = widget.chiller['customerName'] ?? 'Unknown Customer';
    final customerAddress = widget.chiller['customerAddress'] ?? widget.chiller['branch'] ?? '';
    final visitStatus = widget.chiller['visitStatus'] ?? 'not_visited';
    final adminFeedback = widget.chiller['adminFeedback'];
    final isReopened = visitStatus == 'reopened';

    return AlertDialog(
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
            child: const Icon(Icons.assignment_turned_in, color: Color(0xFF06B6D4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReopened ? 'Resubmit Visit Audit' : 'Complete Location Visit',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '$customerName ($chillerCode)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: math.min(540.0, MediaQuery.of(context).size.width - 32),
        height: math.min(580.0, MediaQuery.of(context).size.height * 0.75),
        child: _isLoadingForms
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
            : _forms.isEmpty
                ? const Center(
                    child: Text(
                      'No audit forms have been assigned yet.\nPlease contact your administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Re-opened Alert Banner
                        if (isReopened && adminFeedback != null && adminFeedback.toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF97316)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Re-opened by Admin for Review',
                                        style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        adminFeedback.toString(),
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Location Details Info Box
                        Container(
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
                                  const Icon(Icons.storefront, color: Colors.cyan, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      customerName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              if (customerAddress.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.place_outlined, color: Colors.white54, size: 15),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        customerAddress,
                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Form Selector (if more than 1 form available)
                        if (_forms.length > 1) ...[
                          const Text('Select Audit Form', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Map<String, dynamic>>(
                                isExpanded: true,
                                dropdownColor: const Color(0xFF1E293B),
                                value: _selectedForm,
                                items: _forms.map((f) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: f,
                                    child: Text(f['title'] ?? 'Untitled Form', style: const TextStyle(color: Colors.white)),
                                  );
                                }).toList(),
                                onChanged: (f) {
                                  if (f != null) _selectForm(f);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Form Description
                        if (_selectedForm != null && (_selectedForm!['description'] ?? '').toString().isNotEmpty) ...[
                          Text(
                            _selectedForm!['description'].toString(),
                            style: const TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 16),
                        ],

                        const Divider(color: Colors.white12),
                        const SizedBox(height: 8),

                        // Dynamic Fields List
                        if (_selectedForm != null) ..._buildDynamicFields(),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton.icon(
          onPressed: (_isSubmitting || _isLoadingForms || _forms.isEmpty) ? null : _submitForm,
          icon: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : const Icon(Icons.check_circle, size: 18),
          label: Text(_isSubmitting ? 'Submitting...' : 'Submit Visit Audit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF06B6D4),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDynamicFields() {
    final fields = List<Map<String, dynamic>>.from(_selectedForm!['fields'] ?? []);
    if (fields.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text('This form has no fields defined.', style: TextStyle(color: Colors.white60)),
          ),
        ),
      ];
    }

    final List<Widget> widgets = [];

    for (var f in fields) {
      final id = f['id']?.toString() ?? '';
      final label = f['label']?.toString() ?? 'Field';
      final type = f['type']?.toString() ?? 'text';
      final isRequired = f['required'] == true;
      final options = List<String>.from(f['options'] ?? []);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label + (isRequired ? ' *' : ''),
                      style: TextStyle(
                        color: isRequired ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (type == 'text') ...[
                TextField(
                  controller: _textControllers[id],
                  maxLines: label.toLowerCase().contains('note') || label.toLowerCase().contains('comment') ? 3 : 1,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter $label...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                  ),
                ),
              ] else if (type == 'choose') ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((opt) {
                    final isSelected = _answers[id] == opt;
                    return ChoiceChip(
                      label: Text(opt),
                      selected: isSelected,
                      selectedColor: const Color(0xFF06B6D4),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _answers[id] = opt);
                        }
                      },
                    );
                  }).toList(),
                ),
              ] else if (type == 'attachments') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isUploadingAttachment ? null : _pickAndUploadAttachment,
                      icon: _isUploadingAttachment
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.cyan, strokeWidth: 2))
                          : const Icon(Icons.add_a_photo, size: 16),
                      label: Text(_isUploadingAttachment ? 'Uploading...' : 'Take/Upload Photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF06B6D4),
                        side: const BorderSide(color: Color(0xFF06B6D4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (_attachmentUrls.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _attachmentUrls.map((url) {
                          return Stack(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                  color: const Color(0xFF0F172A),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: url.startsWith('/uploads')
                                    ? Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.insert_drive_file, color: Colors.white60),
                                      )
                                    : const Icon(Icons.image, color: Colors.cyan),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _attachmentUrls.remove(url));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    return widgets;
  }
}
