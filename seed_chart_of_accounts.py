"""
Seed default Chart of Accounts for Orchid Resort.
Standard accounting structure for a hospitality business.
"""
import sys, os

# Support both local Windows dev and remote Linux server
_script_dir = os.path.dirname(os.path.abspath(__file__))
# seed_chart_of_accounts.py lives in: New Orchid/ (alongside ResortApp/)
# or on server in /var/www/inventory/
_local_resortapp = os.path.join(_script_dir, 'ResortApp')
if os.path.isdir(_local_resortapp):
    sys.path.insert(0, _local_resortapp)
else:
    sys.path.insert(0, '/var/www/inventory/ResortApp')

# Load .env from ResortApp directory
from dotenv import load_dotenv
_env_path = os.path.join(_local_resortapp if os.path.isdir(_local_resortapp) else '/var/www/inventory/ResortApp', '.env')
load_dotenv(_env_path)

from app.database import SessionLocal
from app.models.account import AccountGroup, AccountLedger

db = SessionLocal()

# Standard chart of accounts for hospitality
ACCOUNT_GROUPS = [
    # Assets
    {"name": "Current Assets", "account_type": "Asset", "description": "Short-term assets"},
    {"name": "Fixed Assets", "account_type": "Asset", "description": "Long-term assets"},
    {"name": "Cash & Bank", "account_type": "Asset", "description": "Cash and bank accounts"},
    # Liabilities
    {"name": "Current Liabilities", "account_type": "Liability", "description": "Short-term obligations"},
    {"name": "Long-term Liabilities", "account_type": "Liability", "description": "Long-term obligations"},
    {"name": "GST Payable", "account_type": "Liability", "description": "GST tax liabilities"},
    # Revenue
    {"name": "Room Revenue", "account_type": "Revenue", "description": "Income from room bookings"},
    {"name": "F&B Revenue", "account_type": "Revenue", "description": "Food and beverage income"},
    {"name": "Service Revenue", "account_type": "Revenue", "description": "Income from services"},
    {"name": "Other Income", "account_type": "Revenue", "description": "Miscellaneous income"},
    # Expenses
    {"name": "Staff Expenses", "account_type": "Expense", "description": "Salaries and staff costs"},
    {"name": "Operational Expenses", "account_type": "Expense", "description": "Day-to-day operating costs"},
    {"name": "Utility Expenses", "account_type": "Expense", "description": "Electricity, water, etc."},
    {"name": "Maintenance Expenses", "account_type": "Expense", "description": "Repairs and maintenance"},
    {"name": "Marketing Expenses", "account_type": "Expense", "description": "Advertising and promotions"},
    # Tax
    {"name": "GST Receivable (ITC)", "account_type": "Tax", "description": "Input tax credit accounts"},
    {"name": "Tax Payable", "account_type": "Tax", "description": "Tax liabilities"},
]

# Check if already seeded
existing = db.query(AccountGroup).count()
if existing > 0:
    print(f"Already have {existing} account groups. Skipping seed.")
    db.close()
    sys.exit(0)

# Create groups
group_map = {}
for g in ACCOUNT_GROUPS:
    grp = AccountGroup(**g)
    db.add(grp)
    db.flush()
    group_map[g["name"]] = grp.id

db.commit()
print(f"Created {len(ACCOUNT_GROUPS)} account groups")

# Now seed ledgers
def gid(name):
    return group_map[name]

