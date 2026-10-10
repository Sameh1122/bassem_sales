import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FormResponsesViewScreen extends StatefulWidget {
  const FormResponsesViewScreen({super.key});

  @override
  State<FormResponsesViewScreen> createState() => FormResponsesViewScreenState();
}

class FormResponsesViewScreenState extends State<FormResponsesViewScreen> {
  List<Map<String, dynamic>> _responses = [];
  bool _isLoading = true;
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadResponses();
  }

  void reload() {
    _loadResponses();
  }

  Future<void> _loadResponses() async {
    setState(() => _isLoading = true);
    try {
      final resps = await ApiService.fetchFormResponses(
        status: _selectedStatus,
        search: _searchQuery,
      );
      if (mounted) {
        setState(() {
          _responses = resps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading visit responses: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _reviewResponse(int responseId, String newStatus, [String? feedback]) async {
    try {
      await ApiService.reviewFormResponse(
        responseId: responseId,
        status: newStatus,
        adminFeedback: feedback ?? '',
      );
      _loadResponses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'accepted' ? '✅ Visit response accepted and verified!' : '⚠️ Visit re-opened to agent with feedback.'),
            backgroundColor: newStatus == 'accepted' ? const Color(0xFF10B981) : const Color(0xFFF97316),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating review: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showReopenDialog(int responseId) {
    final feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.replay, color: Color(0xFFF97316), size: 24),
            SizedBox(width: 10),
            Text('Re-open Visit to Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: math.min(460.0, MediaQuery.of(ctx).size.width - 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please specify what requires attention (e.g. photos unclear, wrong temperature, missing verification):',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter feedback for agent...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF97316))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = feedbackController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide feedback reason for reopening'), backgroundColor: Colors.orangeAccent),
                );
                return;
              }
              Navigator.of(ctx).pop();
              _reviewResponse(responseId, 'reopened', text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Re-open to Agent'),
          ),
        ],
      ),
    );
  }

  void _showResponseDetailsModal(Map<String, dynamic> r) {
    final int responseId = r['id'] is int ? r['id'] : (int.tryParse(r['id'].toString()) ?? 0);
    final String formTitle = r['form_title'] ?? 'Audit Form';
    final String customerName = r['customer_name'] ?? 'N/A';
    final String chillerCode = r['chiller_code'] ?? 'N/A';
    final String agentName = r['agent_name'] ?? 'N/A';
    final String status = r['status'] ?? 'submitted';
    final String submittedAt = r['submitted_at'] != null ? r['submitted_at'].toString().split('T').first : '';
    final String adminFeedback = r['admin_feedback'] ?? '';
    final Map<String, dynamic> answers = Map<String, dynamic>.from(r['answers'] ?? {});
    final List<String> attachments = List<String>.from(r['attachments'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                  Text(formTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Customer: $customerName • Chiller: $chillerCode', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: math.min(620.0, MediaQuery.of(ctx).size.width - 32),
          height: math.min(600.0, MediaQuery.of(ctx).size.height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadata banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Submitted By', style: TextStyle(color: Colors.white38, fontSize: 11)),
                          Text(agentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Submission Date', style: TextStyle(color: Colors.white38, fontSize: 11)),
                          Text(submittedAt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (adminFeedback.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF97316)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin Feedback Reason:', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(adminFeedback, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text('Responses & Answers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),

                ...answers.entries.map((e) {
                  final key = e.key;
                  final val = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF06B6D4), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(val.toString(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Photo Attachments & Evidences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: attachments.map((url) {
                      return InkWell(
                        onTap: () {
                          // Preview enlarged image
                          showDialog(
                            context: ctx,
                            builder: (imgCtx) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(url, fit: BoxFit.contain),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                    onPressed: () => Navigator.of(imgCtx).pop(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                            color: const Color(0xFF0F172A),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)),
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
          if (status != 'reopened')
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showReopenDialog(responseId);
              },
              icon: const Icon(Icons.replay, size: 16),
              label: const Text('Re-open to Agent'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF97316),
                side: const BorderSide(color: Color(0xFFF97316)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          if (status != 'accepted')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _reviewResponse(responseId, 'accepted');
              },
              icon: const Icon(Icons.verified, size: 16),
              label: const Text('Accept & Verify'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (status == 'accepted') {
      bg = const Color(0xFF10B981).withOpacity(0.2);
      fg = const Color(0xFF10B981);
      label = 'Accepted';
      icon = Icons.verified;
    } else if (status == 'reopened') {
      bg = const Color(0xFFF97316).withOpacity(0.2);
      fg = const Color(0xFFF97316);
      label = 'Re-opened';
      icon = Icons.replay;
    } else {
      bg = const Color(0xFF06B6D4).withOpacity(0.2);
      fg = const Color(0xFF06B6D4);
      label = 'Submitted';
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  child: const Icon(Icons.rate_review, color: Colors.black, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visit Responses & Review Monitor',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Monitor audit questionnaires submitted by agents. Review photos, accept feedback, or re-open visits.',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadResponses,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Tabs & Search
            Row(
              children: [
                // Filter Tabs
                Wrap(
                  spacing: 8,
                  children: ['All', 'submitted', 'accepted', 'reopened'].map((st) {
                    final isSel = _selectedStatus.toLowerCase() == st.toLowerCase();
                    final label = st == 'All'
                        ? 'All'
                        : st == 'submitted'
                            ? 'Submitted (Pending)'
                            : st == 'accepted'
                                ? 'Accepted'
                                : 'Re-opened';
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSel,
                      selectedColor: const Color(0xFF06B6D4),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.white70,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedStatus = st);
                          _loadResponses();
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by customer, chiller code, or agent...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF06B6D4), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                  _loadResponses();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (val) {
                        setState(() => _searchQuery = val.trim());
                        _loadResponses();
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Responses List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                  : _responses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inbox, color: Colors.white38, size: 54),
                              const SizedBox(height: 12),
                              const Text('No responses found', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('No submissions match status "$_selectedStatus".', style: const TextStyle(color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _responses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) {
                            final r = _responses[idx];
                            final id = r['id'] is int ? r['id'] : (int.tryParse(r['id'].toString()) ?? 0);
                            final formTitle = r['form_title'] ?? 'Audit Form';
                            final customerName = r['customer_name'] ?? 'N/A';
                            final chillerCode = r['chiller_code'] ?? 'N/A';
                            final agentName = r['agent_name'] ?? 'N/A';
                            final status = r['status'] ?? 'submitted';
                            final submittedAt = r['submitted_at'] != null ? r['submitted_at'].toString().split('T').first : '';
                            final attachments = List<String>.from(r['attachments'] ?? []);

                            return InkWell(
                              onTap: () => _showResponseDetailsModal(r),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: status == 'accepted'
                                            ? const Color(0xFF10B981).withOpacity(0.15)
                                            : status == 'reopened'
                                                ? const Color(0xFFF97316).withOpacity(0.15)
                                                : const Color(0xFF06B6D4).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        status == 'accepted'
                                            ? Icons.verified
                                            : status == 'reopened'
                                                ? Icons.replay
                                                : Icons.assignment,
                                        color: status == 'accepted'
                                            ? const Color(0xFF10B981)
                                            : status == 'reopened'
                                                ? const Color(0xFFF97316)
                                                : const Color(0xFF06B6D4),
                                        size: 24,
                                      ),
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
                                                  customerName,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                              ),
                                              _buildStatusBadge(status),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Form: $formTitle • Chiller: $chillerCode',
                                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.person, color: Colors.white38, size: 14),
                                              const SizedBox(width: 4),
                                              Text(agentName, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                              const SizedBox(width: 14),
                                              const Icon(Icons.access_time, color: Colors.white38, size: 14),
                                              const SizedBox(width: 4),
                                              Text(submittedAt, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                              if (attachments.isNotEmpty) ...[
                                                const SizedBox(width: 14),
                                                const Icon(Icons.photo, color: Color(0xFF06B6D4), size: 14),
                                                const SizedBox(width: 4),
                                                Text('${attachments.length} photo(s)', style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12)),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Row(
                                      children: [
                                        if (status != 'accepted')
                                          IconButton(
                                            icon: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                                            tooltip: 'Accept & Verify',
                                            onPressed: () => _reviewResponse(id, 'accepted'),
                                          ),
                                        if (status != 'reopened')
                                          IconButton(
                                            icon: const Icon(Icons.replay, color: Color(0xFFF97316)),
                                            tooltip: 'Re-open to Agent',
                                            onPressed: () => _showReopenDialog(id),
                                          ),
                                        const Icon(Icons.chevron_right, color: Colors.white38),
                                      ],
                                    ),
                                  ],
                                ),
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
