import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/expense.dart';
import '../models/kpi_summary.dart';
import 'gst_report_screen.dart';
import 'ledger_screen.dart';
import 'department_report_screen.dart';
import 'pnl_screen.dart';
import 'vendor_report_screen.dart';
import '../config/constants.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'expense_add_screen.dart';
import 'department_detail_screen.dart';
import 'chart_of_accounts_screen.dart';
import 'journal_entries_screen.dart';
import 'trial_balance_screen.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
        Provider.of<ExpenseProvider>(context, listen: false).fetchExpenses();
        Provider.of<ExpenseProvider>(context, listen: false).fetchBudgetAnalysis();
        // Fetch Dashboard KPIs for the Overview tab
        Provider.of<DashboardProvider>(context, listen: false).fetchKPIData();
        Provider.of<DashboardProvider>(context, listen: false).fetchFinancialTrends();
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return DefaultTabController(
      length: 4, // Changed to 4 tabs - Overview, Pending, History, Accounting
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finance & Expenses'),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: () async {
                final provider = Provider.of<DashboardProvider>(context, listen: false);
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (range != null) {
                  provider.updateDateRange(range.start, range.end);
                }
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'export_csv') {
                  _exportToCSV(context, expenseProvider);
                } else if (value == 'refresh') {
                  expenseProvider.fetchExpenses();
                  expenseProvider.fetchBudgetAnalysis();
                  dashboardProvider.fetchKPIData();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export_csv',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 20),
                      SizedBox(width: 8),
                      Text('Export to CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Refresh Data'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'), // New Analytics Tab
              Tab(text: 'Pending'),
              Tab(text: 'History'),
              Tab(text: 'Accounting'), // Chart of Accounts, Journal Entries, Trial Balance
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. Overview Tab (Financial Dashboard)
            dashboardProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildOverviewTab(dashboardProvider, expenseProvider, currencyFormat),
            
            // 2. Pending Tab
            expenseProvider.isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _buildList(expenseProvider.pendingExpenses, currencyFormat, isPending: true),

            // 3. History Tab
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search by category, description...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (val) {
                      setState(() {
                         _searchQuery = val;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: expenseProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildList(
                        expenseProvider.expenses.where((e) {
                           if (e.status == 'Pending') return false;
                           if (_searchQuery.isEmpty) return true;
                           final q = _searchQuery.toLowerCase();
                           return e.category.toLowerCase().contains(q) || 
                                  e.description.toLowerCase().contains(q) ||
                                  (e.requestedBy ?? '').toLowerCase().contains(q);
                        }).toList(),
                        currencyFormat,
                        isPending: false,
                      ),
                ),
              ],
            ),

            // 4. Accounting Tab
            _buildAccountingTab(context, currencyFormat),
          ],
      ),
    ),
  );
}

  // --- Financial Overview Tab ---
  Widget _buildOverviewTab(DashboardProvider provider, ExpenseProvider expenseProvider, NumberFormat format) {
    final kpi = provider.kpiSummary;
    if (kpi == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              "No Financial Data Available",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Start by adding expenses or bookings",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                provider.fetchKPIData();
                expenseProvider.fetchExpenses();
                expenseProvider.fetchBudgetAnalysis();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchKPIData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. KPI Grid (Rich Overview)
          const Text("Financial Snapshot", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
               _buildKpiCard(
                 'Revenue', 
                 format.format(kpi.totalRevenue), 
                 Icons.arrow_downward, 
                 Colors.green,
                 onTap: () => _showRevenueDetails(context, kpi, format),
               ),
               _buildKpiCard(
                 'Expenses', 
                 format.format(kpi.totalExpenses), 
                 Icons.arrow_upward, 
                 Colors.red,
                 onTap: () => _showExpenseDetails(context, kpi, format),
               ),
               _buildKpiCard(
                 'Net Profit', 
                 format.format(kpi.netProfit), 
                 Icons.account_balance_wallet, 
                 kpi.netProfit >= 0 ? Colors.green : Colors.red,
                 onTap: () => _showProfitDetails(context, kpi, format),
               ),
               _buildKpiCard(
                 'Room Bookings', 
                 '${kpi.roomBookings}', 
                 Icons.hotel, 
                 Colors.blue,
                 onTap: () => _showBookingDetails(context, kpi),
               ),
               _buildKpiCard(
                 'Food Orders', 
                 '${kpi.foodOrders}', 
                 Icons.restaurant, 
                 Colors.orange,
                 onTap: () => _showFoodOrderDetails(context, kpi),
               ),
               _buildKpiCard(
                 'Tax Summary', 
                 format.format(kpi.totalOutputTax - kpi.totalInputTax), 
                 Icons.receipt_long, 
                 Colors.purple,
                 onTap: () => _showTaxDetails(context, kpi, format),
               ),
            ],
          ),

          const SizedBox(height: 16),

          // Quick Insights Banner
          _buildQuickInsights(expenseProvider, kpi),

          const SizedBox(height: 24),

          // 1.5 Charts
          _buildTrendChart(provider),
          const SizedBox(height: 24),
          _buildBudgetComparison(expenseProvider),
          const SizedBox(height: 24),
          _buildExpenseChart(kpi),
          const SizedBox(height: 24),
          _buildBarChart(kpi),

          const SizedBox(height: 24),

          // 2. Department Analysis (Dynamic)
          if (kpi.departmentKpis.isNotEmpty) ...[
            const Text("Department Performance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            ...kpi.departmentKpis.entries.map((entry) {
              final deptName = entry.key;
              final data = entry.value as Map<String, dynamic>;
              final income = (data['income'] ?? 0).toDouble();
              final expense = (data['expenses'] ?? 0).toDouble();
              final assets = (data['assets'] ?? 0).toDouble();
              
              return Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (_) => DepartmentDetailScreen(deptName: deptName, data: data)
                      )
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(deptName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text("Assets: ${format.format(assets)}", style: TextStyle(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(child: _buildDeptMetirc("Income", income, Colors.green, format)),
                            Container(width: 1, height: 40, color: Colors.grey[200]),
                            Expanded(child: _buildDeptMetirc("Expenses", expense, Colors.red, format)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
          ],
          
          // 3. Tools & Reports
          Text("Tools & Reports", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 12),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildFeatureCard(context, "Department\nReports", Icons.business, Colors.indigo, () {
                 if (kpi != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DepartmentReportScreen(kpi: kpi)));
                 }
              }),
              _buildFeatureCard(context, "GST Reports", Icons.receipt_long, Colors.purple, () {
                 if (kpi != null) {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => GstReportScreen(kpi: kpi)));
                 }
              }),
              _buildFeatureCard(context, "Ledgers", Icons.book, Colors.teal, () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerScreen()));
              }),
              _buildFeatureCard(context, "P&L Statement", Icons.bar_chart, Colors.deepOrange, () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const PnLScreen()));
              }),
              _buildFeatureCard(context, "Vendor\nPayables", Icons.payment, Colors.blueGrey, () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorReportScreen()));
              }),
            ],
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildExpenseChart(KpiSummary kpi) {
    if (kpi.departmentKpis.isEmpty) return const SizedBox.shrink();

    final data = kpi.departmentKpis.entries
        .map((e) => MapEntry(e.key, (e.value['expenses'] ?? 0).toDouble()))
        .where((e) => e.value > 0)
        .toList();

    if (data.isEmpty) return const SizedBox.shrink();
    
    // Sort desc
    data.sort((a, b) => b.value.compareTo(a.value));
    
    final total = data.fold(0.0, (sum, e) => sum + e.value);
    final colors = [Colors.blue, Colors.red, Colors.orange, Colors.green, Colors.purple, Colors.teal, Colors.indigo];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Expense Distribution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: data.asMap().entries.map((e) {
                    final index = e.key;
                    final entry = e.value;
                    final color = colors[index % colors.length];
                    final percentage = total > 0 ? (entry.value / total * 100) : 0;
                    
                    return PieChartSectionData(
                      color: color,
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(0)}%',
                      radius: 60,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: data.asMap().entries.map((e) {
                 final color = colors[e.key % colors.length];
                 return Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                     const SizedBox(width: 4),
                     Text(e.value.key, style: const TextStyle(fontSize: 12)),
                   ],
                 );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(KpiSummary kpi) {
    if (kpi.departmentKpis.isEmpty) return const SizedBox.shrink();

    final data = kpi.departmentKpis.entries.toList();
    // Sort by Income desc
    data.sort((a, b) => ((b.value['income']??0).toDouble()).compareTo((a.value['income']??0).toDouble()));
    
    // Take top 5
    final topDepts = data.take(5).toList();
    
    // Find max Y for scaling
    double maxY = 0;
    for (var entry in topDepts) {
       double inc = (entry.value['income'] ?? 0).toDouble();
       double exp = (entry.value['expenses'] ?? 0).toDouble();
       if (inc > maxY) maxY = inc;
       if (exp > maxY) maxY = exp;
    }
    if (maxY == 0) maxY = 100;
    maxY = maxY * 1.2; // buffer

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Income vs Expenses (Top 5)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                       getTooltipColor: (group) => Colors.blueGrey,
                       getTooltipItem: (group, groupIndex, rod, rodIndex) {
                         String type = rodIndex == 0 ? 'Income' : 'Expense';
                         return BarTooltipItem(
                           '$type\n${rod.toY.toStringAsFixed(0)}',
                           const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                         );
                       },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30, // reserved size for labels
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= topDepts.length || value.toInt() < 0) return const SizedBox();
                          final name = topDepts[value.toInt()].key;
                          // Initials
                          String label = name.length > 3 ? name.substring(0, 3).toUpperCase() : name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: topDepts.asMap().entries.map((e) {
                    final index = e.key;
                    final entry = e.value;
                    final income = (entry.value['income'] ?? 0).toDouble();
                    final expense = (entry.value['expenses'] ?? 0).toDouble();

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(toY: income, color: Colors.green, width: 12, borderRadius: BorderRadius.circular(2)),
                        BarChartRodData(toY: expense, color: Colors.red, width: 12, borderRadius: BorderRadius.circular(2)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem("Income", Colors.green),
                const SizedBox(width: 16),
                _buildLegendItem("Expense", Colors.red),
              ],
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)), 
      ],
    );
  }

  Widget _buildDeptMetirc(String label, double value, Color color, NumberFormat fmt) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(fmt.format(value), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildKpiCard(String title, String value, IconData icon, Color color, {bool isLarge = false, VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isLarge ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title, 
                      style: TextStyle(
                        color: Colors.grey[600], 
                        fontSize: isLarge ? 16 : 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(icon, color: color, size: isLarge ? 32 : 24),
                ],
              ),
              SizedBox(height: isLarge ? 16 : 8),
              Text(
                value, 
                style: TextStyle(
                  fontSize: isLarge ? 32 : 20, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.black87,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Tap for details',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickInsights(ExpenseProvider expenseProvider, KpiSummary kpi) {
    final pendingCount = expenseProvider.pendingExpenses.length;
    final budgetData = expenseProvider.budgetAnalysis;
    
    // Find categories over budget
    int overBudgetCount = 0;
    if (budgetData != null) {
      final categories = budgetData['categories'] as List<dynamic>? ?? [];
      overBudgetCount = categories.where((cat) => cat['status'] == 'over_budget').length;
    }

    final insights = <Map<String, dynamic>>[];
    
    if (pendingCount > 0) {
      insights.add({
        'icon': Icons.pending_actions,
        'color': Colors.orange,
        'title': '$pendingCount Pending',
        'subtitle': 'Approvals needed',
      });
    }
    
    if (overBudgetCount > 0) {
      insights.add({
        'icon': Icons.warning,
        'color': Colors.red,
        'title': '$overBudgetCount Over Budget',
        'subtitle': 'Categories exceeded',
      });
    }
    
    if (kpi.netProfit < 0) {
      insights.add({
        'icon': Icons.trending_down,
        'color': Colors.red,
        'title': 'Negative Profit',
        'subtitle': 'Review expenses',
      });
    } else if (kpi.netProfit > 0) {
      final margin = (kpi.netProfit / kpi.totalRevenue * 100);
      if (margin > 20) {
        insights.add({
          'icon': Icons.trending_up,
          'color': Colors.green,
          'title': '${margin.toStringAsFixed(0)}% Margin',
          'subtitle': 'Healthy profit',
        });
      }
    }

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue),
              SizedBox(width: 6),
              Text(
                'Quick Insights',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: insights.map((insight) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      insight['icon'] as IconData,
                      size: 20,
                      color: insight['color'] as Color,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight['title'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: insight['color'] as Color,
                          ),
                        ),
                        Text(
                          insight['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double percentage, Color color) {
     final percentVal = (percentage * 100).clamp(0, 100);
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
             Text("${percentVal.toStringAsFixed(1)}%", style: TextStyle(fontWeight: FontWeight.bold, color: color)),
           ],
         ),
         const SizedBox(height: 6),
         LinearProgressIndicator(
           value: percentage.clamp(0.0, 1.0),
           backgroundColor: Colors.grey.shade200,
           color: color,
           minHeight: 8,
           borderRadius: BorderRadius.circular(4),
         ),
       ],
     );
  }

  Widget _buildList(List<Expense> list, NumberFormat format, {required bool isPending}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              isPending ? "No pending approvals" : "No expense history",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final expense = list[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isPending ? Colors.orange.shade100 : Colors.blueGrey.shade100,
              child: Icon(
                Icons.attach_money,
                color: isPending ? Colors.orange.shade900 : Colors.blueGrey,
              ),
            ),
            title: Text(expense.category, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${expense.requestedBy} • ${expense.date}"),
            trailing: Text(
              format.format(expense.amount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Description: ${expense.description}", style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    if (expense.image != null && expense.image!.isNotEmpty)
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: OutlinedButton.icon(
                                  onPressed: () => _showReceipt(context, expense.image!),
                                  icon: const Icon(Icons.receipt),
                                  label: const Text("View Receipt"),
                              ),
                            ),
                        ),
                    if (isPending)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Provider.of<ExpenseProvider>(context, listen: false)
                                    .updateExpenseStatus(expense.id, 'Rejected');
                              },
                              icon: const Icon(Icons.close),
                              label: const Text("Reject"),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Provider.of<ExpenseProvider>(context, listen: false)
                                    .updateExpenseStatus(expense.id, 'Approved');
                              },
                              icon: const Icon(Icons.check),
                              label: const Text("Approve"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Align(
                        alignment: Alignment.centerRight,
                        child: Chip(
                          label: Text(expense.status),
                          backgroundColor: expense.status == 'Approved' ? Colors.green.shade100 : Colors.red.shade100,
                          labelStyle: TextStyle(
                            color: expense.status == 'Approved' ? Colors.green.shade900 : Colors.red.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendChart(DashboardProvider provider) {
    if (provider.financialTrends.isEmpty) return const SizedBox.shrink();
    
    final trends = provider.financialTrends; // List of Maps
    // Prepare spots
    // We expect 6 months.
    List<FlSpot> revSpots = [];
    List<FlSpot> expSpots = [];
    List<FlSpot> profitSpots = [];
    double maxY = 0;

    for (int i = 0; i < trends.length; i++) {
        final t = trends[i];
        double r = (t['revenue'] ?? 0).toDouble();
        double e = (t['expense'] ?? 0).toDouble();
        double p = (t['profit'] ?? 0).toDouble();
        if (r > maxY) maxY = r;
        if (e > maxY) maxY = e;
        
        revSpots.add(FlSpot(i.toDouble(), r));
        expSpots.add(FlSpot(i.toDouble(), e));
        profitSpots.add(FlSpot(i.toDouble(), p));
    }
    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 100;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             const Text("6-Month Trend Analysis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
             const SizedBox(height: 20),
             SizedBox(
               height: 200,
               child: LineChart(
                 LineChartData(
                   minY: 0,
                   maxY: maxY,
                   lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                             return touchedSpots.map((spot) {
                                String label = "";
                                if (spot.barIndex == 0) label = "Rev";
                                if (spot.barIndex == 1) label = "Exp"; 
                                // Actually line properties.
                                return LineTooltipItem(spot.y.toStringAsFixed(0), const TextStyle(color: Colors.white));
                             }).toList();
                        }
                      )
                   ),
                   gridData: const FlGridData(show: false),
                   titlesData: FlTitlesData(
                     bottomTitles: AxisTitles(
                       sideTitles: SideTitles(
                         showTitles: true,
                         getTitlesWidget: (value, meta) {
                            int idx = value.toInt();
                            if (idx >= 0 && idx < trends.length) {
                               String m = trends[idx]['month'] ?? '';
                               return Padding(padding: const EdgeInsets.only(top: 8), child: Text(m.split(' ')[0], style: const TextStyle(fontSize: 10)));
                            }
                            return const SizedBox();
                         },
                         reservedSize: 30,
                         interval: 1
                       )
                     ),
                     leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                   ),
                   borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
                   lineBarsData: [
                     LineChartBarData(
                       spots: revSpots,
                       isCurved: true,
                       color: Colors.green,
                       barWidth: 3,
                       dotData: const FlDotData(show: false),
                       belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1))
                     ),
                      LineChartBarData(
                       spots: expSpots,
                       isCurved: true,
                       color: Colors.red,
                       barWidth: 3,
                       dotData: const FlDotData(show: false),
                     ),
                   ]
                 )
               )
             ),
             const SizedBox(height: 10),
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 _buildLegendItem("Revenue", Colors.green),
                 const SizedBox(width: 16),
                 _buildLegendItem("Expense", Colors.red),
               ],
             )
           ],
        ),
      ),
    );
  }

  Widget _buildBudgetComparison(ExpenseProvider expenseProvider) {
    final budgetData = expenseProvider.budgetAnalysis;
    if (budgetData == null) return const SizedBox.shrink();

    final categories = budgetData['categories'] as List<dynamic>? ?? [];
    if (categories.isEmpty) return const SizedBox.shrink();

    final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final month = budgetData['month'] ?? 'Current Month';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Budget Tracker", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(month, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildBudgetSummaryCard(
                    "Total Budget",
                    format.format(budgetData['total_budget'] ?? 0),
                    Icons.account_balance_wallet,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBudgetSummaryCard(
                    "Total Spent",
                    format.format(budgetData['total_actual'] ?? 0),
                    Icons.money_off,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Category-wise breakdown
            ...categories.take(6).map((cat) {
              final category = cat['category'] ?? 'Unknown';
              final budget = (cat['budget'] ?? 0).toDouble();
              final actual = (cat['actual'] ?? 0).toDouble();
              final percentageUsed = (cat['percentage_used'] ?? 0).toDouble();
              final status = cat['status'] ?? 'within_budget';
              
              Color statusColor = Colors.green;
              if (status == 'over_budget') {
                statusColor = Colors.red;
              } else if (percentageUsed > 80) {
                statusColor = Colors.orange;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          "${percentageUsed.toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Spent: ${format.format(actual)}",
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        Text(
                          "Budget: ${format.format(budget)}",
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: budget > 0 ? (actual / budget).clamp(0.0, 1.0) : 0,
                      backgroundColor: Colors.grey[200],
                      color: statusColor,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  void _showReceipt(BuildContext context, String imagePath) {
     if (imagePath.isEmpty) return;
     final filename = imagePath.split('/').last;
     final url = "${AppConstants.baseUrl}/expenses/image/$filename";
     print("Loading Receipt URL: $url");
     
     showDialog(
       context: context,
       builder: (ctx) => Dialog(
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             AppBar(
               title: const Text("Receipt"),
               leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
               elevation: 0,
               backgroundColor: Colors.white,
               foregroundColor: Colors.black,
             ),
             ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: Image.network(
                   url,
                   errorBuilder: (ctx, err, stack) => const Padding(
                       padding: EdgeInsets.all(20),
                       child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.broken_image, size: 40), Text("Error loading image")])
                   ),
                   loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                 ),
             ),
           ],
         ),
       )
     );
  }

  // Detailed View Methods for KPI Cards
  
  void _showRevenueDetails(BuildContext context, KpiSummary kpi, NumberFormat format) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Revenue Breakdown',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailCard('Total Revenue', format.format(kpi.totalRevenue), Colors.green, Icons.trending_up),
              const SizedBox(height: 16),
              const Text('Revenue by Payment Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...kpi.revenueByMode.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 16)),
                    Text(
                      format.format(entry.value),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )).toList(),
              const SizedBox(height: 16),
              const Text('Revenue by Department', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...kpi.departmentKpis.entries.map((entry) {
                final income = (entry.value['income'] ?? 0).toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 16)),
                      Text(
                        format.format(income),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpenseDetails(BuildContext context, KpiSummary kpi, NumberFormat format) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Expense Breakdown',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailCard('Total Expenses', format.format(kpi.totalExpenses), Colors.red, Icons.trending_down),
              const SizedBox(height: 16),
              const Text('Expenses by Department', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...kpi.departmentExpenses.map((dept) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dept.department, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            format.format(dept.amount),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dept.percentage.toStringAsFixed(1)}% of total expenses',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfitDetails(BuildContext context, KpiSummary kpi, NumberFormat format) {
    final profitMargin = kpi.totalRevenue > 0 ? (kpi.netProfit / kpi.totalRevenue * 100) : 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profit Analysis',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailCard(
                'Net Profit', 
                format.format(kpi.netProfit), 
                kpi.netProfit >= 0 ? Colors.green : Colors.red, 
                kpi.netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.purple.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Revenue', style: TextStyle(fontSize: 16)),
                        Text(format.format(kpi.totalRevenue), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Expenses', style: TextStyle(fontSize: 16)),
                        Text(format.format(kpi.totalExpenses), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Profit Margin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          '${profitMargin.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: profitMargin >= 20 ? Colors.green : profitMargin >= 10 ? Colors.orange : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, KpiSummary kpi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Booking Details',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailCard('Total Room Bookings', '${kpi.roomBookings}', Colors.blue, Icons.hotel),
              const SizedBox(height: 16),
              const Text('Booking Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildInfoRow('Total Bookings', '${kpi.totalBookings}'),
              _buildInfoRow('Room Bookings', '${kpi.roomBookings}'),
              _buildInfoRow('Average per Day', '${(kpi.roomBookings / 30).toStringAsFixed(1)}'),
            ],
          ),
        ),
      ),
    );
  }

  void _showFoodOrderDetails(BuildContext context, KpiSummary kpi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Food Order Details',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailCard('Total Food Orders', '${kpi.foodOrders}', Colors.orange, Icons.restaurant),
              const SizedBox(height: 16),
              const Text('Order Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildInfoRow('Total Orders', '${kpi.foodOrders}'),
              _buildInfoRow('Average per Day', '${(kpi.foodOrders / 30).toStringAsFixed(1)}'),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaxDetails(BuildContext context, KpiSummary kpi, NumberFormat format) {
    final netTax = kpi.totalOutputTax - kpi.totalInputTax;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tax Summary',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailCard('Net Tax Liability', format.format(netTax), Colors.purple, Icons.receipt_long),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Output Tax (Collected)', style: TextStyle(fontSize: 16)),
                        Text(
                          format.format(kpi.totalOutputTax),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Input Tax (Paid)', style: TextStyle(fontSize: 16)),
                        Text(
                          format.format(kpi.totalInputTax),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Tax Payable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          format.format(netTax),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: netTax > 0 ? Colors.orange : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => GstReportScreen(kpi: kpi)));
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View Full GST Report'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }



  void _exportToCSV(BuildContext context, ExpenseProvider provider) {
    final expenses = provider.expenses;
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export')),
      );
      return;
    }

    // Generate CSV content
    final csvBuffer = StringBuffer();
    csvBuffer.writeln('Date,Category,Description,Amount,Status,Requested By,Department');
    
    for (final expense in expenses) {
      csvBuffer.writeln(
        '${expense.date},'
        '"${expense.category}",'
        '"${expense.description}",'
        '${expense.amount},'
        '${expense.status},'
        '"${expense.requestedBy}",'
        '"${expense.department ?? 'N/A'}"'
      );
    }

    // For web, we'll copy to clipboard
    // In a real app, you'd use a package like 'universal_html' for web downloads
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Expenses'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${expenses.length} expenses ready to export'),
            const SizedBox(height: 16),
            const Text('CSV data has been prepared. Copy to clipboard?', 
              style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Copy to clipboard (web compatible)
              // Note: In production, use clipboard package
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${expenses.length} expenses exported'),
                  action: SnackBarAction(
                    label: 'View',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('CSV Data'),
                          content: SingleChildScrollView(
                            child: SelectableText(csvBuffer.toString()),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy CSV'),
          ),
        ],
      ),
    );
  }

  // ── Accounting Tab ──────────────────────────────────────────────────────────
  Widget _buildAccountingTab(BuildContext ctx, NumberFormat fmt) {
    final dashboardProvider = Provider.of<DashboardProvider>(ctx, listen: false);
    final kpi = dashboardProvider.kpiSummary;

    final List<_AccountingMenuItem> items = [
      _AccountingMenuItem(
        icon: Icons.account_tree_outlined,
        color: const Color(0xFF4F46E5),
        title: 'Chart of Accounts',
        subtitle: 'View & manage account groups and ledgers',
        onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ChartOfAccountsScreen())),
      ),
      _AccountingMenuItem(
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF0891B2),
        title: 'Journal Entries',
        subtitle: 'Double-entry bookkeeping records',
        onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const JournalEntriesScreen())),
      ),
      _AccountingMenuItem(
        icon: Icons.balance_outlined,
        color: const Color(0xFF059669),
        title: 'Trial Balance',
        subtitle: 'Verify debit and credit totals',
        onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const TrialBalanceScreen())),
      ),
      _AccountingMenuItem(
        icon: Icons.percent_outlined,
        color: const Color(0xFFD97706),
        title: 'GST Reports',
        subtitle: 'Output tax, ITC, and net GST payable',
        onTap: () {
          if (kpi == null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('GST data loading, please wait...')),
            );
            dashboardProvider.fetchKPIData().then((_) {
              final updatedKpi = dashboardProvider.kpiSummary;
              if (updatedKpi != null && ctx.mounted) {
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => GstReportScreen(kpi: updatedKpi)));
              }
            });
          } else {
            Navigator.push(ctx, MaterialPageRoute(builder: (_) => GstReportScreen(kpi: kpi)));
          }
        },
      ),
      _AccountingMenuItem(
        icon: Icons.trending_up_outlined,
        color: const Color(0xFF7C3AED),
        title: 'Profit & Loss',
        subtitle: 'Revenue vs expenses analysis',
        onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const PnLScreen())),
      ),
      _AccountingMenuItem(
        icon: Icons.book_outlined,
        color: const Color(0xFFDB2777),
        title: 'Ledger',
        subtitle: 'Transaction history per account',
        onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const LedgerScreen())),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // GST quick stats card
        if (kpi != null) ...[
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GST Summary', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _gstStat('Output GST', fmt.format(kpi.totalOutputTax), Colors.red[200]!),
                    _gstStat('Input ITC', fmt.format(kpi.totalInputTax), Colors.green[200]!),
                    _gstStat(
                      'Net Payable',
                      fmt.format((kpi.totalOutputTax - kpi.totalInputTax).abs()),
                      kpi.totalOutputTax > kpi.totalInputTax ? Colors.orange[200]! : Colors.green[200]!,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        const Text(
          'Accounting',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),

        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(item.subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _gstStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class _AccountingMenuItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountingMenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
