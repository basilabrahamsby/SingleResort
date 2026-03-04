import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orchid_employee/presentation/providers/management_provider.dart';
import 'package:orchid_employee/presentation/providers/auth_provider.dart';
import 'package:orchid_employee/data/models/management_models.dart';
import 'package:orchid_employee/presentation/screens/manager/department_detail_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_inventory_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_staff_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/financial_reports_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/booking_analysis_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_purchase_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_create_purchase_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_room_mgmt_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_bookings_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_packages_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_food_orders_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_food_management_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_service_assignment_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_expenses_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_accounting_screen.dart';
import 'package:orchid_employee/presentation/screens/manager/manager_reports_screen.dart';
import 'package:orchid_employee/presentation/providers/attendance_provider.dart';
import 'package:orchid_employee/presentation/widgets/skeleton_loaders.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  String _selectedPeriod = "day";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<ManagementProvider>().loadDashboardData(period: _selectedPeriod);
      context.read<AttendanceProvider>().checkTodayStatus(auth.employeeId);
    });
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // When we reach here, permissions are granted and we can
      // continue accessing the position of the device.
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      print("Location error: $e");
      return null;
    }
  }

  void _onPeriodChanged(String? value) {
    if (value != null) {
      setState(() => _selectedPeriod = value);
      context.read<ManagementProvider>().loadDashboardData(period: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagementProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final auth = context.read<AuthProvider>();
    final summary = provider.summary;

    final isClockedIn = attendance.isClockedIn;
    final currencyFormat = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Manager Dashboard", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isClockedIn)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(12)),
              child: DropdownButton<String>(
                value: _selectedPeriod,
                underline: Container(),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.indigo),
                items: const [
                  DropdownMenuItem(value: "day", child: Text("Today", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: "week", child: Text("Weekly", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: "month", child: Text("Monthly", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                ],
                onChanged: _onPeriodChanged,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              await auth.logout();
              if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: provider.isLoading && summary == null
          ? const DashboardSkeleton()
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  provider.loadDashboardData(period: _selectedPeriod),
                  attendance.checkTodayStatus(auth.employeeId),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAttendanceCard(attendance, auth.employeeId),
                  const SizedBox(height: 16),
                  _buildPremiumFinancialOverview(summary, currencyFormat),
                  const SizedBox(height: 24),
                  _buildModuleGrid(summary, isClockedIn),
                  const SizedBox(height: 24),
                  _buildStaffPerformanceHeader(),
                  const SizedBox(height: 12),
                  _buildStaffHeadcount(provider.employeeStatus),
                  const SizedBox(height: 24),
                  _buildDepartmentPerformance(summary),
                  const SizedBox(height: 24),
                  _buildRecentTransactions(provider.recentTransactions, currencyFormat),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: isClockedIn 
          ? FloatingActionButton(
              onPressed: _showQuickActionMenu,
              backgroundColor: Colors.indigo[900],
              child: const Icon(Icons.bolt, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildAttendanceCard(AttendanceProvider attendance, int? empId) {
    final isClockedIn = attendance.isClockedIn;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: isClockedIn ? Colors.green[50] : Colors.red[50], shape: BoxShape.circle),
            child: Icon(isClockedIn ? Icons.timer : Icons.timer_off, color: isClockedIn ? Colors.green : Colors.red, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isClockedIn ? "Logged In" : "Logged Out", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(isClockedIn ? "Duty ongoing • Tap to clock out" : "Clock in to start your shift", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Switch.adaptive(
            value: isClockedIn,
            onChanged: (val) async {
              if (empId == null) return;
              if (val) {
                Position? position = await _getCurrentLocation();
                final success = await attendance.clockIn(
                  empId, 
                  latitude: position?.latitude, 
                  longitude: position?.longitude,
                );
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clocked in successfully"), backgroundColor: Colors.green));
                }
              } else {
                _confirmClockOut(attendance, empId);
              }
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFinancialOverview(ManagementSummary? summary, NumberFormat format) {
    final revenue = (summary?.kpis['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final expenses = (summary?.kpis['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final profit = revenue - expenses;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[900]!, Colors.indigo[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Projected Net Profit", style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(format.format(profit), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSimpleStat("Total Revenue", revenue, Colors.greenAccent, format),
                Container(width: 1, height: 30, color: Colors.white12),
                _buildSimpleStat("Total Expenses", expenses, Colors.orangeAccent, format),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, dynamic value, Color color, NumberFormat format) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(format.format(value), style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildModuleGrid(ManagementSummary? summary, bool isClockedIn) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildModuleCard("Bookings", Icons.hotel_outlined, "Manage Stay", Colors.purple,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManagerBookingsScreen(isClockedIn: isClockedIn)))),
        _buildModuleCard("Staffing", Icons.people_outline, "${summary?.kpis['active_employees'] ?? 0} On Duty", Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManagerStaffScreen(isClockedIn: isClockedIn)))),
        _buildModuleCard("Inventory", Icons.inventory_2_outlined, "Stock level", Colors.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManagerInventoryScreen(isClockedIn: isClockedIn)))),
        _buildModuleCard("Expenses", Icons.money_off_outlined, "Operational", Colors.red,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManagerExpensesScreen(isClockedIn: isClockedIn)))),
        _buildModuleCard("Accounting", Icons.account_balance_outlined, "P&L / GST", Colors.indigo,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagerAccountingScreen()))),
        _buildModuleCard("More", Icons.apps_outlined, "All Tools", Colors.blueGrey,
            onTap: () => _showAllModules(summary, isClockedIn)),
      ],
    );
  }

  Widget _buildModuleCard(String title, IconData icon, String subtitle, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showAllModules(ManagementSummary? summary, bool isClockedIn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Text("Management Console", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
              children: [
                _buildCircleModule("Rooms", Icons.meeting_room, Colors.green, () => _nav(const ManagerRoomMgmtScreen())),
                _buildCircleModule("Menu", Icons.fastfood, Colors.green[800]!, () => _nav(const ManagerFoodOrdersScreen(initialTab: 3))),
                _buildCircleModule("Dining", Icons.restaurant, Colors.deepOrange, () => _nav(const ManagerFoodOrdersScreen(initialTab: 1))),
                _buildCircleModule("Services", Icons.assignment_ind, Colors.cyan, () => _nav(const ManagerServiceAssignmentScreen())),
                _buildCircleModule("Supply", Icons.shopping_cart, Colors.orange, () => _nav(const ManagerPurchaseScreen())),
                _buildCircleModule("Analytics", Icons.analytics, Colors.deepPurple, () => _nav(const ManagerReportsScreen())),
                _buildCircleModule("Trends", Icons.insights, Colors.blueGrey, () => _nav(const BookingAnalysisScreen())),
                _buildCircleModule("Offers", Icons.card_giftcard, Colors.pink, () => _nav(const ManagerPackagesScreen())),
                _buildCircleModule("Finance", Icons.trending_up, Colors.blue, () => _nav(const FinancialReportsScreen())),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _nav(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildCircleModule(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStaffPerformanceHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Staff Presence", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagerStaffScreen())), child: const Text("Directory")),
      ],
    );
  }

  Widget _buildStaffHeadcount(Map<String, List<dynamic>> status) {
    if (status.isEmpty) return const SizedBox();
    final active = status['active_employees']?.length ?? 0;
    final onLeave = (status['on_paid_leave']?.length ?? 0) + (status['on_sick_leave']?.length ?? 0) + (status['on_unpaid_leave']?.length ?? 0);
    final total = active + onLeave + (status['inactive_employees']?.length ?? 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildHeadcountItem("On-Duty", active, Colors.green),
          _buildHeadcountItem("Leave", onLeave, Colors.orange),
          _buildHeadcountItem("Total", total, Colors.indigo),
        ],
      ),
    );
  }

  Widget _buildHeadcountItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDepartmentPerformance(ManagementSummary? summary) {
    if (summary == null || summary.departmentKpis.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Departmental P&L", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...summary.departmentKpis.entries.map((entry) => _buildDeptCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildDeptCard(String name, DepartmentKPI kpi) {
    final profit = kpi.income - kpi.expenses;
    final format = NumberFormat.compact();
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DepartmentDetailScreen(departmentName: name))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Colors.indigo[50], child: Text(name[0], style: TextStyle(color: Colors.indigo[800], fontWeight: FontWeight.bold))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Rev: ₹${format.format(kpi.income)}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${format.format(profit)}", style: TextStyle(color: profit >= 0 ? Colors.green[700] : Colors.red[700], fontWeight: FontWeight.bold, fontSize: 15)),
                Text(profit >= 0 ? "Profit" : "Loss", style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(List<ManagerTransaction> transactions, NumberFormat format) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Latest Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text("See All")),
          ],
        ),
        const SizedBox(height: 8),
        ...transactions.take(5).map((t) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: t.isIncome ? Colors.green[50] : Colors.red[50], shape: BoxShape.circle),
              child: Icon(t.isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline, color: t.isIncome ? Colors.green : Colors.red, size: 20),
            ),
            title: Text(t.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text("${t.category} • ${DateFormat('dd MMM').format(DateTime.parse(t.date))}", style: const TextStyle(fontSize: 11)),
            trailing: Text("${t.isIncome ? "+" : "-"} ₹${format.format(t.amount)}", style: TextStyle(color: t.isIncome ? Colors.green[700] : Colors.red[700], fontWeight: FontWeight.bold)),
          ),
        )),
      ],
    );
  }

  void _confirmClockOut(AttendanceProvider attendance, int empId) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clock Out?"),
        content: const Text("You will lose access to management features until your next shift."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Stay Online")),
          ElevatedButton(onPressed: () { attendance.clockOut(empId); Navigator.pop(ctx); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Clock Out")),
        ],
      ),
    );
  }

  void _showQuickActionMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Global Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildQuickActionItem(Icons.add_shopping_cart, "New Purchase Order", "Supply acquisition", Colors.blue, () => _nav(const ManagerCreatePurchaseScreen())),
            _buildQuickActionItem(Icons.note_add_outlined, "Employee Memo", "Broadcase to staff", Colors.teal, () { Navigator.pop(context); _showStaffMemoDialog(); }),
            _buildQuickActionItem(Icons.warning_amber_rounded, "Critical Alert", "Emergency broadcast", Colors.red, () { Navigator.pop(context); _showEmergencyAlertDialog(); }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }

  void _showStaffMemoDialog() {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Staff Memo"), content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Enter Message", border: OutlineInputBorder()), maxLines: 3), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () { if (controller.text.isNotEmpty) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Memo sent to all staff members"))); } }, child: const Text("Send"))]));
  }

  void _showEmergencyAlertDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text("Emergency Alert")]), content: const Text("This will notify all logged-in staff immediately. Continue?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emergency Alert Broadcasted"), backgroundColor: Colors.red)); }, child: const Text("Confirm"))]));
  }
}
