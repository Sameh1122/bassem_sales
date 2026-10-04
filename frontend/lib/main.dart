import 'package:flutter/material.dart';
import 'views/map_view.dart';
import 'views/upload_view.dart';
import 'views/delta_view.dart';
import 'views/columns_view.dart';
import 'views/data_table_view.dart';

void main() {
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
  final GlobalKey<DeltaViewScreenState> _deltaKey = GlobalKey<DeltaViewScreenState>();
  final GlobalKey<DataTableViewScreenState> _tableKey = GlobalKey<DataTableViewScreenState>();

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      MapViewScreen(key: _mapKey),
      UploadViewScreen(onUploadSuccess: () {
        setState(() {
          _currentIndex = 0; // Automatically switch to Map View on successful upload & save!
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapKey.currentState?.reload(forceRecenter: true);
        });
      }),
      DeltaViewScreen(key: _deltaKey),
      const ColumnsViewScreen(),
      DataTableViewScreen(key: _tableKey),
    ];

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
      ),
      body: Row(
        children: [
          // Sidebar Navigation Drawer
          NavigationRail(
            backgroundColor: const Color(0xFF1E293B),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (index == 0) {
                  _mapKey.currentState?.reload();
                } else if (index == 2) {
                  _deltaKey.currentState?.reload();
                } else if (index == 4) {
                  _tableKey.currentState?.reload();
                }
              });
            },
            extended: true,
            minExtendedWidth: 220,
            selectedIconTheme: const IconThemeData(color: Colors.cyan),
            selectedLabelTextStyle: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
            unselectedIconTheme: const IconThemeData(color: Colors.white60),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white60),
            destinations: const [
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
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white12),

          // Main View Content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }
}
