import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orchid_employee/presentation/providers/management_provider.dart';
import 'package:orchid_employee/presentation/providers/leave_provider.dart';
import 'package:orchid_employee/data/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:orchid_employee/presentation/widgets/skeleton_loaders.dart';

class ManagerStaffScreen extends StatefulWidget {
  final bool isClockedIn;
  
  const ManagerStaffScreen({super.key, this.isClockedIn = true});

  @override
  State<ManagerStaffScreen> createState() => _ManagerStaffScreenState();
}

class _ManagerStaffScreenState extends State<ManagerStaffScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _allEmployees = [];
  bool _isLoadingEmployees = true;
  String _selectedLeaveFilter = 'Pending';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ManagementProvider>().loadDashboardData();
      context.read<LeaveProvider>().fetchPendingLeaves();
      _loadAllEmployees();
    });
  }

  Future<void> _loadAllEmployees() async {
    final api = context.read<ApiService>();
    try {
      final response = await api.dio.get('/employees');
      if (mounted && response.statusCode == 200) {
        setState(() {
          _allEmployees = response.data as List? ?? [];
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEmployees = false);
      print("Error loading employees: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Staff & Payroll", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal[800],
          tabs: const [
            Tab(text: "Attendance"),
            Tab(text: "Leave Requests"),
            Tab(text: "Directory"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceList(),
          _buildLeaveRequests(),
          _buildStaffDirectory(),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    return Consumer<ManagementProvider>(
      builder: (context, provider, _) {
        final status = provider.employeeStatus;
        if (status.isEmpty) return const ListSkeleton();

        final active = status['active_employees'] ?? [];
        final leaves = (status['on_paid_leave'] ?? []) + (status['on_sick_leave'] ?? []) + (status['on_unpaid_leave'] ?? []);
        final inactive = status['inactive_employees'] ?? [];
        final totalStaff = active.length + leaves.length + inactive.length;

        return RefreshIndicator(
          onRefresh: () => provider.loadDashboardData(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _buildMetricCard("On Duty", "${active.length}", Icons.check_circle, Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMetricCard("On Leave", "${leaves.length}", Icons.event_busy, Colors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildMetricCard("Off Duty", "${inactive.length}", Icons.person_off, Colors.grey)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMetricCard("Headcount", "$totalStaff", Icons.people, Colors.indigo)),
                ],
              ),
              const SizedBox(height: 24),
              _buildStatusSection("Currently on Shift", active, Colors.green),
              const SizedBox(height: 16),
              _buildStatusSection("Away on Leave", leaves, Colors.orange),
              const SizedBox(height: 16),
              _buildStatusSection("Not Scheduled", inactive, Colors.grey),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.05), border: Border.all(color: color.withOpacity(0.1)), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatusSection(String title, List<dynamic> list, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text("${list.length}", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        if (list.isEmpty)
           const Padding(padding: EdgeInsets.all(16), child: Center(child: Text("None", style: TextStyle(color: Colors.grey, fontSize: 13))))
        else
          ...list.map((emp) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Text(emp['name'][0], style: TextStyle(color: color, fontWeight: FontWeight.bold))),
              title: Text(emp['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(emp['role']),
              trailing: Icon(Icons.circle, size: 10, color: color),
            ),
          )),
      ],
    );
  }

  Widget _buildLeaveRequests() {
    return Consumer<LeaveProvider>(
      builder: (context, provider, _) {
        final isPending = _selectedLeaveFilter == 'Pending';
        final list = isPending ? provider.pendingLeaves : provider.leaveHistory;
        
        return Column(
          children: [
            Container(
              height: 60,
              color: Colors.white,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: ['Pending', 'Approved', 'Rejected', 'All'].map((filter) {
                  final isSel = _selectedLeaveFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSel,
                      onSelected: (s) {
                        if (s) {
                          setState(() => _selectedLeaveFilter = filter);
                          if (filter == 'Pending') provider.fetchPendingLeaves();
                          else provider.fetchLeaveHistory(status: filter == 'All' ? null : filter);
                        }
                      },
                      selectedColor: Colors.teal[800],
                      labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (provider.isLoading)
              const Expanded(child: ListSkeleton())
            else if (list.isEmpty)
              _buildEmptyState("Requests", Icons.event_note)
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final leave = list[index];
                    final empName = leave['employee'] != null ? leave['employee']['name'] : (leave['employee_name'] ?? 'Unknown');
                    final status = leave['status'] ?? 'pending';
                    final sColor = status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
                    
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(6)), child: Text(leave['leave_type'] ?? 'Leave', style: TextStyle(fontSize: 10, color: Colors.indigo[900], fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(children: [const Icon(Icons.date_range, size: 14, color: Colors.grey), const SizedBox(width: 6), Text("${leave['from_date']} to ${leave['to_date']}", style: const TextStyle(fontSize: 13, color: Colors.grey))]),
                            if (leave['reason'] != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(leave['reason'], style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 13))),
                            const Divider(height: 24),
                            if (status == 'pending')
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(onPressed: () => _updateLeave(leave['id'], 'rejected'), child: const Text("Reject", style: TextStyle(color: Colors.red))),
                                  const SizedBox(width: 8),
                                  ElevatedButton(onPressed: () => _updateLeave(leave['id'], 'approved'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text("Approve")),
                                ],
                              )
                            else
                              Align(alignment: Alignment.centerRight, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: sColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(status.toUpperCase(), style: TextStyle(color: sColor, fontWeight: FontWeight.bold, fontSize: 10)))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 48, color: Colors.grey[300]), const SizedBox(height: 16), Text("No $msg found", style: const TextStyle(color: Colors.grey))])));
  }

  Widget _buildStaffDirectory() {
    return Consumer<ManagementProvider>(
      builder: (context, provider, _) {
        final status = provider.employeeStatus;
        if (status.isEmpty && provider.isLoading) return const ListSkeleton();

        final List<Map<String, dynamic>> all = [];
        for (var emp in (status['active_employees'] ?? [])) { final e = Map<String, dynamic>.from(emp); e['status'] = 'On Duty'; all.add(e); }
        for (var emp in (status['on_paid_leave'] ?? [])) { final e = Map<String, dynamic>.from(emp); e['status'] = 'On Paid Leave'; all.add(e); }
        for (var emp in (status['on_sick_leave'] ?? [])) { final e = Map<String, dynamic>.from(emp); e['status'] = 'On Sick Leave'; all.add(e); }
        for (var emp in (status['on_unpaid_leave'] ?? [])) { final e = Map<String, dynamic>.from(emp); e['status'] = 'On Unpaid Leave'; all.add(e); }
        for (var emp in (status['inactive_employees'] ?? [])) { final e = Map<String, dynamic>.from(emp); e['status'] = 'Off Duty'; all.add(e); }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: all.length,
          itemBuilder: (context, index) {
            final emp = all[index];
            final s = emp['status'] ?? 'Unknown';
            final sColor = s == 'On Duty' ? Colors.green : (s.contains('Leave') ? Colors.orange : Colors.grey);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.teal[50], child: Text(emp['name'][0], style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.bold))),
                title: Text(emp['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(emp['role']),
                trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: sColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(s, style: TextStyle(fontSize: 10, color: sColor, fontWeight: FontWeight.bold))),
                onTap: () => _showEmployeeDetails(emp),
              ),
            );
          },
        );
      },
    );
  }

  void _showEmployeeDetails(Map<String, dynamic> employee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 24, child: Text(employee['name'][0], style: const TextStyle(fontSize: 20))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(employee['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(employee['role'], style: TextStyle(color: Colors.grey[600]))])),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow('Status', employee['status'] ?? 'N/A'),
            _buildDetailRow('Salary', '₹${NumberFormat.currency(symbol: "", decimalDigits: 0).format(employee['salary'] ?? 0)}'),
            _buildDetailRow('Join Date', employee['join_date'] ?? 'N/A'),
            _buildDetailRow('Email', employee['email'] ?? 'N/A'),
            const SizedBox(height: 16),
            const Text('Leave Entitlements', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSmallLeaveChip('Paid', employee['paid_leave_balance']),
                const SizedBox(width: 8),
                _buildSmallLeaveChip('Sick', employee['sick_leave_balance']),
                const SizedBox(width: 8),
                _buildSmallLeaveChip('Well', employee['wellness_leave_balance']),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(context); _showMonthlyReport(employee); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white), child: const Text("Report"))),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallLeaveChip(String label, dynamic val) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)), child: Column(children: [Text("$val", style: const TextStyle(fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))]));
  }

  void _showMonthlyReport(Map<String, dynamic> employee) async {
    final employeeId = employee['id'];
    final now = DateTime.now();
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([api.dio.get('/attendance/work-logs/$employeeId'), api.dio.get('/leaves/employee/$employeeId'), api.dio.get('/attendance/monthly-report/$employeeId', queryParameters: {'year': now.year, 'month': now.month})]);
      if (!mounted) return;
      Navigator.pop(context);
      _displayMonthlyReport(employee, results[0].data as List? ?? [], results[1].data as List? ?? [], results[2].data as Map<String, dynamic>? ?? {}, now.year, now.month);
    } catch (e) { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); } }
  }

  void _displayMonthlyReport(Map<String, dynamic> employee, List workLogs, List leaves, Map<String, dynamic> report, int year, int month) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Container(height: MediaQuery.of(context).size.height * 0.85, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${employee['name']} - Monthly Summary", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildReportStats("Present", report['present_days'] ?? 0, Colors.green), _buildReportStats("Absent", report['absent_days'] ?? 0, Colors.red), _buildReportStats("Leaves", (report['paid_leaves_taken'] ?? 0), Colors.orange), _buildReportStats("Salary", "₹${NumberFormat.compact().format(report['net_salary'] ?? 0)}", Colors.teal)]), const SizedBox(height: 24), Expanded(child: DefaultTabController(length: 2, child: Column(children: [const TabBar(labelColor: Colors.black, tabs: [Tab(text: "Logs"), Tab(text: "Leaves")]), Expanded(child: TabBarView(children: [_buildSimpleList(workLogs, (l) => "Work Log - ${l['date']}"), _buildSimpleList(leaves, (l) => "${l['leave_type']} - ${l['status']}")]))])))])),
    );
  }

  Widget _buildReportStats(String label, dynamic val, Color color) {
    return Column(children: [Text("$val", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)), Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))]);
  }

  Widget _buildSimpleList(List data, String Function(dynamic) title) {
    if (data.isEmpty) return const Center(child: Text("No records"));
    return ListView.builder(itemCount: data.length, itemBuilder: (context, i) => ListTile(title: Text(title(data[i])), dense: true, leading: const Icon(Icons.circle, size: 8)));
  }

  Future<void> _updateLeave(int id, String status) async {
    final success = await context.read<LeaveProvider>().approveLeave(id, status);
    if (mounted && success) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Leave $status"), backgroundColor: status == 'approved' ? Colors.green : Colors.red));
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [SizedBox(width: 100, child: Text("$label:", style: const TextStyle(color: Colors.grey))), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));
  }
}
