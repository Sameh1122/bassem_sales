import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'views/login_view.dart';
import 'views/map_view.dart';
import 'views/upload_view.dart';
import 'views/batch_manager_view.dart';
import 'views/assign_locations_view.dart';
import 'views/agents_view.dart';
import 'views/delta_view.dart';
import 'views/columns_view.dart';
import 'views/data_table_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.initAuth();
  runApp(const ChillerAnalyticsApp());
}

class ChillerAnalyticsApp extends StatelessWidget {
  const ChillerAnalyticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Excel Map Analytics & Delta Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF06B6D4), // Cyan accent
          secondary: Color(0xFF10B981), // Emerald accent
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<MapViewScreenState> _mapKey = GlobalKey<MapViewScreenState>();
  final GlobalKey<BatchManagerViewScreenState> _batchManagerKey = GlobalKey<BatchManagerViewScreenState>();
  final GlobalKey<AssignLocationsViewScreenState> _assignKey = GlobalKey<AssignLocationsViewScreenState>();
  final GlobalKey<AgentsViewScreenState> _agentsKey = GlobalKey<AgentsViewScreenState>();
  final GlobalKey<DeltaViewScreenState> _deltaKey = GlobalKey<DeltaViewScreenState>();
  final GlobalKey<DataTableViewScreenState> _tableKey = GlobalKey<DataTableViewScreenState>();

  void _onUploadSuccess() {
    setState(() {
      _currentIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapKey.currentState?.reload(forceRecenter: true);
    });
  }

  void _onOpenBatch(dynamic batchId) {
    setState(() {
      _currentIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapKey.currentState?.selectBatch(batchId);
    });
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
    final bool isAdmin = ApiService.isAdmin;
    final String roleName = isAdmin ? 'Admin' : 'Sales Agent';
    final String displayName = (currentUser['name'] ?? currentUser['username'] ?? 'User').toString();
    final String? agentArea = currentUser['agentArea']?.toString();

    // Screens configured by permission: Agents only access MapView
    final List<Widget> screens = isAdmin
        ? [
            MapViewScreen(key: _mapKey),
            UploadViewScreen(onUploadSuccess: _onUploadSuccess),
            BatchManagerViewScreen(key: _batchManagerKey, onOpenBatch: _onOpenBatch),
            AssignLocationsViewScreen(key: _assignKey),
            AgentsViewScreen(key: _agentsKey),
            DeltaViewScreen(key: _deltaKey),
            const ColumnsViewScreen(),
            DataTableViewScreen(key: _tableKey),
          ]
        : [
            MapViewScreen(key: _mapKey),
          ];

    final List<NavigationRailDestination> destinations = isAdmin
        ? const [
            NavigationRailDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: Text('Map View'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.upload_file_outlined),
              selectedIcon: Icon(Icons.upload_file),
              label: Text('Upload & Validate'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.folder_copy_outlined),
              selectedIcon: Icon(Icons.folder_copy),
              label: Text('Batch Manager'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.assignment_ind_outlined),
              selectedIcon: Icon(Icons.assignment_ind),
              label: Text('Assign Locations'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge),
              label: Text('Sales Agents'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.compare_arrows_outlined),
              selectedIcon: Icon(Icons.compare_arrows),
              label: Text('Delta Changes'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.view_column_outlined),
              selectedIcon: Icon(Icons.view_column),
              label: Text('Column Manager'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.table_chart_outlined),
              selectedIcon: Icon(Icons.table_chart),
              label: Text('Data Table'),
            ),
          ]
        : const [
            NavigationRailDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: Text('My Assigned Customers'),
            ),
          ];

    // Clamp current index if user switched roles
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
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
                child: const Icon(Icons.analytics_outlined, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Excel Map Analytics Platform',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.cyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Text('Node.js + Flutter + SQLite', style: TextStyle(color: Colors.cyan, fontSize: 11)),
              ),
            ],
          ),
        ),
        actions: [
          // Current User & Role Badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isAdmin
                  ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                  : const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAdmin ? const Color(0xFF06B6D4) : const Color(0xFF10B981),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAdmin ? Icons.admin_panel_settings : Icons.person,
                  size: 16,
                  color: isAdmin ? const Color(0xFF06B6D4) : const Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Text(
                  '$roleName: $displayName${agentArea != null && agentArea.isNotEmpty ? ' ($agentArea)' : ''}',
                  style: TextStyle(
                    color: isAdmin ? const Color(0xFF06B6D4) : const Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Logout Button
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            onPressed: () {
              ApiService.logout();
              setState(() {
                _currentIndex = 0;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Sidebar Navigation Drawer
          NavigationRail(
            backgroundColor: const Color(0xFF1E293B),
            selectedIndex: safeIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (index == 0) {
                  _mapKey.currentState?.reload();
                } else if (isAdmin) {
                  if (index == 2) {
                    _batchManagerKey.currentState?.reload();
                  } else if (index == 3) {
                    _assignKey.currentState?.reload();
                  } else if (index == 4) {
                    _agentsKey.currentState?.reload();
                  } else if (index == 5) {
                    _deltaKey.currentState?.reload();
                  } else if (index == 7) {
                    _tableKey.currentState?.reload();
                  }
                }
              });
            },
            extended: true,
            minExtendedWidth: 220,
            selectedIconTheme: const IconThemeData(color: Colors.cyan),
            selectedLabelTextStyle: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
            unselectedIconTheme: const IconThemeData(color: Colors.white60),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white60),
            destinations: destinations,
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white12),

          // Main View Content
          Expanded(
            child: IndexedStack(
              index: safeIndex,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }
}
