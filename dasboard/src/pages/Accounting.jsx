import React, { useState, useEffect } from "react";
import DashboardLayout from "../layout/DashboardLayout";
import api from "../services/api";
import {
  BookOpen,
  FileText,
  Calculator,
  Plus,
  Edit,
  Trash2,
  Search,
  DollarSign,
  TrendingUp,
  TrendingDown,
  CheckCircle,
  XCircle,
  Info,
  ChevronDown,
  ChevronUp,
  ShoppingCart,
  Receipt,
  BarChart3
} from "lucide-react";

// ── GST Report Info Definitions ─────────────────────────────────────────────
const GST_REPORT_INFO = {
  'master-gst-summary': {
    title: 'Master GST Summary',
    icon: BarChart3,
    color: 'indigo',
    description: 'A consolidated overview of all GST activity — output tax collected from guests, input tax credits from purchases, and net liability.',
    includes: [
      'Total taxable sales (CGST + SGST + IGST)',
      'Total purchases eligible for ITC',
      'Net GST payable = Output GST − ITC',
      'RCM liability summary',
    ],
    calculation: 'Aggregates all checkout revenue (room, food, service) grouped by tax rate. Input tax is pulled from purchase orders. Net = Output GST − ITC claimed.',
    use: "Use to get a bird\u2019s-eye view before filing GST returns. Core figure for GSTR-3B filing (due 20th of following month).",
    filingRef: 'Summary for GSTR-3B filing',
    keyFields: ['Taxable Value', 'CGST', 'SGST', 'IGST', 'Total Output Tax', 'Total ITC', 'Net Payable'],
    endpoint: '/gst-reports/master-summary',
  },
  'gstr-1-sales': {
    title: 'Sales / GSTR-1 (B2B)',
    icon: TrendingUp,
    color: 'green',
    description: 'Lists all B2B taxable sales to GST-registered businesses. Required for GSTR-1 filing on the 11th of each month.',
    includes: [
      'Invoice-wise sales to GST-registered customers',
      'Customer GSTIN, invoice number, date, taxable value',
      'CGST, SGST, IGST split per invoice',
      'Exempt and nil-rated supplies',
    ],
    calculation: 'Pulls all checkout invoices where guest GSTIN is recorded. Tax calculated at applicable slab rate (e.g., 12% room = 6% CGST + 6% SGST).',
    use: 'Your outward supply register — directly used for GSTR-1 filing.',
    filingRef: 'GSTR-1 (Table 4A – B2B Invoices)',
    keyFields: ['GSTIN of Recipient', 'Invoice No.', 'Invoice Date', 'Taxable Value', 'CGST', 'SGST', 'IGST', 'Total Tax'],
    endpoint: '/gst-reports/b2b-sales',
  },
  'itc-register': {
    title: 'Purchases / ITC Register',
    icon: ShoppingCart,
    color: 'blue',
    description: 'Records all inward supplies (purchases) on which Input Tax Credit (ITC) can be claimed to offset your GST liability.',
    includes: [
      'Vendor name and GSTIN',
      'Invoice number, date, and amount',
      'CGST, SGST, IGST paid to vendor',
      'Eligible ITC vs. blocked credit',
    ],
    calculation: 'Pulls all purchase orders with vendor invoices. Reconciled against GSTR-2B portal data.',
    use: "Use to claim Input Tax Credit in GSTR-3B. Ensures you only claim ITC reflected in your vendor\u2019s GSTR-1.",
    filingRef: 'GSTR-3B (Table 4 – ITC available)',
    keyFields: ['Vendor GSTIN', 'Invoice No.', 'Purchase Date', 'Taxable Value', 'CGST', 'SGST', 'IGST', 'Eligible ITC'],
    endpoint: '/gst-reports/itc-register',
  },
  'rcm-register': {
    title: 'RCM Register',
    icon: Receipt,
    color: 'orange',
    description: 'Tracks purchases from unregistered vendors where GST must be paid by you (the recipient) under Reverse Charge Mechanism.',
    includes: [
      'Unregistered vendor invoices',
      'GST amount self-assessed and payable',
      'Category of supply triggering RCM',
      'Payment date and period',
    ],
    calculation: 'Identifies purchase entries marked as RCM. Tax at applicable rate on taxable value. Becomes a payable in GSTR-3B.',
    use: "RCM amounts must be declared and paid in GSTR-3B even though vendor didn\u2019t charge GST. ITC on RCM can be claimed same month.",
    filingRef: 'GSTR-3B (Table 3.1d – Inward under RCM)',
    keyFields: ['Vendor Name', 'Invoice No.', 'Date', 'Supply Category', 'Taxable Value', 'RCM Tax Payable', 'ITC Eligible'],
    endpoint: '/gst-reports/rcm-register',
  },
};

const COLOR_MAP = {
  indigo: { bg: 'bg-indigo-50', border: 'border-indigo-200', text: 'text-indigo-700', badge: 'bg-indigo-100 text-indigo-800', icon: 'text-indigo-500' },
  green: { bg: 'bg-green-50', border: 'border-green-200', text: 'text-green-700', badge: 'bg-green-100 text-green-800', icon: 'text-green-500' },
  blue: { bg: 'bg-blue-50', border: 'border-blue-200', text: 'text-blue-700', badge: 'bg-blue-100 text-blue-800', icon: 'text-blue-500' },
  orange: { bg: 'bg-orange-50', border: 'border-orange-200', text: 'text-orange-700', badge: 'bg-orange-100 text-orange-800', icon: 'text-orange-500' },
};

