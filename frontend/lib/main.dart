import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/api_service.dart';
import 'services/offline_sync_service.dart';
import 'services/storage.dart';
import 'theme/app_tokens.dart';
import 'widgets/app_feedback.dart';
import 'widgets/offline_sync_banner.dart';
import 'views/login_view.dart';
import 'views/dashboard_view.dart';
import 'views/map_view.dart';
import 'views/upload_view.dart';
import 'views/assign_locations_view.dart';
import 'views/agents_view.dart';
import 'views/data_table_view.dart';
import 'views/forms_manager_view.dart';
import 'views/form_responses_view.dart';
import 'views/system_logs_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.initAuth();
  OfflineSyncService.instance.init();
  runApp(const ChillerAnalyticsApp());
}

class ChillerAnalyticsApp extends StatefulWidget {
  const ChillerAnalyticsApp({super.key});

  @override
  State<ChillerAnalyticsApp> createState() => _ChillerAnalyticsAppState();
}

class _ChillerAnalyticsAppState extends State<ChillerAnalyticsApp> {
  late AppThemeMode _themeMode;
  late String _localeCode;

  @override
  void initState() {
    super.initState();
    _themeMode = AppThemeMode.fromString(getLocalStorage('app_theme_mode'));
    _localeCode = getLocalStorage('app_locale') == 'ar' ? 'ar' : 'en';
  }

  void _setThemeMode(AppThemeMode mode) {
    setState(() => _themeMode = mode);
    setLocalStorage('app_theme_mode', mode.storageKey);
  }

