import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/kpi_summary.dart';

// ── GST Report Info Data ────────────────────────────────────────────────────

class _GstReportInfo {
  final String title;
  final String description;
  final List<String> includes;
  final String calculation;
  final String use;
  final String filingRef;
  final List<String> keyFields;

  const _GstReportInfo({
    required this.title,
    required this.description,
    required this.includes,
    required this.calculation,
    required this.use,
    required this.filingRef,
    required this.keyFields,
  });
}

const _gstLiabilityInfo = _GstReportInfo(
  title: 'GST Liability Report',
  description:
      'A summary of your net GST obligation — how much GST you collected from guests (output) versus how much you paid on purchases (input/ITC).',
  includes: [
    'Total Output GST collected from room, food & service billing',
    'Total Input Tax Credit (ITC) from vendor purchase invoices',
    'Net GST Payable = Output GST − ITC',
    'Whether you have excess ITC credit or a liability',
  ],
  calculation:
      'Output GST is calculated from all checkout invoices (room tariff × applicable GST rate + food orders GST + service charges GST). '
      'Input GST is the total GST paid on your vendor purchases. '
      'Net Payable = Output GST − Input ITC. A positive value means you must pay the difference to the GST portal.',
  use:
      'Use this report to determine how much GST you need to remit to the government for the filing period. '
      'This is the core figure for GSTR-3B filing (due by the 20th of the following month). '
      'If ITC > Output, the surplus carries forward as a credit.',
  filingRef: 'GSTR-3B – Table 3.1 (Outward Supplies) & Table 4 (ITC)',
  keyFields: [
    'Output GST (Collected from guests)',
    'Input ITC (Paid on purchases)',
    'Net GST Payable',
    'Excess ITC (if any)',
  ],
);

const _gstDetailedBreakdown = _GstReportInfo(
  title: 'Why These Numbers Matter',
  description: 'Understanding CGST, SGST & IGST',
  includes: [
    'CGST (Central GST) — half the GST rate, goes to Central Government',
    'SGST (State GST) — half the GST rate, goes to Kerala State Government',
    'IGST (Integrated GST) — for interstate transactions, goes fully to Centre then distributed',
    'Hotels typically charge 12% GST on rooms ≤₹7,500/night and 18% on rooms above',
    'Restaurants charge 5% GST (no ITC) or 18% GST with ITC',
  ],
  calculation:
      'For a room charged at ₹5,000/night: Taxable = ₹5,000, CGST = ₹300 (6%), SGST = ₹300 (6%), Total = ₹5,600. '
      'For rooms above ₹7,500: 18% applies → 9% CGST + 9% SGST.',
  use:
      'Understanding the split helps verify that the correct tax rates are applied. '
      'CGST and SGST are always equal. IGST applies when the guest is from another state and the transaction is B2B.',
  filingRef: 'GSTR-1 (Outward Supplies) & GSTR-3B',
  keyFields: ['CGST Rate', 'SGST Rate', 'IGST Rate', 'Taxable Value', 'Tax Slab'],
);

// ── Info Sheet Widget ────────────────────────────────────────────────────────

void _showGstInfoSheet(BuildContext context, _GstReportInfo info) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      info.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // Description
                  Text(
                    info.description,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  // What it includes
                  _infoSection(
                    label: '📋 What This Report Includes',
                    color: const Color(0xFF4F46E5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: info.includes
                          .map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 6, right: 8),
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4F46E5),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: const TextStyle(fontSize: 13, height: 1.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // How it calculates
                  _infoSection(
                    label: '🧮 How It\'s Calculated',
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    child: Text(
                      info.calculation,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Key fields
                  _infoSection(
                    label: '🔑 Key Fields',
                    color: Colors.grey.shade600,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: info.keyFields
                          .map((f) => Chip(
                                label: Text(f, style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.grey[100],
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Use and filing reference
                  _infoSection(
                    label: '✅ Purpose & Filing Use',
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFF0FDF4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.use,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF065F46), height: 1.5),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '📂 ${info.filingRef}',
                            style: const TextStyle(
                              color: Color(0xFF065F46),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _infoSection({
  required String label,
  required Color color,
  required Widget child,
  Color? bgColor,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bgColor ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

// ── Main Screen ────────────────────────────────────────────────────────────

class GstReportScreen extends StatelessWidget {
  final KpiSummary kpi;

  const GstReportScreen({super.key, required this.kpi});

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(locale: "en_IN", symbol: "₹");
    final netLiability = kpi.totalOutputTax - kpi.totalInputTax;

    return Scaffold(
      appBar: AppBar(
        title: const Text("GST Liability Report"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About this report',
            onPressed: () => _showGstInfoSheet(context, _gstLiabilityInfo),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ────────────────────────────────────────────────
            GestureDetector(
              onTap: () => _showGstInfoSheet(context, _gstLiabilityInfo),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Color(0xFF4F46E5), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap ⓘ to learn what this report includes, how taxes are calculated, and how to use it for GST filing.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF3730A3), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Output GST Card ────────────────────────────────────────────
            _buildSummaryCard(
              context,
              "Output GST (Collected from Guests)",
              kpi.totalOutputTax,
              Colors.red,
              format,
              "Liability",
              infoKey: 'output',
            ),
            const SizedBox(height: 16),

            // ── Input ITC Card ────────────────────────────────────────────
            _buildSummaryCard(
              context,
              "Input GST / ITC (Paid on Purchases)",
              kpi.totalInputTax,
              Colors.green,
              format,
              "Asset",
              infoKey: 'input',
            ),
            const SizedBox(height: 24),

            // ── Net Liability Card ─────────────────────────────────────────
            _buildNetLiabilityCard(context, netLiability, format),
            const SizedBox(height: 32),

            // ── Tax rates reference card ───────────────────────────────────
            GestureDetector(
              onTap: () => _showGstInfoSheet(context, _gstDetailedBreakdown),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calculate_outlined, color: Color(0xFF7C3AED), size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GST Rates & CGST/SGST/IGST Explained',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            SizedBox(height: 3),
                            Text('Tap to learn about tax slabs, splitting rules & interstate transactions',
                                style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "Note: This is an estimated report based on Checkout and Purchase records. For official filing, verify with your CA or the GST portal ledger.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double amount,
    Color color,
    NumberFormat fmt,
    String type, {
    String? infoKey,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(
                type == "Liability" ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(amount),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
            // ⓘ info button
            IconButton(
              icon: const Icon(Icons.info_outline, size: 20),
              color: Colors.grey[400],
              tooltip: 'Learn more',
              onPressed: () => _showGstInfoSheet(context, _gstLiabilityInfo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetLiabilityCard(BuildContext context, double amount, NumberFormat fmt) {
    final isPayable = amount > 0;
    return Card(
      color: isPayable ? Colors.orange[50] : Colors.green[50],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Net GST Payable", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showGstInfoSheet(context, _gstLiabilityInfo),
                  child: Icon(Icons.info_outline, size: 18, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fmt.format(amount.abs()),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isPayable ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPayable ? "You need to pay this to GST portal" : "You have excess ITC credit",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPayable ? Colors.red[800] : Colors.green[800],
              ),
            ),
            if (isPayable) ...[
              const SizedBox(height: 6),
              Text(
                'Due by 20th of next month (GSTR-3B)',
                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