LEDGERS = [
    # Cash & Bank
    {"name": "Cash in Hand", "code": "1001", "group_id": gid("Cash & Bank"), "module": "General", "balance_type": "debit", "opening_balance": 0},
    {"name": "Bank Account - Main", "code": "1002", "group_id": gid("Cash & Bank"), "module": "General", "balance_type": "debit", "opening_balance": 0},
    {"name": "Petty Cash", "code": "1003", "group_id": gid("Cash & Bank"), "module": "General", "balance_type": "debit", "opening_balance": 0},
    # Current Assets
    {"name": "Accounts Receivable", "code": "1101", "group_id": gid("Current Assets"), "module": "Booking", "balance_type": "debit", "opening_balance": 0},
    {"name": "Advance Deposits - Guests", "code": "1102", "group_id": gid("Current Assets"), "module": "Booking", "balance_type": "debit", "opening_balance": 0},
    {"name": "Inventory Stock", "code": "1103", "group_id": gid("Current Assets"), "module": "Inventory", "balance_type": "debit", "opening_balance": 0},
    {"name": "Prepaid Expenses", "code": "1104", "group_id": gid("Current Assets"), "module": "General", "balance_type": "debit", "opening_balance": 0},
    # Fixed Assets
    {"name": "Furniture & Fixtures", "code": "1201", "group_id": gid("Fixed Assets"), "module": "General", "balance_type": "debit", "opening_balance": 0},
    {"name": "Equipment", "code": "1202", "group_id": gid("Fixed Assets"), "module": "General", "balance_type": "debit", "opening_balance": 0},
    {"name": "Building", "code": "1203", "group_id": gid("Fixed Assets"), "module": "General", "balance_type": "debit", "opening_balance": 0},
    # Current Liabilities
    {"name": "Accounts Payable", "code": "2001", "group_id": gid("Current Liabilities"), "module": "Purchase", "balance_type": "credit", "opening_balance": 0},
    {"name": "Advance from Guests", "code": "2002", "group_id": gid("Current Liabilities"), "module": "Booking", "balance_type": "credit", "opening_balance": 0},
    {"name": "Salaries Payable", "code": "2003", "group_id": gid("Current Liabilities"), "module": "Employee", "balance_type": "credit", "opening_balance": 0},
    # GST Payable
    {"name": "CGST Payable", "code": "2101", "group_id": gid("GST Payable"), "module": "GST", "tax_type": "CGST", "balance_type": "credit", "opening_balance": 0},
    {"name": "SGST Payable", "code": "2102", "group_id": gid("GST Payable"), "module": "GST", "tax_type": "SGST", "balance_type": "credit", "opening_balance": 0},
    {"name": "IGST Payable", "code": "2103", "group_id": gid("GST Payable"), "module": "GST", "tax_type": "IGST", "balance_type": "credit", "opening_balance": 0},
    # Revenue
    {"name": "Room Tariff Income", "code": "4001", "group_id": gid("Room Revenue"), "module": "Booking", "balance_type": "credit", "opening_balance": 0},
    {"name": "Package Revenue", "code": "4002", "group_id": gid("Room Revenue"), "module": "Booking", "balance_type": "credit", "opening_balance": 0},
    {"name": "Early Check-in / Late Check-out", "code": "4003", "group_id": gid("Room Revenue"), "module": "Booking", "balance_type": "credit", "opening_balance": 0},
    {"name": "Restaurant Revenue", "code": "4101", "group_id": gid("F&B Revenue"), "module": "Food", "balance_type": "credit", "opening_balance": 0},
    {"name": "Bar Revenue", "code": "4102", "group_id": gid("F&B Revenue"), "module": "Food", "balance_type": "credit", "opening_balance": 0},
    {"name": "Laundry Revenue", "code": "4201", "group_id": gid("Service Revenue"), "module": "Service", "balance_type": "credit", "opening_balance": 0},
    {"name": "Spa & Wellness Revenue", "code": "4202", "group_id": gid("Service Revenue"), "module": "Service", "balance_type": "credit", "opening_balance": 0},
    {"name": "Event Revenue", "code": "4203", "group_id": gid("Service Revenue"), "module": "Service", "balance_type": "credit", "opening_balance": 0},
    {"name": "Miscellaneous Income", "code": "4301", "group_id": gid("Other Income"), "module": "General", "balance_type": "credit", "opening_balance": 0},
    {"name": "Cancellation Charges", "code": "4302", "group_id": gid("Other Income"), "module": "Booking", "balance_type": "credit", "opening_balance": 0},
    # Expenses
    {"name": "Salaries & Wages", "code": "5001", "group_id": gid("Staff Expenses"), "module": "Employee", "balance_type": "debit", "opening_balance": 0},
    {"name": "Staff Benefits", "code": "5002", "group_id": gid("Staff Expenses"), "module": "Employee", "balance_type": "debit", "opening_balance": 0},
    {"name": "Food & Beverage Purchases", "code": "5101", "group_id": gid("Operational Expenses"), "module": "Purchase", "balance_type": "debit", "opening_balance": 0},
    {"name": "Housekeeping Supplies", "code": "5102", "group_id": gid("Operational Expenses"), "module": "Inventory", "balance_type": "debit", "opening_balance": 0},
    {"name": "Laundry Costs", "code": "5103", "group_id": gid("Operational Expenses"), "module": "Service", "balance_type": "debit", "opening_balance": 0},
    {"name": "Electricity", "code": "5201", "group_id": gid("Utility Expenses"), "module": "Expense", "balance_type": "debit", "opening_balance": 0},
    {"name": "Water", "code": "5202", "group_id": gid("Utility Expenses"), "module": "Expense", "balance_type": "debit", "opening_balance": 0},
    {"name": "Internet & Communications", "code": "5203", "group_id": gid("Utility Expenses"), "module": "Expense", "balance_type": "debit", "opening_balance": 0},
    {"name": "Building Maintenance", "code": "5301", "group_id": gid("Maintenance Expenses"), "module": "Expense", "balance_type": "debit", "opening_balance": 0},
    {"name": "Equipment Maintenance", "code": "5302", "group_id": gid("Maintenance Expenses"), "module": "Expense", "balance_type": "debit", "opening_balance": 0},
    {"name": "Advertising", "code": "5401", "group_id": gid("Marketing Expenses"), "module": "Expense", "balance_type": "debit", "opening_balance": 0},
    {"name": "Online Travel Agent Commissions", "code": "5402", "group_id": gid("Marketing Expenses"), "module": "Expense", "balance_type": "debit", "opening_balance": 0},
    # GST ITC
    {"name": "CGST Input Credit", "code": "6001", "group_id": gid("GST Receivable (ITC)"), "module": "GST", "tax_type": "CGST", "balance_type": "debit", "opening_balance": 0},
    {"name": "SGST Input Credit", "code": "6002", "group_id": gid("GST Receivable (ITC)"), "module": "GST", "tax_type": "SGST", "balance_type": "debit", "opening_balance": 0},
    {"name": "IGST Input Credit", "code": "6003", "group_id": gid("GST Receivable (ITC)"), "module": "GST", "tax_type": "IGST", "balance_type": "debit", "opening_balance": 0},
]

count = 0
for l in LEDGERS:
    ledger = AccountLedger(**l)
    db.add(ledger)
    count += 1

db.commit()
print(f"Created {count} account ledgers")
print("Chart of Accounts seeded successfully!")
db.close()