  void _setLocale(String code) {
    final normalized = code == 'ar' ? 'ar' : 'en';
    setState(() => _localeCode = normalized);
    setLocalStorage('app_locale', normalized);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Excel Map Analytics & Data Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTokens.buildThemeData(_themeMode),
      locale: Locale(_localeCode),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: _localeCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: MainNavigationScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
        localeCode: _localeCode,
        onLocaleChanged: _setLocale,
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final String localeCode;
  final ValueChanged<String> onLocaleChanged;

  const MainNavigationScreen({
    super.key,
    this.themeMode = AppThemeMode.dark,
    required this.onThemeModeChanged,
    this.localeCode = 'en',
    required this.onLocaleChanged,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _agentRouteTabSelected = false;
  final GlobalKey<DashboardViewScreenState> _dashboardKey = GlobalKey<DashboardViewScreenState>();
  final GlobalKey<MapViewScreenState> _mapKey = GlobalKey<MapViewScreenState>();
  final GlobalKey<AssignLocationsViewScreenState> _assignKey = GlobalKey<AssignLocationsViewScreenState>();
  final GlobalKey<AgentsViewScreenState> _agentsKey = GlobalKey<AgentsViewScreenState>();
  final GlobalKey<DataTableViewScreenState> _tableKey = GlobalKey<DataTableViewScreenState>();
  final GlobalKey<FormsManagerViewScreenState> _formsKey = GlobalKey<FormsManagerViewScreenState>();
  final GlobalKey<FormResponsesViewScreenState> _responsesKey = GlobalKey<FormResponsesViewScreenState>();
  final GlobalKey<SystemLogsViewScreenState> _logsKey = GlobalKey<SystemLogsViewScreenState>();

  @override
  void initState() {
    super.initState();
    if (ApiService.isLoggedIn) {
      ApiService.validateSession().then((isValid) {
        if (!isValid && mounted) {
          setState(() {
            _currentIndex = 0;
          });
        }
      });
    }
  }

  void _onUploadSuccess() {
    setState(() {
      _currentIndex = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAfterSync();
    });
  }

  void _refreshAfterSync() {
    _dashboardKey.currentState?.reload();
    _mapKey.currentState?.reload(forceRecenter: false, forceApi: true);
    _tableKey.currentState?.reload(forceApi: true);
  }

  @override
  Widget build(BuildContext context) {
    // If not logged in, show dedicated Login Screen
    if (!ApiService.isLoggedIn) {
      return LoginViewScreen(
        onLoginSuccess: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      );
    }

    final currentUser = ApiService.currentUser ?? {};
    final bool isOwner = ApiService.isOwner;
    final bool isRegionalManager = ApiService.isRegionalManager;
    final bool isAdmin = ApiService.isAdmin;
    final bool isSupervisor = ApiService.isSupervisor;
    final bool isTechnician = ApiService.isTechnician;
    final String roleName = isOwner
        ? 'System Owner'
        : (isRegionalManager
            ? 'Regional Manager'
            : (isAdmin
                ? 'Admin'
                : (isSupervisor ? 'Supervisor' : (isTechnician ? 'Technician' : 'Sales Agent'))));
    final String displayName = (currentUser['name'] ?? currentUser['email'] ?? currentUser['username'] ?? 'User').toString();
    final String? agentArea = currentUser['agentArea']?.toString();

    final dashboardWidget = DashboardViewScreen(
      key: _dashboardKey,
      onOpenMap: ({String? branchFilter, bool routeMode = false}) {
        _onSelectDestination(1);
        if (routeMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapKey.currentState?.openRoutePlanner();
          });
        }
      },
      onOpenTable: () => _onSelectDestination(isAdmin ? 5 : (isSupervisor ? 4 : 2)),
      onOpenUpload: isAdmin ? () => _onSelectDestination(2) : null,
      onOpenAssign: isAdmin ? () => _onSelectDestination(3) : (isSupervisor ? () => _onSelectDestination(2) : null),
      onOpenResponses: isAdmin ? () => _onSelectDestination(7) : (isSupervisor ? () => _onSelectDestination(3) : null),
    );

    late final List<Widget> screens;
    late final List<NavigationRailDestination> destinations;

    if (isAdmin) {
      screens = [
        dashboardWidget,
        MapViewScreen(key: _mapKey),
        UploadViewScreen(onUploadSuccess: _onUploadSuccess),
        AssignLocationsViewScreen(key: _assignKey),
        AgentsViewScreen(key: _agentsKey),
        DataTableViewScreen(key: _tableKey),
        FormsManagerViewScreen(key: _formsKey),
        FormResponsesViewScreen(key: _responsesKey),
        if (isOwner) SystemLogsViewScreen(key: _logsKey),
      ];
      destinations = [
        const NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: Text('Home'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: Text('Map View'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.upload_file_outlined),
          selectedIcon: Icon(Icons.upload_file),
          label: Text('Upload & Validate'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.assignment_ind_outlined),
          selectedIcon: Icon(Icons.assignment_ind),
          label: Text('Assign Locations'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.badge_outlined),
          selectedIcon: Icon(Icons.badge),
          label: Text('Sales Agents'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.table_chart_outlined),
          selectedIcon: Icon(Icons.table_chart),
          label: Text('Data Table'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.dynamic_form_outlined),
          selectedIcon: Icon(Icons.dynamic_form),
          label: Text('Forms Manager'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.rate_review_outlined),
          selectedIcon: Icon(Icons.rate_review),
          label: Text('Visit Responses'),
        ),
        if (isOwner)
          const NavigationRailDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: Text('System Logs'),
          ),
      ];
    } else if (isSupervisor) {
      screens = [
        dashboardWidget,
        MapViewScreen(key: _mapKey),
        AssignLocationsViewScreen(key: _assignKey),
        FormResponsesViewScreen(key: _responsesKey),
        DataTableViewScreen(key: _tableKey),
      ];
      destinations = const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: Text('Map'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.assignment_ind_outlined),
          selectedIcon: Icon(Icons.assignment_ind),
          label: Text('Assign'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.rate_review_outlined),
          selectedIcon: Icon(Icons.rate_review),
          label: Text('Responses'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.table_chart_outlined),
          selectedIcon: Icon(Icons.table_chart),
          label: Text('Table'),
        ),
      ];
    } else if (isTechnician) {
      screens = [
        dashboardWidget,
        MapViewScreen(key: _mapKey),
        DataTableViewScreen(key: _tableKey),
      ];
      destinations = const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: Text('Work Map'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.build_circle_outlined),
          selectedIcon: Icon(Icons.build_circle),
          label: Text('Repair Log'),
        ),
      ];
    } else {
      screens = [
        dashboardWidget,
        MapViewScreen(key: _mapKey),
        DataTableViewScreen(key: _tableKey),
      ];
      destinations = const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: Text('My Map'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.list_alt_outlined),
          selectedIcon: Icon(Icons.list_alt),
          label: Text('My List'),
        ),
      ];
    }

    // Clamp current index if user switched roles
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    final bool isDesktop = screenWidth >= 1100;
    final t = AppTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: t.surfaceElevated,
        elevation: 0,
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF10B981)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_outlined, color: Colors.black, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                isMobile ? 'Sales Analytics' : 'Excel Map Analytics Platform',
                style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.cyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Node.js + Flutter + SQLite', style: TextStyle(color: Colors.cyan, fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          // Current User & Role Badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOwner
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.18)
                  : (isAdmin
                      ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOwner
                    ? const Color(0xFF8B5CF6)
                    : (isAdmin ? const Color(0xFF06B6D4) : const Color(0xFF10B981)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOwner
                      ? Icons.security
                      : (isAdmin ? Icons.admin_panel_settings : Icons.person),
                  size: 15,
                  color: isOwner
                      ? const Color(0xFFA78BFA)
                      : (isAdmin ? const Color(0xFF06B6D4) : const Color(0xFF10B981)),
                ),
                const SizedBox(width: 6),
                Text(
                  isMobile ? displayName : '$roleName: $displayName${agentArea != null && agentArea.isNotEmpty ? ' ($agentArea)' : ''}',
                  style: TextStyle(
                    color: isOwner
                        ? const Color(0xFFA78BFA)
                        : (isAdmin ? const Color(0xFF06B6D4) : const Color(0xFF10B981)),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Locale Toggle (EN / عربي) — STORY-009
          Semantics(
            button: true,
            label: widget.localeCode == 'ar' ? 'Switch language to English' : 'Switch language to Arabic',
            child: Tooltip(
              message: widget.localeCode == 'ar' ? 'Switch to English (LTR)' : 'التبديل إلى العربية (RTL)',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.onLocaleChanged(widget.localeCode == 'ar' ? 'en' : 'ar'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.accentPrimary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.accentPrimary.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        widget.localeCode == 'ar' ? 'EN' : 'عربي',
                        style: TextStyle(color: t.accentPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Theme Mode Switcher (Dark / Light / Outdoor Contrast)
          Semantics(
            button: true,
            label: 'Switch theme mode',
            child: PopupMenuButton<AppThemeMode>(
              tooltip: 'Switch Theme',
              icon: Icon(widget.themeMode.icon, color: t.accentPrimary, size: 20),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              color: t.surfaceElevated,
              onSelected: widget.onThemeModeChanged,
              itemBuilder: (ctx) => AppThemeMode.values.map((mode) {
                final selected = mode == widget.themeMode;
                return PopupMenuItem<AppThemeMode>(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(mode.icon, size: 18, color: selected ? t.accentPrimary : t.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mode.label,
                          style: TextStyle(
                            color: selected ? t.accentPrimary : t.textPrimary,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (selected) Icon(Icons.check, size: 16, color: t.accentPrimary),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Change Password Button
          Semantics(
            button: true,
            label: 'Change Password',
            child: IconButton(
              tooltip: 'Change Password',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(Icons.key_outlined, color: t.accentPrimary, size: 20),
              onPressed: () => _showChangePasswordDialog(context),
            ),
          ),

          // Logout Button
          Semantics(
            button: true,
            label: 'Sign Out',
            child: IconButton(
              tooltip: 'Sign Out',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
              onPressed: () {
                ApiService.logout();
                setState(() {
                  _currentIndex = 0;
                });
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isMobile
          ? Column(
              children: [
                Expanded(
                  child: IndexedStack(
              index: safeIndex,
              children: screens,
            )
            ),
            OfflineSyncBanner(
              isCompactMobile: true,
              onSyncCompleted: _refreshAfterSync,
            ),
          ],
        )
          : Row(
              children: [
                // Sidebar Navigation Rail
                NavigationRail(
                  backgroundColor: t.surfaceElevated,
                  selectedIndex: safeIndex,
                  onDestinationSelected: (index) => _onSelectDestination(index),
                  extended: isDesktop,
                  minExtendedWidth: 220,
                  selectedIconTheme: IconThemeData(color: t.accentPrimary),
                  selectedLabelTextStyle: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.bold),
                  unselectedIconTheme: IconThemeData(color: t.textSecondary),
                  unselectedLabelTextStyle: TextStyle(color: t.textSecondary),
                  destinations: destinations,
                ),
                VerticalDivider(thickness: 1, width: 1, color: t.borderSubtle),

                // Main View Content
                Expanded(
                  child: Column(
                    children: [
                      OfflineSyncBanner(
                        isCompactMobile: false,
                        onSyncCompleted: _refreshAfterSync,
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: safeIndex,
                          children: screens,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

      bottomNavigationBar: isMobile ? _buildMobileBottomBar(context, safeIndex, isAdmin, isOwner, t) : null,
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    bool attemptedSubmit = false;
    String? errorMsg;

    InputDecoration pwDecoration(String label, bool obscure, VoidCallback toggle, {String? helper}) {
      return InputDecoration(
        labelText: label,
        helperText: helper,
        helperStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 11.5),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 18),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: toggle,
        ),
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white12),
              ),
              title: const Row(
                children: [
                  Icon(Icons.key_outlined, color: Color(0xFF06B6D4)),
                  SizedBox(width: 10),
                  Text('Change Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Form(
                  key: formKey,
                  autovalidateMode: attemptedSubmit ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: currentCtrl,
                        obscureText: obscureCurrent,
                        style: const TextStyle(color: Colors.white),
                        validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
                        decoration: pwDecoration('Current Password', obscureCurrent, () => setDialogState(() => obscureCurrent = !obscureCurrent)),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newCtrl,
                        obscureText: obscureNew,
                        style: const TextStyle(color: Colors.white),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'New password is required';
                          if (v.length < 8) return 'Must be at least 8 characters';
                          if (v == currentCtrl.text) return 'Must differ from current password';
                          return null;
                        },
                        decoration: pwDecoration(
                          'New Password',
                          obscureNew,
                          () => setDialogState(() => obscureNew = !obscureNew),
                          helper: 'Min 8 chars, uppercase, lowercase, number & symbol',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmCtrl,
                        obscureText: obscureConfirm,
                        style: const TextStyle(color: Colors.white),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm your new password';
                          if (v != newCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                        decoration: pwDecoration('Confirm New Password', obscureConfirm, () => setDialogState(() => obscureConfirm = !obscureConfirm)),
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      ],
    
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            attemptedSubmit = true;
                            errorMsg = null;
                          });
                          if (!(formKey.currentState?.validate() ?? false)) return;
                          setDialogState(() => isSubmitting = true);
                          try {
                            await ApiService.changePassword(currentCtrl.text, newCtrl.text);
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            if (context.mounted) {
                              AppToast.show(context, type: AppToastType.success, message: 'Password updated successfully');
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMsg = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  void _onSelectDestination(int index) {
    setState(() {
      _currentIndex = index;
      _agentRouteTabSelected = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index == 0) {
        _dashboardKey.currentState?.reload();
        return;
      }
      if (ApiService.isAdmin) {
        if (index == 1) _mapKey.currentState?.reload();
        else if (index == 3) _assignKey.currentState?.reload();
        else if (index == 4) _agentsKey.currentState?.reload();
        else if (index == 5) _tableKey.currentState?.reload(forceApi: true);
        else if (index == 6) _formsKey.currentState?.reload();
        else if (index == 7) _responsesKey.currentState?.reload();
        else if (index == 8 && ApiService.isOwner) _logsKey.currentState?.reload();
      } else if (ApiService.isSupervisor) {
        if (index == 1) _mapKey.currentState?.reload();
        else if (index == 2) _assignKey.currentState?.reload();
        else if (index == 3) _responsesKey.currentState?.reload();
        else if (index == 4) _tableKey.currentState?.reload(forceApi: true);
      } else {
        if (index == 1) _mapKey.currentState?.reload();
        else if (index == 2) _tableKey.currentState?.reload();
      }
    });
  }

  Widget _buildMobileBottomBar(BuildContext context, int safeIndex, bool isAdmin, bool isOwner, AppTokens t) {
    if (ApiService.isSupervisor) {
      return Container(
        decoration: BoxDecoration(
          color: t.surfaceElevated,
          border: Border(top: BorderSide(color: t.borderSubtle, width: t.borderWidth)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 64,
            backgroundColor: t.surfaceElevated,
            selectedIndex: safeIndex.clamp(0, 4),
            onDestinationSelected: _onSelectDestination,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
              NavigationDestination(icon: Icon(Icons.assignment_ind_outlined), selectedIcon: Icon(Icons.assignment_ind), label: 'Assign'),
              NavigationDestination(icon: Icon(Icons.rate_review_outlined), selectedIcon: Icon(Icons.rate_review), label: 'Responses'),
              NavigationDestination(icon: Icon(Icons.table_chart_outlined), selectedIcon: Icon(Icons.table_chart), label: 'Table'),
            ],
          ),
        ),
      );
    }

    if (ApiService.isTechnician) {
      return Container(
        decoration: BoxDecoration(
          color: t.surfaceElevated,
          border: Border(top: BorderSide(color: t.borderSubtle, width: t.borderWidth)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 64,
            backgroundColor: t.surfaceElevated,
            selectedIndex: safeIndex.clamp(0, 2),
            onDestinationSelected: _onSelectDestination,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Work Map'),
              NavigationDestination(icon: Icon(Icons.build_circle_outlined), selectedIcon: Icon(Icons.build_circle), label: 'Repair Log'),
            ],
          ),
        ),
      );
    }

    if (!isAdmin) {
      final int agentBarIndex = _agentRouteTabSelected ? 3 : safeIndex.clamp(0, 2);
      return Container(
        decoration: BoxDecoration(
          color: t.surfaceElevated,
          border: Border(top: BorderSide(color: t.borderSubtle, width: t.borderWidth)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 64,
            backgroundColor: t.surfaceElevated,
            selectedIndex: agentBarIndex,
            onDestinationSelected: (barIdx) {
              if (barIdx <= 2) {
                _onSelectDestination(barIdx);
              } else if (barIdx == 3) {
                setState(() {
                  _currentIndex = 1;
                  _agentRouteTabSelected = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mapKey.currentState?.openRoutePlanner();
                });
              }
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'My Map'),
              NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'My List'),
              NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route_rounded), label: 'Route'),
            ],
          ),
        ),
      );
    }

    int adminBarIndex;
    switch (safeIndex) {
      case 0:
        adminBarIndex = 0;
        break;
      case 1:
        adminBarIndex = 1;
        break;
      case 5:
        adminBarIndex = 2;
        break;
      case 7:
        adminBarIndex = 3;
        break;
      default:
        adminBarIndex = 4;
    }

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        border: Border(top: BorderSide(color: t.borderSubtle, width: t.borderWidth)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 64,
          backgroundColor: t.surfaceElevated,
          selectedIndex: adminBarIndex,
          onDestinationSelected: (barIdx) {
            switch (barIdx) {
              case 0:
                _onSelectDestination(0);
                break;
              case 1:
                _onSelectDestination(1);
                break;
              case 2:
                _onSelectDestination(5);
                break;
              case 3:
                _onSelectDestination(7);
                break;
              case 4:
                _showAdminMoreSheet(context, safeIndex, isOwner);
                break;
            }
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
            NavigationDestination(icon: Icon(Icons.table_chart_outlined), selectedIcon: Icon(Icons.table_chart), label: 'Table'),
            NavigationDestination(icon: Icon(Icons.rate_review_outlined), selectedIcon: Icon(Icons.rate_review), label: 'Responses'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'More'),
          ],
        ),
      ),
    );
  }

  void _showAdminMoreSheet(BuildContext context, int safeIndex, bool isOwner) {
    final t = AppTokens.of(context);
    final items = <({int index, IconData icon, String label})>[
      (index: 2, icon: Icons.upload_file_outlined, label: 'Upload & Validate'),
      (index: 3, icon: Icons.assignment_ind_outlined, label: 'Assign Locations'),
      (index: 4, icon: Icons.badge_outlined, label: 'Sales Agents'),
      (index: 6, icon: Icons.dynamic_form_outlined, label: 'Forms Manager'),
      if (isOwner) (index: 8, icon: Icons.receipt_long_outlined, label: 'System Logs'),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusLg)),
        side: BorderSide(color: t.borderSubtle, width: t.borderWidth),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(t.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: t.spaceMd),
                Text('MORE WORKSPACES', style: t.eyebrow),
                SizedBox(height: t.spaceMd),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: t.spaceSm,
                  crossAxisSpacing: t.spaceSm,
                  childAspectRatio: 2.7,
                  children: items.map((item) {
                    final selected = safeIndex == item.index;
                    return InkWell(
                      borderRadius: BorderRadius.circular(t.radiusMd),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _onSelectDestination(item.index);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceSm),
                        decoration: BoxDecoration(
                          color: selected ? t.accentPrimary.withValues(alpha: 0.16) : t.canvasBg,
                          borderRadius: BorderRadius.circular(t.radiusMd),
                          border: Border.all(
                            color: selected ? t.accentPrimary : t.borderSubtle,
                            width: t.borderWidth,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(item.icon, color: selected ? t.accentPrimary : t.textSecondary, size: 20),
                            SizedBox(width: t.spaceSm),
                            Expanded(
                              child: Text(
                                item.label,
                                style: t.caption.copyWith(
                                  color: selected ? t.accentPrimary : t.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: t.spaceLg),
                Text('APPEARANCE', style: t.eyebrow),
                SizedBox(height: t.spaceSm),
                Row(
                  children: AppThemeMode.values.map((mode) {
                    final active = widget.themeMode == mode;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(end: mode == AppThemeMode.outdoor ? 0 : t.spaceSm),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(t.radiusSm),
                          onTap: () {
                            widget.onThemeModeChanged(mode);
                            Navigator.of(sheetCtx).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: active ? t.accentPrimary.withValues(alpha: 0.18) : t.canvasBg,
                              borderRadius: BorderRadius.circular(t.radiusSm),
                              border: Border.all(
                                color: active ? t.accentPrimary : t.borderSubtle,
                                width: t.borderWidth,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(mode.icon, size: 18, color: active ? t.accentPrimary : t.textSecondary),
                                const SizedBox(height: 4),
                                Text(
                                  mode == AppThemeMode.outdoor ? 'Outdoor' : mode.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                                    color: active ? t.accentPrimary : t.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}