// ── Accounting Section Info ─────────────────────────────────────────────────
const SECTION_INFO = {
  'chart-of-accounts': {
    title: 'Chart of Accounts (CoA)',
    color: 'indigo',
    description: 'The master list of all financial accounts used in your business. Every transaction must be assigned to an account.',
    includes: [
      'Account Groups — categories like Assets, Liabilities, Revenue, Expenses, Tax',
      'Account Ledgers — specific accounts within each group (e.g., Cash, Bank, Room Revenue)',
      'Account code, opening balance, and module linkage',
      'Balance type: Debit (assets/expenses) or Credit (liabilities/revenue)',
    ],
    calculation: 'Not a calculated report — it is a structural setup. Every transaction (booking, purchase, salary) posts to specific ledgers here. Balances accumulate over time.',
    use: 'Set up once when starting accounting. Add groups for each category of money flow. Add ledgers for specific accounts. Used as the backbone of all other reports (Trial Balance, P&L, GST).',
    tip: 'Tip: Click on a Group to filter ledgers belonging to it.',
  },
  'journal-entries': {
    title: 'Journal Entries',
    color: 'blue',
    description: 'The foundation of double-entry bookkeeping. Every financial event is recorded as a journal entry with at least one debit and one credit that must be equal.',
    includes: [
      'Entry number, date, and description',
      'Lines: Debit ledger + Credit ledger + Amount for each line',
      'Reference to source transaction (Booking, Purchase, etc.)',
      'Total amount must balance (Total Debits = Total Credits)',
    ],
    calculation: 'For example: When a guest checks out paying ₹5,000 — Debit: Cash A/c ₹5,000, Credit: Room Revenue A/c ₹5,000. Both sides are equal, ensuring the books always balance.',
    use: 'Use to record any financial event not automatically captured. Automatic journal entries are created by the system for bookings, purchases, and salaries. Manual entries are for adjustments, corrections, opening balances.',
    tip: 'Tip: Debits increase Assets/Expenses. Credits increase Liabilities/Revenue.',
  },
  'trial-balance': {
    title: 'Trial Balance',
    color: 'green',
    description: 'A summary of all ledger balances at a point in time. Verifies that Total Debits = Total Credits — confirming the books are mathematically balanced.',
    includes: [
      'Every active ledger account with its net balance',
      'Balance shown as Debit or Credit column',
      'Total row showing sum of all debits and sum of all credits',
      'Is Balanced indicator — should always be YES',
    ],
    calculation: 'For each ledger: Net Balance = Sum of all Debits posted − Sum of all Credits posted. Asset/Expense accounts normally show Debit balances. Liability/Revenue accounts show Credit balances.',
    use: 'Run this at month-end before preparing the P&L and Balance Sheet. If it is out of balance, there is a data entry error somewhere that needs correction.',
    tip: 'If out of balance, look for journal entries where debits ≠ credits.',
  },
  'automatic-reports': {
    title: 'Automatic Financial Reports',
    color: 'blue',
    description: 'Dynamic reports generated automatically by analyzing every business event (bookings, food, services, expenses). No manual entries required.',
    includes: [
      'Automatic Profit & Loss (P&L)',
      'Department-wise revenue analysis',
      'Inventory consumption & COGS tracking',
      'Operating expense summaries',
    ],
    calculation: 'Instead of looking at manual journal entries, these reports query the raw operational tables directly (Checkout, PurchaseDetail, Expense) to provide a real-time view of profitability.',
    use: 'Use for a quick, "no-accounting-knowledge" view of how the business is performing today. Refreshes instantly when a guest checks out or a purchase is made.',
    tip: 'Note: These reports are separate from the formal Accounting ledger reports.',
  },
  'comprehensive-report': {
    title: 'Comprehensive Master Report',
    color: 'indigo',
    description: 'The master data extract of the entire resort operation. Aggregates records from every module into a single view.',
    includes: [
      'Master list of all Checkouts, Bookings, and Food Orders',
      'Complete Service history and Employee logs',
      'Every inventory transaction and purchase master',
      'Full record history available for export',
    ],
    calculation: 'A raw data dump from the operational database. It does not perform accounting balancing — it simply shows you exactly what was recorded in each module.',
    use: 'Use when you need to find a specific transaction or audit all activity within a date range. Great for deep-diving into operational history.',
    tip: 'Tip: Use the date filters to narrow down the master record list.',
  },
};

