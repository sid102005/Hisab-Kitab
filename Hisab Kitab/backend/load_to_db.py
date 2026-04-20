# load_to_db.py
import pandas as pd
import sqlite3
import os

print("🚀 Loading Indian Budget Data to Database...")
print("="*50)

# Look for CSV in multiple locations
possible_paths = [
    'india_govt_fund_allocation.csv',           # current folder
    os.path.join('..', 'data', 'india_govt_fund_allocation.csv'),  # ../data/
    os.path.join('..', 'india_govt_fund_allocation.csv'),          # parent folder
]

csv_file = None
for path in possible_paths:
    if os.path.exists(path):
        csv_file = path
        print(f"✅ Found CSV at: {path}")
        break

if csv_file is None:
    print("❌ Error: Could not find CSV file!")
    print("Searched in:")
    for path in possible_paths:
        print(f"  - {os.path.abspath(path)}")
    exit(1)

# Load CSV
print(f"📂 Reading CSV...")
df = pd.read_csv(csv_file)
print(f"✅ Loaded {len(df):,} records")

# Clean column names
df.columns = df.columns.str.strip().str.replace(' ', '_').str.replace('(', '').str.replace(')', '')
print(f"✅ Cleaned column names")

# Connect to SQLite
db_path = 'budget_india.db'
conn = sqlite3.connect(db_path)
print(f"✅ Connected to database: {db_path}")

# Save to database
print(f"💾 Writing to database...")
df.to_sql('budget', conn, if_exists='replace', index=False)

# Create indexes
print(f"🔨 Creating indexes...")
indexes = [
    'CREATE INDEX IF NOT EXISTS idx_state ON budget(State)',
    'CREATE INDEX IF NOT EXISTS idx_district ON budget(District)',
    'CREATE INDEX IF NOT EXISTS idx_ministry ON budget(Ministry)',
    'CREATE INDEX IF NOT EXISTS idx_department ON budget(Department)',
    'CREATE INDEX IF NOT EXISTS idx_year ON budget(Year)',
    'CREATE INDEX IF NOT EXISTS idx_utilization ON budget(Utilization_Percentage)',
]

for idx in indexes:
    conn.execute(idx)

conn.commit()

# Verify
count = conn.execute("SELECT COUNT(*) FROM budget").fetchone()[0]
print(f"\n✅ Database ready with {count:,} records")

# Show sample stats
stats = conn.execute("""
    SELECT 
        COUNT(DISTINCT State) as states,
        COUNT(DISTINCT District) as districts,
        COUNT(DISTINCT Ministry) as ministries,
        MIN(Year) as min_year,
        MAX(Year) as max_year,
        SUM(Allocated_Budget_Cr) as total_budget
    FROM budget
""").fetchone()

print(f"\n📊 DATA SUMMARY")
print(f"States: {stats[0]}, Districts: {stats[1]}")
print(f"Ministries: {stats[2]}")
print(f"Years: {stats[3]}-{stats[4]}")
print(f"Total Budget: ₹{stats[5]:,.2f} Cr")

conn.close()
print(f"\n✅ Database saved to: {os.path.abspath(db_path)}")