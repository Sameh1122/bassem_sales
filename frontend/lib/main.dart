import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'views/login_view.dart';
import 'views/map_view.dart';
import 'views/upload_view.dart';
import 'views/assign_locations_view.dart';
import 'views/agents_view.dart';
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
      title: 'Excel Map Analytics & Data Platform',
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
  final GlobalKey<AssignLocationsViewScreenState> _assignKey = GlobalKey<AssignLocationsViewScreenState>();
  final GlobalKey<AgentsViewScreenState> _agentsKey = GlobalKey<AgentsViewScreenState>();
  final GlobalKey<DataTableViewScreenState> _tableKey = GlobalKey<DataTableViewScreenState>();

  void _onUploadSuccess() {
    setState(() {
      _currentIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapKey.currentState?.reload(forceRecenter: true, forceApi: true);
      _tableKey.currentState?.reload(forceApi: true);
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
    final String displayName = (currentUser['name'] ?? currentUser['email'] ?? currentUser['username'] ?? 'User').toString();
    final String? agentArea = currentUser['agentArea']?.toString();

    // Screens configured by permission: 5 tabs for Admin, 1 tab for Sales Agent
    final List<Widget> screens = isAdmin
        ? [
            MapViewScreen(key: _mapKey),
            UploadViewScreen(onUploadSuccess: _onUploadSuccess),
            AssignLocationsViewScreen(key: _assignKey),
            AgentsViewScreen(key: _agentsKey),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    final bool isDesktop = screenWidth >= 1100;

    return Scaffold(
      drawer: (isMobile && isAdmin) ? _buildDrawer(context, safeIndex) : null,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: (isMobile && isAdmin)
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.cyan),
                  tooltip: 'Navigation Menu',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            : null,
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
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
                  size: 15,
                  color: isAdmin ? const Color(0xFF06B6D4) : const Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Text(
                  isMobile ? displayName : '$roleName: $displayName${agentArea != null && agentArea.isNotEmpty ? ' ($agentArea)' : ''}',
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
          const SizedBox(width: 4),
        ],
      ),
      body: isMobile
          ? IndexedStack(
              index: safeIndex,
              children: screens,
            )
          : Row(
              children: [
                // Sidebar Navigation Drawer
                NavigationRail(
                  backgroundColor: const Color(0xFF1E293B),
                  selectedIndex: safeIndex,
                  onDestinationSelected: (index) => _onSelectDestination(index, isAdmin),
                  extended: isDesktop,
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

  void _onSelectDestination(int index, bool isAdmin) {
    setState(() => _currentIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index == 0) {
        _mapKey.currentState?.reload();
      } else if (isAdmin) {
        if (index == 2) {
          _assignKey.currentState?.reload();
        } else if (index == 3) {
          _agentsKey.currentState?.reload();
        } else if (index == 4) {
          _tableKey.currentState?.reload(forceApi: true);
        }
      }
    });
  }

  Widget _buildDrawer(BuildContext context, int safeIndex) {
    final currentUser = ApiService.currentUser ?? {};
    final displayName = (currentUser['name'] ?? currentUser['email'] ?? 'User').toString();
    final email = (currentUser['login_email'] ?? currentUser['email'] ?? '').toString();

    final List<Map<String, dynamic>> menuItems = [
      {'icon': Icons.map_outlined, 'activeIcon': Icons.map, 'label': 'Map View'},
      {'icon': Icons.upload_file_outlined, 'activeIcon': Icons.upload_file, 'label': 'Upload & Validate'},
      {'icon': Icons.assignment_ind_outlined, 'activeIcon': Icons.assignment_ind, 'label': 'Assign Locations'},
      {'icon': Icons.badge_outlined, 'activeIcon': Icons.badge, 'label': 'Sales Agents'},
      {'icon': Icons.table_chart_outlined, 'activeIcon': Icons.table_chart, 'label': 'Data Table'},
    ];

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF10B981)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_outlined, color: Colors.black, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Excel Map Analytics',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Admin: $displayName',
                          style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: menuItems.length,
                itemBuilder: (ctx, index) {
                  final item = menuItems[index];
                  final isSelected = safeIndex == index;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF06B6D4).withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.4)) : null,
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        isSelected ? item['activeIcon'] : item['icon'],
                        color: isSelected ? const Color(0xFF06B6D4) : Colors.white70,
                        size: 20,
                      ),
                      title: Text(
                        item['label'],
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF06B6D4) : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _onSelectDestination(index, true);
                      },
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.of(context).pop();
                  ApiService.logout();
                  setState(() => _currentIndex = 0);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
