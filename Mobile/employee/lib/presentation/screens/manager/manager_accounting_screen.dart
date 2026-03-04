import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orchid_employee/data/services/api_service.dart';
import 'package:orchid_employee/presentation/widgets/skeleton_loaders.dart';
import 'package:intl/intl.dart';

class ManagerAccountingScreen extends StatefulWidget {
  const ManagerAccountingScreen({super.key});

  @override
  State<ManagerAccountingScreen> createState() => _ManagerAccountingScreenState();
}

class _ManagerAccountingScreenState extends State<ManagerAccountingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _accountData = {};
  bool _isLoading = true;
  String _searchQuery = "";
  String _selectedType = "All";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    final api = context.read<ApiService>();
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        api.dio.get('/accounts/ledgers?limit=1000'),
        api.dio.get('/accounts/journal-entries?limit=100'),
        api.dio.get('/accounts/trial-balance?automatic=true'),
        api.dio.get('/accounts/auto-report'),
        api.dio.get('/accounts/comprehensive-report?limit=100'),
        api.dio.get('/gst-reports/b2b-sales'),
        api.dio.get('/gst-reports/b2c-sales'),
        api.dio.get('/gst-reports/hsn-sac-summary'),
      ]);
      
      if (mounted) {
        setState(() {
          _accountData['chart_of_accounts'] = (results[0].data as List?) ?? [];
          _accountData['journal_entries'] = (results[1].data as List?) ?? [];
          _accountData['trial_balance'] = results[2].data ?? {};
          
          final autoReport = results[3].data ?? {};
          _accountData['profit_loss'] = {
             'total_revenue': autoReport['summary']?['total_revenue'] ?? 0,
             'total_expenses': autoReport['summary']?['total_expenses'] ?? 0,
             'revenue_breakdown': _mapRevenueBreakdown(autoReport['revenue']),
             'expense_breakdown': _mapExpenseBreakdown(autoReport['expenses']),
          };

          _accountData['comprehensive'] = results[4].data ?? {};
          _accountData['gst_b2b'] = results[5].data ?? {};
          _accountData['gst_b2c'] = results[6].data ?? {};
          _accountData['gst_hsn'] = results[7].data ?? {};
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
         print("Accounting load error: $e");
         setState(() => _isLoading = false);
      }
    }
  }
  
  List<Map<String, dynamic>> _mapRevenueBreakdown(Map<String, dynamic>? data) {
    if (data == null) return [];
    List<Map<String, dynamic>> list = [];
    if (data['checkouts'] != null) list.add({'category': 'Room Revenue', 'amount': data['checkouts']['room_revenue']});
    if (data['food_orders'] != null) list.add({'category': 'Food Revenue', 'amount': data['food_orders']['billed_revenue']});
    if (data['services'] != null) list.add({'category': 'Service Revenue', 'amount': data['services']['billed_revenue']});
    return list;
  }

  List<Map<String, dynamic>> _mapExpenseBreakdown(Map<String, dynamic>? data) {
    if (data == null) return [];
    List<Map<String, dynamic>> list = [];
    if (data['operating_expenses'] != null) list.add({'category': 'Operating Expenses', 'amount': data['operating_expenses']['total_amount']});
    if (data['inventory_purchases'] != null) list.add({'category': 'Purchases', 'amount': data['inventory_purchases']['total_amount']});
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: "₹", decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Accounting & Finance", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.indigo[900],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo[900],
          tabs: const [
            Tab(text: "Chart of Accounts"),
            Tab(text: "P&L Statement"),
            Tab(text: "Journal Entries"),
            Tab(text: "Trial Balance"),
            Tab(text: "Comprehensive"),
            Tab(text: "GST Reports"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccountData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const ListSkeleton()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChartOfAccounts(currencyFormat),
                _buildProfitLoss(currencyFormat),
                _buildJournalEntries(currencyFormat),
                _buildTrialBalance(currencyFormat),
                _buildComprehensiveReport(currencyFormat),
                _buildGstReports(currencyFormat),
              ],
            ),
    );
  }

  Widget _buildChartOfAccounts(NumberFormat format) {
    final accounts = (_accountData['chart_of_accounts'] as List? ?? []).where((acc) {
      final matchesSearch = (acc['name'] ?? "").toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            (acc['code'] ?? "").toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedType == "All" || (acc['type'] ?? acc['group_name'] ?? "").toString() == _selectedType;
      return matchesSearch && matchesType;
    }).toList();

    // Summary calculations
    double totalAssets = 0;
    double totalLiabilities = 0;
    for (var acc in _accountData['chart_of_accounts'] as List? ?? []) {
      final balance = double.tryParse(acc['current_balance']?.toString() ?? "0") ?? 0;
      final type = (acc['type'] ?? acc['group_name'] ?? "").toString().toLowerCase();
      if (type == "asset") totalAssets += balance;
      if (type == "liability") totalLiabilities += balance;
    }

    return Column(
      children: [
        _buildSearchAndFilterHeader(),
        _buildQuickMetrics(totalAssets, totalLiabilities, format),
        Expanded(
          child: accounts.isEmpty 
              ? const Center(child: Text("No accounts found"))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    final acc = accounts[index];
                    final balance = double.tryParse(acc['current_balance']?.toString() ?? "0") ?? 0;
                    return _buildAccountCard(acc, balance, format);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: "Search account name or code...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                "All", "Asset", "Liability", "Equity", "Revenue", "Expense"
              ].map((type) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type),
                  selected: _selectedType == type,
                  onSelected: (val) => setState(() => _selectedType = type),
                  selectedColor: Colors.indigo[900],
                  labelStyle: TextStyle(color: _selectedType == type ? Colors.white : Colors.black),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMetrics(double assets, double liabilities, NumberFormat format) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard("Net Worth", assets - liabilities, Colors.indigo[900]!, Icons.account_balance, format),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard("Total Assets", assets, Colors.green[700]!, Icons.account_balance_wallet, format),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, double amount, Color color, IconData icon, NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(format.format(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> acc, double balance, NumberFormat format) {
    final type = (acc['type'] ?? acc['group_name'] ?? "N/A").toString();
    final color = _getAccountColor(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(_getAccountIcon(type), color: color),
        ),
        title: Text(acc['name'] ?? "Account", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${acc['code'] ?? ''} • $type", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: Text(format.format(balance), style: TextStyle(fontWeight: FontWeight.bold, color: balance < 0 ? Colors.red : Colors.green[700])),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow("Account Code", acc['code'] ?? "N/A"),
                _buildInfoRow("Group", acc['group_name'] ?? "N/A"),
                _buildInfoRow("Type", type),
                _buildInfoRow("Description", acc['description'] ?? "No description available"),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {}, // View Ledger Button logic
                    icon: const Icon(Icons.list_alt),
                    label: const Text("View Full Ledger"),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildProfitLoss(NumberFormat format) {
    final pnl = _accountData['profit_loss'] as Map? ?? {};
    final revenue = (pnl['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final expenses = (pnl['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final profit = revenue - expenses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: profit >= 0 ? [Colors.green[700]!, Colors.green[900]!] : [Colors.red[700]!, Colors.red[900]!],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text("Net Profit/Loss", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text(format.format(profit), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPnLSmallStat("Gross Revenue", revenue, Colors.white, format),
                    _buildPnLSmallStat("Total Expenses", expenses, Colors.white, format),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildPremiumPnLSection("Revenue Breakdown", pnl['revenue_breakdown'] as List? ?? [], Colors.green, Icons.trending_up, format),
          const SizedBox(height: 16),
          _buildPremiumPnLSection("Expense Categories", pnl['expense_breakdown'] as List? ?? [], Colors.red, Icons.trending_down, format),
        ],
      ),
    );
  }

  Widget _buildPnLSmallStat(String label, double value, Color color, NumberFormat format) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
        Text(format.format(value), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildPremiumPnLSection(String title, List items, Color color, IconData icon, NumberFormat format) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: color),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          if (items.isEmpty) 
            const Padding(padding: EdgeInsets.all(16), child: Text("No data available"))
          else
            ...items.map((item) => ListTile(
              title: Text(item['category'] ?? "Category"),
              trailing: Text(format.format(item['amount'] ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            )),
        ],
      ),
    );
  }

  Widget _buildJournalEntries(NumberFormat format) {
    final entries = _accountData['journal_entries'] as List? ?? [];
    if (entries.isEmpty) return const Center(child: Text("No journal entries found"));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final totalDebit = entry['lines'] != null 
            ? (entry['lines'] as List).where((l) => l['debit_ledger_id'] != null).fold(0.0, (s, l) => s + (double.tryParse(l['amount'].toString()) ?? 0))
            : 0.0;
            
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.blue[50], child: const Icon(Icons.receipt_long, color: Colors.blue)),
            title: Text(entry['entry_number'] ?? "JE-${entry['id']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(entry['description'] ?? "No description"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(format.format(totalDebit), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(DateFormat('dd MMM').format(DateTime.parse(entry['entry_date'])), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrialBalance(NumberFormat format) {
    final trial = _accountData['trial_balance'] as Map? ?? {};
    final totalDebit = double.tryParse(trial['total_debit']?.toString() ?? "0") ?? 0;
    final totalCredit = double.tryParse(trial['total_credit']?.toString() ?? "0") ?? 0;
    final accounts = trial['accounts'] as List? ?? [];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(child: _buildTrialMetric("Total Debit", totalDebit, Colors.red, format)),
              const SizedBox(width: 12),
              Expanded(child: _buildTrialMetric("Total Credit", totalCredit, Colors.green, format)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final acc = accounts[index];
              return Card(
                child: ListTile(
                  title: Text(acc['name'] ?? "Account"),
                  subtitle: Text(acc['code'] ?? "N/A"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBalanceColumn("Dr", acc['debit'], Colors.red, format),
                      const SizedBox(width: 16),
                      _buildBalanceColumn("Cr", acc['credit'], Colors.green, format),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrialMetric(String label, double value, Color color, NumberFormat format) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(format.format(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildBalanceColumn(String label, dynamic value, Color color, NumberFormat format) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(format.format(value ?? 0), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildComprehensiveReport(NumberFormat format) {
    final data = _accountData['comprehensive']?['data'] as Map? ?? {};
    final summary = _accountData['comprehensive']?['summary'] as Map? ?? {};
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPremiumCompSection("Checkouts", summary['total_checkouts'], data['checkouts'] as List?, (item) => format.format(item['grand_total'] ?? 0), format),
        _buildPremiumCompSection("Expenses", summary['total_expenses'], data['expenses'] as List?, (item) => format.format(item['amount'] ?? 0), format),
        _buildPremiumCompSection("Purchases", summary['total_purchases'], data['purchases'] as List?, (item) => format.format(item['total_amount'] ?? 0), format),
      ],
    );
  }

  Widget _buildPremiumCompSection(String title, dynamic totalValue, List? items, String Function(dynamic) valFormatter, NumberFormat format) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Total Value: ${format.format(totalValue ?? 0)}"),
        children: (items ?? []).map((item) => ListTile(
          title: Text(item['description'] ?? item['guest_name'] ?? item['vendor_name'] ?? "Item"),
          trailing: Text(valFormatter(item), style: const TextStyle(fontWeight: FontWeight.bold)),
        )).toList(),
      ),
    );
  }

  Widget _buildGstReports(NumberFormat format) {
    final b2b = _accountData['gst_b2b'] as Map? ?? {};
    final b2c = _accountData['gst_b2c'] as Map? ?? {};
    final hsn = _accountData['gst_hsn'] as Map? ?? {};
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGstPremiumCard("B2B Sales Summary", b2b, format),
        _buildGstPremiumCard("B2C Sales Summary", b2c['summary'] ?? {}, format),
        _buildGstPremiumCard("HSN/SAC Summary", hsn, format),
      ],
    );
  }

  Widget _buildGstPremiumCard(String title, Map data, NumberFormat format) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const Divider(height: 24),
            ...data.entries.where((e) => e.value is num).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(e.value is int ? e.value.toString() : format.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  IconData _getAccountIcon(String type) {
    switch (type.toLowerCase()) {
      case 'asset': return Icons.account_balance_wallet;
      case 'liability': return Icons.credit_card;
      case 'equity': return Icons.pie_chart;
      case 'revenue': return Icons.trending_up;
      case 'expense': return Icons.trending_down;
      default: return Icons.account_balance;
    }
  }

  Color _getAccountColor(String type) {
    switch (type.toLowerCase()) {
      case 'asset': return Colors.green;
      case 'liability': return Colors.red;
      case 'equity': return Colors.blue;
      case 'revenue': return Colors.indigo;
      case 'expense': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
