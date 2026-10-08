import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AgentsViewScreen extends StatefulWidget {
  const AgentsViewScreen({super.key});

  @override
  State<AgentsViewScreen> createState() => AgentsViewScreenState();
}

class AgentsViewScreenState extends State<AgentsViewScreen> {
  List<dynamic> _agents = [];
  bool _isLoading = true;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  void reload() {
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    try {
      final agents = await ApiService.fetchAgents();
      if (mounted) {
        setState(() {
          _agents = agents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading agents: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
  void _showAddOrEditAgentDialog([dynamic agent]) {
    final isEditing = agent != null;
    final nameController = TextEditingController(text: agent != null ? agent['name'] ?? '' : '');
    final areaController = TextEditingController(text: agent != null ? agent['area'] ?? '' : '');
    final phoneController = TextEditingController(text: agent != null ? agent['phone'] ?? '' : '');
    final emailController = TextEditingController(text: agent != null ? (agent['login_email'] ?? agent['email'] ?? '') : '');
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit : Icons.person_add,
                color: const Color(0xFF06B6D4),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                isEditing ? 'Edit Sales Agent' : 'Add New Sales Agent',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agent Full Name *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. أمينة or Ahmed Hassan',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF06B6D4)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Assigned Territory / Area *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: areaController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Cairo East, Maadi, Giza',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF10B981))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Phone Number', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. +20 100 123 4567',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Login Email Address *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. amina@sales.com',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF06B6D4)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                    ),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 16),
                    const Text('Login Password *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Agent#Amina2026!',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF06B6D4)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white54,
                            size: 18,
                          ),
                          onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        'Password Policy: Min 8 chars with uppercase, lowercase, numbers & symbols.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                  ],
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(isEditing ? Icons.save : Icons.check, size: 18),
              label: Text(isEditing ? 'Save Changes' : 'Create Agent', style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final name = nameController.text.trim();
                final area = areaController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Agent name is required'), backgroundColor: Colors.orangeAccent),
                  );
                  return;
                }

                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Valid login email is required'), backgroundColor: Colors.orangeAccent),
                  );
                  return;
                }

                if (!isEditing && password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Login password is required'), backgroundColor: Colors.orangeAccent),
                  );
                  return;
                }

                Navigator.of(ctx).pop();
                try {
                  if (isEditing) {
                    await ApiService.updateAgent(
                      id: agent['id'],
                      name: name,
                      area: area,
                      phone: phoneController.text.trim(),
                      email: email,
                    );
                  } else {
                    await ApiService.createAgent(
                      name: name,
                      area: area,
                      phone: phoneController.text.trim(),
                      email: email,
                      password: password,
                    );
                  }
                  _loadAgents();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'Agent updated successfully' : 'Agent created successfully with login credentials!'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (err) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $err'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAgent(dynamic agent) async {
    final int id = agent['id'] ?? 0;
    final String name = agent['name'] ?? 'Agent';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 10),
            Text('Delete Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove $name?\nAny assigned locations will be unassigned.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete Agent'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteAgent(id);
        _loadAgents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Agent $name removed'), backgroundColor: const Color(0xFF10B981)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _showResetPasswordDialog(Map<String, dynamic> agent) async {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? localError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.key, color: Color(0xFF06B6D4), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Set Password: ${agent['name']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Login Email: ${agent['login_email'] ?? agent['email'] ?? ''}',
                style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text('New Password', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Agent#2026Pass!',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white54, size: 18),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                ),
              ),
              if (localError != null) ...[
                const SizedBox(height: 10),
                Text(localError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Password Requirements:', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('• Minimum 8 characters', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text('• At least one uppercase letter (A-Z)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text('• At least one lowercase letter (a-z)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text('• At least one number (0-9)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text('• At least one symbol (!@#\$%^&*...)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final newPass = passwordController.text;
                try {
                  final res = await ApiService.resetAgentPassword(agent['id'], newPass);
                  Navigator.of(ctx).pop();
                  _loadAgents();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Password set successfully'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    localError = e.toString().replaceAll('Exception:', '').trim();
                  });
                }
              },
              child: const Text('Save Password', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> get _filteredAgents {
    if (_search.isEmpty) return _agents;
    final term = _search.toLowerCase();
    return _agents.where((a) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      final area = (a['area'] ?? '').toString().toLowerCase();
      final phone = (a['phone'] ?? '').toString().toLowerCase();
      return name.contains(term) || area.contains(term) || phone.contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAgents;

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
                        child: const Icon(Icons.badge, color: Color(0xFF06B6D4), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Sales Agents & Coverage Areas',
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
                  const Text(
                    'Manage your sales team roster and territories for assigning customer accounts & locations.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadAgents,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddOrEditAgentDialog(),
                    icon: const Icon(Icons.person_add, size: 18, color: Colors.black),
                    label: const Text('Add Sales Agent', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search agent name, area/territory, or phone...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
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
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${filtered.length} of ${_agents.length} Agents Registered',
                    style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Agents List Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 54, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(height: 12),
                            Text(
                              _agents.isEmpty ? 'No sales agents added yet' : 'No agents match your search',
                              style: const TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            if (_agents.isEmpty)
                              ElevatedButton.icon(
                                onPressed: () => _showAddOrEditAgentDialog(),
                                icon: const Icon(Icons.add, color: Colors.black, size: 18),
                                label: const Text('Add Your First Agent', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final agent = filtered[index];
                          final String name = agent['name'] ?? 'Unnamed Agent';
                          final String area = agent['area'] ?? 'General Area';
                          final String phone = agent['phone'] ?? '';
                          final String email = agent['email'] ?? '';
                          final int assignedCount = agent['assigned_count'] ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                // Avatar circle
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF06B6D4), Color(0xFF10B981)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Agent Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.location_on, size: 12, color: Color(0xFF10B981)),
                                                const SizedBox(width: 4),
                                                Text(area, style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 4,
                                        children: [
                                          if (phone.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.phone, size: 14, color: Colors.white54),
                                                const SizedBox(width: 4),
                                                Text(phone, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                              ],
                                            ),
                                          if (email.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.email, size: 14, color: Colors.white54),
                                                const SizedBox(width: 4),
                                                Text(email, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                              ],
                                            ),
                                          if ((agent['login_email'] ?? agent['email']) != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                'Login: ${agent['login_email'] ?? agent['email']}',
                                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: assignedCount > 0 ? const Color(0xFF06B6D4).withValues(alpha: 0.15) : Colors.white10,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$assignedCount assigned locations',
                                              style: TextStyle(
                                                color: assignedCount > 0 ? const Color(0xFF06B6D4) : Colors.white54,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Action Buttons
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Set / Reset Login Password',
                                      onPressed: () => _showResetPasswordDialog(agent),
                                      icon: const Icon(Icons.key, color: Colors.amber, size: 20),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.amber.withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Edit Agent',
                                      onPressed: () => _showAddOrEditAgentDialog(agent),
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF06B6D4), size: 20),
                                      style: IconButton.styleFrom(
                                        backgroundColor: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Delete Agent',
                                      onPressed: () => _confirmDeleteAgent(agent),
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
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
    );
  }
}
