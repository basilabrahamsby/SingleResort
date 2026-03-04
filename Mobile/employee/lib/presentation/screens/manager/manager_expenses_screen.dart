import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orchid_employee/presentation/providers/auth_provider.dart';
import 'package:orchid_employee/presentation/providers/expense_provider.dart';
import 'package:orchid_employee/presentation/providers/management_provider.dart';
import 'package:orchid_employee/presentation/widgets/skeleton_loaders.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ManagerExpensesScreen extends StatefulWidget {
  final bool isClockedIn;
  
  const ManagerExpensesScreen({super.key, this.isClockedIn = true});

  @override
  State<ManagerExpensesScreen> createState() => _ManagerExpensesScreenState();
}

class _ManagerExpensesScreenState extends State<ManagerExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().fetchExpenses();
      context.read<ExpenseProvider>().fetchBudgetAnalysis();
      context.read<ManagementProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Expense Management", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.red[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.red[800],
          tabs: const [
            Tab(text: "All Expenses"),
            Tab(text: "Budget Analysis"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ExpenseProvider>().fetchExpenses();
              context.read<ExpenseProvider>().fetchBudgetAnalysis();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExpensesTab(currencyFormat),
          _buildBudgetAnalysisTab(currencyFormat),
        ],
      ),
      floatingActionButton: widget.isClockedIn 
          ? FloatingActionButton.extended(
              heroTag: "expenses_fab",
              onPressed: _showExpenseForm,
              backgroundColor: Colors.red[800],
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Add Expense", style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildExpensesTab(NumberFormat format) {
    return Column(
      children: [
        _buildKpiOverview(format),
        Expanded(
          child: _buildExpenseList(format),
        ),
      ],
    );
  }

  Widget _buildBudgetAnalysisTab(NumberFormat format) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final analysis = provider.budgetAnalysis;
        if (analysis == null) return const ListSkeleton();
        
        final categories = analysis['categories'] as List? ?? [];
        final totalBudget = analysis['total_monthly_budget'] ?? 0;
        final totalActual = analysis['total_monthly_actual'] ?? 0;
        final percent = totalBudget > 0 ? (totalActual / totalBudget) * 100 : 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildOverallBudgetCard(totalBudget, totalActual, percent, format),
            const SizedBox(height: 20),
            const Text("Category-wise Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...categories.map((cat) => _buildCategoryBudgetCard(cat, format)),
          ],
        );
      }
    );
  }

  Widget _buildOverallBudgetCard(dynamic budget, dynamic actual, double percent, NumberFormat format) {
    final color = percent > 100 ? Colors.red : (percent > 85 ? Colors.orange : Colors.green);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.indigo[900]!, Colors.indigo[700]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text("Monthly Budget Status", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text("${percent.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBudgetStat("Budgeted", budget, Colors.white70, format),
              _buildBudgetStat("Spent", actual, color, format),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetStat(String label, dynamic value, Color color, NumberFormat format) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(format.format(value), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  Widget _buildCategoryBudgetCard(Map<String, dynamic> cat, NumberFormat format) {
    final budget = cat['budget'] ?? 0;
    final actual = cat['actual'] ?? 0;
    final percent = budget > 0 ? (actual / budget) : 0.0;
    final status = cat['status'] ?? "within_budget";
    
    Color statusColor = Colors.green;
    if (status == "over_budget") statusColor = Colors.red;
    else if (percent > 0.85) statusColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(cat['category'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Spent: ${format.format(actual)}", style: const TextStyle(fontSize: 13)),
                Text("Budget: ${format.format(budget)}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent.clamp(0, 1),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiOverview(NumberFormat format) {
    return Consumer<ManagementProvider>(
      builder: (context, mgmtProvider, _) {
        final stats = mgmtProvider.summary?.kpis ?? {};
        
        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildKpiCard("Total Spent", format.format(stats['total_expenses'] ?? 0), Icons.trending_down, Colors.red),
              _buildKpiCard("Total Count", "${stats['expense_count'] ?? 0} bills", Icons.receipt_long, Colors.orange),
              _buildKpiCard("Purchases", format.format(stats['total_purchases'] ?? 0), Icons.shopping_cart, Colors.blue),
              _buildKpiCard("Vendors", "${stats['vendor_count'] ?? 0} active", Icons.store, Colors.purple),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList(NumberFormat format) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const ListSkeleton();
        if (provider.error != null) return Center(child: Text(provider.error!));
        if (provider.expenses.isEmpty) return const Center(child: Text("No expenses recorded yet."));

        return RefreshIndicator(
          onRefresh: () => provider.fetchExpenses(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.expenses.length,
            itemBuilder: (context, index) {
              final e = provider.expenses[index];
              return _buildExpenseCard(e, format);
            },
          ),
        );
      },
    );
  }

  Widget _buildExpenseCard(dynamic e, NumberFormat format) {
    final date = DateTime.tryParse(e['date'] ?? "") ?? DateTime.now();
    final status = e['status']?.toString().toLowerCase() ?? "pending";
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.outbound, color: Colors.red[800]),
        ),
        title: Text(e['description'] ?? "Expense", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${e['category']} • ${DateFormat('dd MMM yyyy').format(date)}"),
            Text("By: ${e['employee_name'] ?? 'N/A'}", style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(format.format(e['amount']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        onLongPress: widget.isClockedIn ? () => _showDeleteConfirmation(e) : null,
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'approved' || status == 'paid') return Colors.green;
    if (status == 'pending') return Colors.orange;
    if (status == 'rejected') return Colors.red;
    return Colors.blue;
  }

  void _showDeleteConfirmation(dynamic expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Expense"),
        content: Text("Are you sure you want to delete this expense of ₹${expense['amount']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<ExpenseProvider>().deleteExpense(expense['id']);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? "Expense deleted" : "Failed to delete expense")),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showExpenseForm() {
    final descController = TextEditingController();
    final amtController = TextEditingController();
    String category = "Operational";
    String? department;
    
    final auth = context.read<AuthProvider>();
    final employeeId = auth.employeeId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            XFile? selectedImage;
            final ImagePicker picker = ImagePicker();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Add New Expense", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: InkWell(
                    onTap: () async {
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                      if (image != null) setModalState(() { selectedImage = image; });
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[50], border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(16)),
                      child: selectedImage != null 
                        ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(selectedImage!.path), fit: BoxFit.cover))
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey), SizedBox(height: 8), Text("Add Bill Photo", style: TextStyle(color: Colors.grey))]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(controller: descController, decoration: InputDecoration(labelText: "Description", filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                TextField(controller: amtController, decoration: InputDecoration(labelText: "Amount", prefixText: "₹ ", filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  items: ["Operational", "Maintenance", "Food & Bev", "Marketing", "Salaries", "Utilities", "Supplies", "Other"].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => category = val!,
                  decoration: InputDecoration(labelText: "Category", filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: department,
                  items: ["Front Office", "Restaurant", "Kitchen", "Housekeeping", "Maintenance", "Management", "Security"].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => department = val,
                  decoration: InputDecoration(labelText: "Department (Optional)", filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () async {
                      if (descController.text.isEmpty || amtController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
                        return;
                      }
                      final amount = double.tryParse(amtController.text);
                      if (amount == null || employeeId == null) return;

                      final success = await context.read<ExpenseProvider>().createExpense(
                        category: category, amount: amount, description: descController.text, employeeId: employeeId, department: department, image: selectedImage,
                      );

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? "Expense added successfully" : "Failed to add expense"), backgroundColor: success ? Colors.green : Colors.red));
                      }
                    },
                    child: const Text("Submit Expense", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }
}