// ── Section Info Popover Component ────────────────────────────────────
const SectionInfoPanel = ({ sectionKey, open, onClose }) => {
  const info = SECTION_INFO[sectionKey];
  if (!info || !open) return null;
  const colorMap = {
    indigo: { header: 'from-indigo-600 to-indigo-700', badge: 'bg-indigo-100 text-indigo-700', dot: 'bg-indigo-400', border: 'border-indigo-200', bg: 'bg-indigo-50' },
    blue: { header: 'from-blue-600 to-blue-700', badge: 'bg-blue-100 text-blue-700', dot: 'bg-blue-400', border: 'border-blue-200', bg: 'bg-blue-50' },
    green: { header: 'from-green-600 to-green-700', badge: 'bg-green-100 text-green-700', dot: 'bg-green-400', border: 'border-green-200', bg: 'bg-green-50' },
  };
  const c = colorMap[info.color];
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 overflow-hidden" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className={`bg-gradient-to-r ${c.header} px-6 py-5 flex items-center justify-between`}>
          <div className="flex items-center gap-3">
            <div className="bg-white/20 rounded-full p-2"><Info size={18} className="text-white" /></div>
            <h2 className="text-lg font-bold text-white">{info.title}</h2>
          </div>
          <button onClick={onClose} className="text-white/70 hover:text-white"><ChevronDown size={20} /></button>
        </div>
        {/* Body */}
        <div className="p-5 space-y-4 max-h-[70vh] overflow-y-auto">
          <p className="text-gray-700 text-sm leading-relaxed">{info.description}</p>

          <div>
            <p className="text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">What It Includes</p>
            <ul className="space-y-1.5">
              {info.includes.map((item, i) => (
                <li key={i} className="flex items-start gap-2 text-sm text-gray-700">
                  <span className={`mt-1.5 w-1.5 h-1.5 rounded-full flex-shrink-0 ${c.dot}`} />
                  {item}
                </li>
              ))}
            </ul>
          </div>

          <div className="bg-amber-50 border border-amber-100 rounded-xl p-3">
            <p className="text-xs font-bold uppercase tracking-wider text-amber-700 mb-1">How It Works</p>
            <p className="text-sm text-amber-800 leading-relaxed">{info.calculation}</p>
          </div>

          <div className={`${c.bg} border ${c.border} rounded-xl p-3`}>
            <p className="text-xs font-bold uppercase tracking-wider text-gray-600 mb-1">How To Use</p>
            <p className="text-sm text-gray-700 leading-relaxed">{info.use}</p>
          </div>

          {info.tip && (
            <div className="bg-yellow-50 border border-yellow-100 rounded-xl p-3 flex items-start gap-2">
              <span className="text-yellow-500 text-base">💡</span>
              <p className="text-sm text-yellow-800">{info.tip}</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};


export default function Accounting() {
  const [activeTab, setActiveTab] = useState("chart-of-accounts");
  const [loading, setLoading] = useState(false);
  const [gstInfoOpen, setGstInfoOpen] = useState({});
  const [gstSummary, setGstSummary] = useState(null);
  const [gstLoading, setGstLoading] = useState(false);
  const [sectionInfoOpen, setSectionInfoOpen] = useState(null); // 'chart-of-accounts' | 'journal-entries' | 'trial-balance'

  // Chart of Accounts State
  const [accountGroups, setAccountGroups] = useState([]);
  const [accountLedgers, setAccountLedgers] = useState([]);
  const [selectedGroup, setSelectedGroup] = useState(null);
  const [showGroupModal, setShowGroupModal] = useState(false);
  const [showLedgerModal, setShowLedgerModal] = useState(false);
  const [editingGroup, setEditingGroup] = useState(null);
  const [editingLedger, setEditingLedger] = useState(null);

  // Journal Entries State
  const [journalEntries, setJournalEntries] = useState([]);
  const [showJournalModal, setShowJournalModal] = useState(false);

  // Trial Balance State
  const [trialBalance, setTrialBalance] = useState(null);

  // Form States
  const [groupForm, setGroupForm] = useState({
    name: "",
    account_type: "Revenue",
    description: ""
  });

  const [ledgerForm, setLedgerForm] = useState({
    name: "",
    code: "",
    group_id: "",
    module: "",
    description: "",
    opening_balance: 0,
    balance_type: "debit",
    tax_type: "",
    tax_rate: "",
    bank_name: "",
    account_number: "",
    ifsc_code: "",
    branch_name: ""
  });

  const [journalForm, setJournalForm] = useState({
    entry_date: new Date().toISOString().split('T')[0],
    description: "",
    notes: "",
    lines: [{ debit_ledger_id: "", credit_ledger_id: "", amount: 0, description: "" }]
  });

  // Fetch Data
  useEffect(() => {
    if (activeTab === "chart-of-accounts") {
      fetchAccountGroups();
      fetchAccountLedgers();
    } else if (activeTab === "journal-entries") {
      fetchJournalEntries();
    } else if (activeTab === "trial-balance") {
      fetchTrialBalance();
    } else if (activeTab === "gst-reports") {
      fetchGstSummary();
    }
  }, [activeTab]);

  const fetchGstSummary = async () => {
    try {
      setGstLoading(true);
      const res = await api.get('/gst-reports/master-summary');
      setGstSummary(res.data);
    } catch (e) {
      console.error('GST summary error:', e);
    } finally {
      setGstLoading(false);
    }
  };

  const toggleGstInfo = (id) => setGstInfoOpen(prev => ({ ...prev, [id]: !prev[id] }));


  const fetchAccountGroups = async () => {
    try {
      const res = await api.get("/accounts/groups?limit=1000");
      setAccountGroups(res.data || []);
    } catch (error) {
      console.error("Failed to fetch account groups:", error);
      alert("Failed to load account groups");
    }
  };

  const fetchAccountLedgers = async () => {
    try {
      const res = await api.get("/accounts/ledgers?limit=1000");
      setAccountLedgers(res.data || []);
    } catch (error) {
      console.error("Failed to fetch account ledgers:", error);
      alert("Failed to load account ledgers");
    }
  };

  const fetchJournalEntries = async () => {
    try {
      setLoading(true);
      const res = await api.get("/accounts/journal-entries?limit=100");
      setJournalEntries(res.data || []);
    } catch (error) {
      console.error("Failed to fetch journal entries:", error);
      alert("Failed to load journal entries");
    } finally {
      setLoading(false);
    }
  };

  const fetchTrialBalance = async () => {
    try {
      setLoading(true);
      const res = await api.get("/accounts/trial-balance");
      setTrialBalance(res.data);
    } catch (error) {
      console.error("Failed to fetch trial balance:", error);
      alert("Failed to load trial balance");
    } finally {
      setLoading(false);
    }
  };

  // Account Group Handlers
  const handleCreateGroup = async (e) => {
    e.preventDefault();
    try {
      if (editingGroup) {
        await api.put(`/accounts/groups/${editingGroup.id}`, groupForm);
      } else {
        await api.post("/accounts/groups", groupForm);
      }
      setShowGroupModal(false);
      setEditingGroup(null);
      setGroupForm({ name: "", account_type: "Revenue", description: "" });
      fetchAccountGroups();
    } catch (error) {
      alert(error.response?.data?.detail || "Failed to save account group");
    }
  };

  const handleDeleteGroup = async (id) => {
    if (!confirm("Are you sure you want to delete this account group?")) return;
    try {
      await api.delete(`/accounts/groups/${id}`);
      fetchAccountGroups();
    } catch (error) {
      alert("Failed to delete account group");
    }
  };

  // Account Ledger Handlers
  const handleCreateLedger = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        ...ledgerForm,
        group_id: parseInt(ledgerForm.group_id),
        opening_balance: parseFloat(ledgerForm.opening_balance) || 0,
        tax_rate: ledgerForm.tax_rate ? parseFloat(ledgerForm.tax_rate) : null
      };

      if (editingLedger) {
        await api.put(`/accounts/ledgers/${editingLedger.id}`, payload);
      } else {
        await api.post("/accounts/ledgers", payload);
      }
      setShowLedgerModal(false);
      setEditingLedger(null);
      setLedgerForm({
        name: "", code: "", group_id: "", module: "", description: "",
        opening_balance: 0, balance_type: "debit", tax_type: "", tax_rate: "",
        bank_name: "", account_number: "", ifsc_code: "", branch_name: ""
      });
      fetchAccountLedgers();
    } catch (error) {
      alert(error.response?.data?.detail || "Failed to save account ledger");
    }
  };

  const handleDeleteLedger = async (id) => {
    if (!confirm("Are you sure you want to delete this account ledger?")) return;
    try {
      await api.delete(`/accounts/ledgers/${id}`);
      fetchAccountLedgers();
    } catch (error) {
      alert("Failed to delete account ledger");
    }
  };

  // Journal Entry Handlers
  const handleAddJournalLine = () => {
    setJournalForm({
      ...journalForm,
      lines: [...journalForm.lines, { debit_ledger_id: "", credit_ledger_id: "", amount: 0, description: "" }]
    });
  };

  const handleRemoveJournalLine = (index) => {
    setJournalForm({
      ...journalForm,
      lines: journalForm.lines.filter((_, i) => i !== index)
    });
  };

  const handleCreateJournalEntry = async (e) => {
    e.preventDefault();
    try {
      // Validate debits equal credits
      const totalDebits = journalForm.lines
        .filter(line => line.debit_ledger_id)
        .reduce((sum, line) => sum + (parseFloat(line.amount) || 0), 0);
      const totalCredits = journalForm.lines
        .filter(line => line.credit_ledger_id)
        .reduce((sum, line) => sum + (parseFloat(line.amount) || 0), 0);

      if (Math.abs(totalDebits - totalCredits) > 0.01) {
        alert(`Journal entry must balance. Debits: ₹${totalDebits.toFixed(2)}, Credits: ₹${totalCredits.toFixed(2)}`);
        return;
      }

      const payload = {
        ...journalForm,
        entry_date: new Date(journalForm.entry_date).toISOString(),
        lines: journalForm.lines.map(line => ({
          ...line,
          debit_ledger_id: line.debit_ledger_id ? parseInt(line.debit_ledger_id) : null,
          credit_ledger_id: line.credit_ledger_id ? parseInt(line.credit_ledger_id) : null,
          amount: parseFloat(line.amount) || 0
        }))
      };

      await api.post("/accounts/journal-entries", payload);
      setShowJournalModal(false);
      setJournalForm({
        entry_date: new Date().toISOString().split('T')[0],
        description: "",
        notes: "",
        lines: [{ debit_ledger_id: "", credit_ledger_id: "", amount: 0, description: "" }]
      });
      fetchJournalEntries();
    } catch (error) {
      alert(error.response?.data?.detail || "Failed to create journal entry");
    }
  };

  const getLedgerName = (ledgerId) => {
    const ledger = accountLedgers.find(l => l.id === ledgerId);
    return ledger ? ledger.name : `Ledger #${ledgerId}`;
  };

  const filteredLedgers = selectedGroup
    ? accountLedgers.filter(l => l.group_id === selectedGroup.id)
    : accountLedgers;

  // ── Seed Chart of Accounts ──────────────────────────────────────────────
  const [seedLoading, setSeedLoading] = useState(false);
  const [seedDone, setSeedDone] = useState(false);

  const seedChartOfAccounts = async () => {
    if (!window.confirm('This will seed a standard hospitality Chart of Accounts (17 groups, 41 ledgers). It will be skipped if groups already exist. Continue?')) return;
    try {
      setSeedLoading(true);
      // Call backend seed endpoint
      await api.post('/accounts/seed-chart-of-accounts');
      setSeedDone(true);
      // Refresh data
      await fetchAccountGroups();
      await fetchAccountLedgers();
      setTimeout(() => setSeedDone(false), 4000);
    } catch (err) {
      const msg = err.response?.data?.detail || err.message || 'Seed failed';
      alert('Seed error: ' + msg);
    } finally {
      setSeedLoading(false);
    }
  };

  return (
    <DashboardLayout>
      {/* Section Info Modal */}
      <SectionInfoPanel
        sectionKey={sectionInfoOpen}
        open={!!sectionInfoOpen}
        onClose={() => setSectionInfoOpen(null)}
      />

      <div className="p-6 space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-3xl font-bold text-gray-800">Accounting Module</h1>
        </div>

        {/* Tabs */}
        <div className="flex space-x-2 border-b border-gray-200 flex-wrap gap-y-1">
          <button
            onClick={() => setActiveTab("chart-of-accounts")}
            className={`px-4 py-2 font-medium ${activeTab === "chart-of-accounts"
              ? "border-b-2 border-indigo-600 text-indigo-600"
              : "text-gray-600 hover:text-gray-800"
              }`}
          >
            <BookOpen className="inline mr-2" size={18} />
            Chart of Accounts
          </button>
          <button
            onClick={() => setActiveTab("journal-entries")}
            className={`px-4 py-2 font-medium ${activeTab === "journal-entries"
              ? "border-b-2 border-indigo-600 text-indigo-600"
              : "text-gray-600 hover:text-gray-800"
              }`}
          >
            <FileText className="inline mr-2" size={18} />
            Journal Entries
          </button>
          <button
            onClick={() => setActiveTab("trial-balance")}
            className={`px-4 py-2 font-medium ${activeTab === "trial-balance"
              ? "border-b-2 border-indigo-600 text-indigo-600"
              : "text-gray-600 hover:text-gray-800"
              }`}
          >
            <Calculator className="inline mr-2" size={18} />
            Trial Balance
          </button>
          <button
            onClick={() => setActiveTab("gst-reports")}
            className={`px-4 py-2 font-medium ${activeTab === "gst-reports"
              ? "border-b-2 border-indigo-600 text-indigo-600"
              : "text-gray-600 hover:text-gray-800"
              }`}
          >
            <Receipt className="inline mr-2" size={18} />
            GST Reports
          </button>
          <button
            onClick={() => setActiveTab("automatic-reports")}
            className={`px-4 py-2 font-medium ${activeTab === "automatic-reports"
              ? "border-b-2 border-indigo-600 text-indigo-600"
              : "text-gray-600 hover:text-gray-800"
              }`}
          >
            <Activity className="inline mr-2" size={18} />
            Automatic Reports
          </button>
          <button
            onClick={() => setActiveTab("comprehensive-report")}
            className={`px-4 py-2 font-medium ${activeTab === "comprehensive-report"
              ? "border-b-2 border-indigo-600 text-indigo-600"
              : "text-gray-600 hover:text-gray-800"
              }`}
          >
            <Database className="inline mr-2" size={18} />
            Comprehensive Report
          </button>
        </div>

        {/* Chart of Accounts Tab */}
        {activeTab === "chart-of-accounts" && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Account Groups */}
            <div className="lg:col-span-1 bg-white rounded-lg shadow p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <h2 className="text-xl font-bold">Account Groups</h2>
                  <button
                    onClick={() => setSectionInfoOpen('chart-of-accounts')}
                    className="p-1 rounded-full text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 transition-colors"
                    title="What is Chart of Accounts?"
                  >
                    <Info size={16} />
                  </button>
                </div>
                <div className="flex items-center gap-2">
                  {/* Seed Button - shown when empty */}
                  {accountGroups.length === 0 && (
                    <button
                      onClick={seedChartOfAccounts}
                      disabled={seedLoading}
                      className="flex items-center gap-1.5 px-3 py-1.5 bg-violet-600 text-white text-sm rounded-lg hover:bg-violet-700 disabled:opacity-50 transition-colors"
                      title="Seed standard hospitality CoA"
                    >
                      {seedLoading ? (
                        <span className="animate-spin inline-block w-3 h-3 border border-white border-t-transparent rounded-full" />
                      ) : (
                        <span>🌱</span>
                      )}
                      {seedLoading ? 'Seeding...' : 'Seed CoA'}
                    </button>
                  )}
                  {seedDone && (
                    <span className="text-xs text-green-600 font-semibold flex items-center gap-1">
                      <CheckCircle size={13} /> Seeded!
                    </span>
                  )}
                  <button
                    onClick={() => {
                      setEditingGroup(null);
                      setGroupForm({ name: "", account_type: "Revenue", description: "" });
                      setShowGroupModal(true);
                    }}
                    className="px-3 py-1 bg-indigo-600 text-white rounded hover:bg-indigo-700"
                  >
                    <Plus size={16} className="inline mr-1" />
                    Add Group
                  </button>
                </div>
              </div>
              <div className="space-y-2 max-h-96 overflow-y-auto">
                {accountGroups.map((group) => (
                  <div
                    key={group.id}
                    onClick={() => setSelectedGroup(group)}
                    className={`p-3 rounded cursor-pointer ${selectedGroup?.id === group.id
                      ? "bg-indigo-100 border-2 border-indigo-600"
                      : "bg-gray-50 hover:bg-gray-100"
                      }`}
                  >
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="font-semibold">{group.name}</p>
                        <p className="text-sm text-gray-600">{group.account_type}</p>
                      </div>
                      <div className="flex space-x-2">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setEditingGroup(group);
                            setGroupForm({
                              name: group.name,
                              account_type: group.account_type,
                              description: group.description || ""
                            });
                            setShowGroupModal(true);
                          }}
                          className="text-blue-600 hover:text-blue-800"
                        >
                          <Edit size={16} />
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleDeleteGroup(group.id);
                          }}
                          className="text-red-600 hover:text-red-800"
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Account Ledgers */}
            <div className="lg:col-span-2 bg-white rounded-lg shadow p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-bold">
                  Account Ledgers
                  {selectedGroup && ` - ${selectedGroup.name}`}
                </h2>
                <button
                  onClick={() => {
                    setEditingLedger(null);
                    setLedgerForm({
                      ...ledgerForm,
                      group_id: selectedGroup?.id || ""
                    });
                    setShowLedgerModal(true);
                  }}
                  className="px-3 py-1 bg-indigo-600 text-white rounded hover:bg-indigo-700"
                  disabled={!selectedGroup}
                >
                  <Plus size={16} className="inline mr-1" />
                  Add Ledger
                </button>
              </div>
              <div className="overflow-x-auto">
                <table className="min-w-full">
                  <thead className="bg-gray-100">
                    <tr>
                      <th className="px-4 py-2 text-left">Name</th>
                      <th className="px-4 py-2 text-left">Code</th>
                      <th className="px-4 py-2 text-left">Module</th>
                      <th className="px-4 py-2 text-left">Opening Balance</th>
                      <th className="px-4 py-2 text-left">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredLedgers.map((ledger) => (
                      <tr key={ledger.id} className="border-b">
                        <td className="px-4 py-2">{ledger.name}</td>
                        <td className="px-4 py-2">{ledger.code || "-"}</td>
                        <td className="px-4 py-2">{ledger.module || "-"}</td>
                        <td className="px-4 py-2">₹{ledger.opening_balance?.toFixed(2) || "0.00"}</td>
                        <td className="px-4 py-2">
                          <div className="flex space-x-2">
                            <button
                              onClick={() => {
                                setEditingLedger(ledger);
                                setLedgerForm({
                                  name: ledger.name,
                                  code: ledger.code || "",
                                  group_id: ledger.group_id.toString(),
                                  module: ledger.module || "",
                                  description: ledger.description || "",
                                  opening_balance: ledger.opening_balance || 0,
                                  balance_type: ledger.balance_type,
                                  tax_type: ledger.tax_type || "",
                                  tax_rate: ledger.tax_rate?.toString() || "",
                                  bank_name: ledger.bank_name || "",
                                  account_number: ledger.account_number || "",
                                  ifsc_code: ledger.ifsc_code || "",
                                  branch_name: ledger.branch_name || ""
                                });
                                setShowLedgerModal(true);
                              }}
                              className="text-blue-600 hover:text-blue-800"
                            >
                              <Edit size={16} />
                            </button>
                            <button
                              onClick={() => handleDeleteLedger(ledger.id)}
                              className="text-red-600 hover:text-red-800"
                            >
                              <Trash2 size={16} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* Journal Entries Tab */}
        {activeTab === "journal-entries" && (
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <h2 className="text-xl font-bold">Journal Entries</h2>
                <button
                  onClick={() => setSectionInfoOpen('journal-entries')}
                  className="p-1 rounded-full text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors"
                  title="What are Journal Entries?"
                >
                  <Info size={16} />
                </button>
              </div>
              <button
                onClick={() => setShowJournalModal(true)}
                className="px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700"
              >
                <Plus size={18} className="inline mr-2" />
                New Entry
              </button>
            </div>
            {loading ? (
              <div className="text-center py-8">Loading...</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full">
                  <thead className="bg-gray-100">
                    <tr>
                      <th className="px-4 py-2 text-left">Entry #</th>
                      <th className="px-4 py-2 text-left">Date</th>
                      <th className="px-4 py-2 text-left">Description</th>
                      <th className="px-4 py-2 text-left">Reference</th>
                      <th className="px-4 py-2 text-right">Amount</th>
                      <th className="px-4 py-2 text-left">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {journalEntries.map((entry) => (
                      <tr key={entry.id} className="border-b">
                        <td className="px-4 py-2">{entry.entry_number}</td>
                        <td className="px-4 py-2">
                          {new Date(entry.entry_date).toLocaleDateString()}
                        </td>
                        <td className="px-4 py-2">{entry.description}</td>
                        <td className="px-4 py-2">
                          {entry.reference_type && entry.reference_id
                            ? `${entry.reference_type} #${entry.reference_id}`
                            : "-"}
                        </td>
                        <td className="px-4 py-2 text-right">₹{entry.total_amount.toFixed(2)}</td>
                        <td className="px-4 py-2">
                          <button
                            onClick={() => {
                              // View entry details
                              alert(`Entry Details:\n${JSON.stringify(entry.lines, null, 2)}`);
                            }}
                            className="text-blue-600 hover:text-blue-800"
                          >
                            View
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* Trial Balance Tab */}
        {activeTab === "trial-balance" && (
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <h2 className="text-xl font-bold">Trial Balance</h2>
                <button
                  onClick={() => setSectionInfoOpen('trial-balance')}
                  className="p-1 rounded-full text-gray-400 hover:text-green-600 hover:bg-green-50 transition-colors"
                  title="What is a Trial Balance?"
                >
                  <Info size={16} />
                </button>
              </div>
              <button
                onClick={fetchTrialBalance}
                className="px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700"
              >
                Refresh
              </button>
            </div>
            {loading ? (
              <div className="text-center py-8">Loading...</div>
            ) : trialBalance ? (
              <div>
                <div className="mb-4 flex items-center space-x-4">
                  <div className="flex items-center space-x-2">
                    {trialBalance.is_balanced ? (
                      <CheckCircle className="text-green-600" size={20} />
                    ) : (
                      <XCircle className="text-red-600" size={20} />
                    )}
                    <span className={`font-semibold ${trialBalance.is_balanced ? "text-green-600" : "text-red-600"}`}>
                      {trialBalance.is_balanced ? "Balanced" : "Not Balanced"}
                    </span>
                  </div>
                  <div className="text-gray-600">
                    Total Debits: ₹{trialBalance.total_debits.toFixed(2)} |
                    Total Credits: ₹{trialBalance.total_credits.toFixed(2)}
                  </div>
                </div>
                <div className="overflow-x-auto">
                  <table className="min-w-full">
                    <thead className="bg-gray-100">
                      <tr>
                        <th className="px-4 py-2 text-left">Ledger Name</th>
                        <th className="px-4 py-2 text-right">Debit Total</th>
                        <th className="px-4 py-2 text-right">Credit Total</th>
                        <th className="px-4 py-2 text-right">Balance</th>
                        <th className="px-4 py-2 text-left">Type</th>
                      </tr>
                    </thead>
                    <tbody>
                      {trialBalance.ledgers.map((ledger) => (
                        <tr key={ledger.ledger_id} className="border-b">
                          <td className="px-4 py-2">{ledger.ledger_name}</td>
                          <td className="px-4 py-2 text-right">₹{ledger.debit_total.toFixed(2)}</td>
                          <td className="px-4 py-2 text-right">₹{ledger.credit_total.toFixed(2)}</td>
                          <td className="px-4 py-2 text-right">
                            ₹{Math.abs(ledger.balance).toFixed(2)}
                            {ledger.balance < 0 && " (Cr)"}
                          </td>
                          <td className="px-4 py-2">{ledger.balance_type}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            ) : (
              <div className="text-center py-8 text-gray-500">No data available</div>
            )}
          </div>
        )}

        {/* Account Group Modal */}
        {showGroupModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 w-full max-w-md">
              <h3 className="text-xl font-bold mb-4">
                {editingGroup ? "Edit" : "Create"} Account Group
              </h3>
              <form onSubmit={handleCreateGroup}>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium mb-1">Name</label>
                    <input
                      type="text"
                      value={groupForm.name}
                      onChange={(e) => setGroupForm({ ...groupForm, name: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Account Type</label>
                    <select
                      value={groupForm.account_type}
                      onChange={(e) => setGroupForm({ ...groupForm, account_type: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                      required
                    >
                      <option value="Revenue">Revenue</option>
                      <option value="Expense">Expense</option>
                      <option value="Asset">Asset</option>
                      <option value="Liability">Liability</option>
                      <option value="Tax">Tax</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Description</label>
                    <textarea
                      value={groupForm.description}
                      onChange={(e) => setGroupForm({ ...groupForm, description: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                      rows="3"
                    />
                  </div>
                </div>
                <div className="mt-6 flex space-x-3">
                  <button
                    type="submit"
                    className="flex-1 px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700"
                  >
                    {editingGroup ? "Update" : "Create"}
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setShowGroupModal(false);
                      setEditingGroup(null);
                    }}
                    className="flex-1 px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Account Ledger Modal */}
        {showLedgerModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
              <h3 className="text-xl font-bold mb-4">
                {editingLedger ? "Edit" : "Create"} Account Ledger
              </h3>
              <form onSubmit={handleCreateLedger}>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium mb-1">Name *</label>
                    <input
                      type="text"
                      value={ledgerForm.name}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, name: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Code</label>
                    <input
                      type="text"
                      value={ledgerForm.code}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, code: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Group *</label>
                    <select
                      value={ledgerForm.group_id}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, group_id: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                      required
                    >
                      <option value="">Select Group</option>
                      {accountGroups.map((group) => (
                        <option key={group.id} value={group.id}>
                          {group.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Module</label>
                    <input
                      type="text"
                      value={ledgerForm.module}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, module: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                      placeholder="e.g., Booking, Purchase"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Opening Balance</label>
                    <input
                      type="number"
                      step="0.01"
                      value={ledgerForm.opening_balance}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, opening_balance: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Balance Type</label>
                    <select
                      value={ledgerForm.balance_type}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, balance_type: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                    >
                      <option value="debit">Debit</option>
                      <option value="credit">Credit</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Tax Type</label>
                    <input
                      type="text"
                      value={ledgerForm.tax_type}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, tax_type: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                      placeholder="e.g., CGST, SGST, IGST"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Tax Rate (%)</label>
                    <input
                      type="number"
                      step="0.01"
                      value={ledgerForm.tax_rate}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, tax_rate: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Bank Name</label>
                    <input
                      type="text"
                      value={ledgerForm.bank_name}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, bank_name: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Account Number</label>
                    <input
                      type="text"
                      value={ledgerForm.account_number}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, account_number: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">IFSC Code</label>
                    <input
                      type="text"
                      value={ledgerForm.ifsc_code}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, ifsc_code: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Branch Name</label>
                    <input
                      type="text"
                      value={ledgerForm.branch_name}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, branch_name: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                    />
                  </div>
                  <div className="col-span-2">
                    <label className="block text-sm font-medium mb-1">Description</label>
                    <textarea
                      value={ledgerForm.description}
                      onChange={(e) => setLedgerForm({ ...ledgerForm, description: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                      rows="3"
                    />
                  </div>
                </div>
                <div className="mt-6 flex space-x-3">
                  <button
                    type="submit"
                    className="flex-1 px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700"
                  >
                    {editingLedger ? "Update" : "Create"}
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setShowLedgerModal(false);
                      setEditingLedger(null);
                    }}
                    className="flex-1 px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Journal Entry Modal */}
        {showJournalModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 w-full max-w-4xl max-h-[90vh] overflow-y-auto">
              <h3 className="text-xl font-bold mb-4">Create Journal Entry</h3>
              <form onSubmit={handleCreateJournalEntry}>
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium mb-1">Entry Date *</label>
                      <input
                        type="date"
                        value={journalForm.entry_date}
                        onChange={(e) => setJournalForm({ ...journalForm, entry_date: e.target.value })}
                        className="w-full border rounded px-3 py-2"
                        required
                      />
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Description *</label>
                    <input
                      type="text"
                      value={journalForm.description}
                      onChange={(e) => setJournalForm({ ...journalForm, description: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Notes</label>
                    <textarea
                      value={journalForm.notes}
                      onChange={(e) => setJournalForm({ ...journalForm, notes: e.target.value })}
                      className="w-full border rounded px-3 py-2"
                      rows="2"
                    />
                  </div>
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <label className="block text-sm font-medium">Journal Entry Lines *</label>
                      <button
                        type="button"
                        onClick={handleAddJournalLine}
                        className="px-3 py-1 bg-indigo-600 text-white rounded text-sm"
                      >
                        <Plus size={14} className="inline mr-1" />
                        Add Line
                      </button>
                    </div>
                    <div className="space-y-2">
                      {journalForm.lines.map((line, index) => (
                        <div key={index} className="grid grid-cols-12 gap-2 items-end border p-3 rounded">
                          <div className="col-span-4">
                            <label className="block text-xs font-medium mb-1">Debit Ledger</label>
                            <select
                              value={line.debit_ledger_id}
                              onChange={(e) => {
                                const newLines = [...journalForm.lines];
                                newLines[index].debit_ledger_id = e.target.value;
                                newLines[index].credit_ledger_id = ""; // Clear credit if debit selected
                                setJournalForm({ ...journalForm, lines: newLines });
                              }}
                              className="w-full border rounded px-2 py-1 text-sm"
                            >
                              <option value="">Select...</option>
                              {accountLedgers.map((ledger) => (
                                <option key={ledger.id} value={ledger.id}>
                                  {ledger.name}
                                </option>
                              ))}
                            </select>
                          </div>
                          <div className="col-span-4">
                            <label className="block text-xs font-medium mb-1">Credit Ledger</label>
                            <select
                              value={line.credit_ledger_id}
                              onChange={(e) => {
                                const newLines = [...journalForm.lines];
                                newLines[index].credit_ledger_id = e.target.value;
                                newLines[index].debit_ledger_id = ""; // Clear debit if credit selected
                                setJournalForm({ ...journalForm, lines: newLines });
                              }}
                              className="w-full border rounded px-2 py-1 text-sm"
                            >
                              <option value="">Select...</option>
                              {accountLedgers.map((ledger) => (
                                <option key={ledger.id} value={ledger.id}>
                                  {ledger.name}
                                </option>
                              ))}
                            </select>
                          </div>
                          <div className="col-span-3">
                            <label className="block text-xs font-medium mb-1">Amount *</label>
                            <input
                              type="number"
                              step="0.01"
                              value={line.amount}
                              onChange={(e) => {
                                const newLines = [...journalForm.lines];
                                newLines[index].amount = e.target.value;
                                setJournalForm({ ...journalForm, lines: newLines });
                              }}
                              className="w-full border rounded px-2 py-1 text-sm"
                              required
                            />
                          </div>
                          <div className="col-span-1">
                            {journalForm.lines.length > 1 && (
                              <button
                                type="button"
                                onClick={() => handleRemoveJournalLine(index)}
                                className="text-red-600 hover:text-red-800"
                              >
                                <Trash2 size={16} />
                              </button>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
                <div className="mt-6 flex space-x-3">
                  <button
                    type="submit"
                    className="flex-1 px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700"
                  >
                    Create Entry
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowJournalModal(false)}
                    className="flex-1 px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
        {/* GST Reports Tab */}
        {activeTab === "gst-reports" && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-bold text-gray-800">GST Reports</h2>
              <span className="text-sm text-gray-500">Click <Info size={14} className="inline" /> to learn about each report</span>
            </div>

            {/* GST Liability Summary Banner */}
            {gstLoading && (
              <div className="bg-gray-50 rounded-lg p-6 text-center text-gray-500">Loading GST summary...</div>
            )}
            {gstSummary && !gstLoading && (
              <div className="bg-gradient-to-r from-indigo-600 to-violet-600 rounded-2xl p-6 text-white shadow-lg">
                <p className="text-sm font-medium opacity-75 mb-3">GST Liability Summary (Current Period)</p>
                <div className="grid grid-cols-3 gap-6">
                  <div className="text-center">
                    <p className="text-xs opacity-70">Output GST</p>
                    <p className="text-2xl font-bold">₹{(gstSummary.total_output_tax || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 })}</p>
                  </div>
                  <div className="text-center">
                    <p className="text-xs opacity-70">Input ITC</p>
                    <p className="text-2xl font-bold">₹{(gstSummary.total_input_tax || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 })}</p>
                  </div>
                  <div className="text-center">
                    <p className="text-xs opacity-70">Net Payable</p>
                    <p className="text-2xl font-bold">₹{((gstSummary.total_output_tax || 0) - (gstSummary.total_input_tax || 0)).toLocaleString('en-IN', { maximumFractionDigits: 0 })}</p>
                  </div>
                </div>
              </div>
            )}

            {/* GST Report Cards with Info Buttons */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {Object.entries(GST_REPORT_INFO).map(([id, info]) => {
                const colors = COLOR_MAP[info.color];
                const isOpen = gstInfoOpen[id];
                const IconComp = info.icon;
                return (
                  <div key={id} className={`bg-white rounded-xl shadow border ${isOpen ? colors.border : 'border-gray-100'} overflow-hidden transition-all`}>
                    {/* Card Header */}
                    <div className="flex items-center gap-3 p-4">
                      <div className={`p-2 rounded-lg ${colors.bg}`}>
                        <IconComp size={20} className={colors.icon} />
                      </div>
                      <div className="flex-1">
                        <h3 className="font-semibold text-gray-800">{info.title}</h3>
                        <span className={`text-xs px-2 py-0.5 rounded-full ${colors.badge}`}>{info.filingRef}</span>
                      </div>
                      <button
                        onClick={() => toggleGstInfo(id)}
                        className={`flex items-center gap-1 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${isOpen ? `${colors.bg} ${colors.text}` : 'bg-gray-50 text-gray-600 hover:bg-gray-100'
                          }`}
                        title={isOpen ? 'Hide info' : 'About this report'}
                      >
                        <Info size={15} />
                        {isOpen ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                      </button>
                    </div>
                    <p className="px-4 pb-3 text-sm text-gray-500">{info.description}</p>

                    {/* Expandable Info Panel */}
                    {isOpen && (
                      <div className={`border-t ${colors.border} ${colors.bg} p-4 space-y-4`}>
                        {/* What it includes */}
                        <div>
                          <p className={`text-xs font-bold uppercase tracking-wider ${colors.text} mb-2`}>What This Report Includes</p>
                          <ul className="space-y-1">
                            {info.includes.map((item, i) => (
                              <li key={i} className="flex items-start gap-2 text-sm text-gray-700">
                                <span className={`mt-1.5 w-1.5 h-1.5 rounded-full flex-shrink-0 ${colors.icon.replace('text-', 'bg-')}`} />
                                {item}
                              </li>
                            ))}
                          </ul>
                        </div>

                        {/* Calculation */}
                        <div className="bg-amber-50 border border-amber-100 rounded-lg p-3">
                          <p className="text-xs font-bold uppercase tracking-wider text-amber-700 mb-1">How It's Calculated</p>
                          <p className="text-sm text-amber-800">{info.calculation}</p>
                        </div>

                        {/* Key fields */}
                        <div>
                          <p className="text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">Key Fields</p>
                          <div className="flex flex-wrap gap-1.5">
                            {info.keyFields.map((f, i) => (
                              <span key={i} className="text-xs bg-white border border-gray-200 text-gray-700 px-2 py-0.5 rounded-full">{f}</span>
                            ))}
                          </div>
                        </div>

                        {/* Filing use */}
                        <div className="bg-green-50 border border-green-100 rounded-lg p-3">
                          <p className="text-xs font-bold uppercase tracking-wider text-green-700 mb-1">📋 Purpose & Filing Use</p>
                          <p className="text-sm text-green-800">{info.use}</p>
                        </div>

                        {/* View report link */}
                        <a
                          href="/report"
                          target="_blank"
                          rel="noreferrer"
                          className={`inline-flex items-center gap-2 text-sm font-semibold ${colors.text} hover:underline`}
                        >
                          <FileText size={14} /> Open Full Report →
                        </a>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        )}

      </div>
    </DashboardLayout>
  );
}


