import sys, os
sys.path.insert(0, '/var/www/inventory/ResortApp')
from app.database import SessionLocal
from app.models.inventory import InventoryTransaction, InventoryItem, LaundryLog

db = SessionLocal()
item = db.query(InventoryItem).filter(InventoryItem.name.ilike('%bed sheet%')).first()

print("=== BED SHEET TXNS ===")
txns = db.query(InventoryTransaction).filter(
    InventoryTransaction.item_id == item.id
).order_by(InventoryTransaction.created_at.asc()).all()
for t in txns:
    print(f"#{t.id}")
    print(f"  type={t.transaction_type}")
    print(f"  ref={t.reference_number}")
    print(f"  qty={t.quantity}")
    print(f"  src={t.source_location_id}")
    print(f"  dst={t.destination_location_id}")
    print(f"  notes={t.notes}")
    print(f"  time={t.created_at}")
    print()

print("=== LAUNDRY LOGS ===")
logs = db.query(LaundryLog).order_by(LaundryLog.sent_at.desc()).all()
for l in logs:
    i = db.query(InventoryItem).filter(InventoryItem.id == l.item_id).first()
    print(f"#{l.id}")
    print(f"  item={i.name if i else '?'}")
    print(f"  qty={l.quantity}")
    print(f"  status={l.status}")
    print(f"  src_loc={l.source_location_id}")
    print(f"  room={l.room_number}")
    print(f"  sent={l.sent_at}")
    print(f"  returned={l.returned_at}")
    print()

db.close()
