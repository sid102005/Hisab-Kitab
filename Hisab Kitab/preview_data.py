# preview_data.py
import pandas as pd
import os

# Check both current folder and data folder
data_paths = [
    ".",  # current folder
    "data"  # data folder
]

found_file = None

for path in data_paths:
    if os.path.exists(path):
        files = os.listdir(path)
        csv_files = [f for f in files if f.endswith('.csv')]
        if csv_files:
            found_file = os.path.join(path, csv_files[0])
            break

if found_file:
    print(f"📊 Found CSV file: {found_file}")
    df = pd.read_csv(found_file)
    
    print("\n" + "="*50)
    print("📊 DATA OVERVIEW")
    print("="*50)
    print(f"Total Records: {len(df):,}")
    print(f"\nCOLUMNS IN YOUR DATA:")
    for i, col in enumerate(df.columns, 1):
        print(f"{i}. {col}")
    
    print(f"\nFIRST 5 ROWS:")
    print(df.head())
    
    print(f"\nDATA TYPES:")
    print(df.dtypes)
    
    print(f"\nBASIC STATS:")
    print(df.describe())
    
    # Check for your specific columns
    expected_cols = ['Year', 'Quarter', 'Month', 'State', 'District', 'Ministry', 
                     'Department', 'Scheme_Name', 'Allocated_Budget_Cr']
    
    print("\n" + "="*50)
    print("✅ COLUMN CHECK")
    print("="*50)
    for col in expected_cols:
        if col in df.columns:
            print(f"✓ {col} found")
        else:
            # Try to find similar column names
            similar = [c for c in df.columns if col.lower() in c.lower()]
            if similar:
                print(f"⚠ {col} not found, but found similar: {similar}")
            else:
                print(f"✗ {col} MISSING")
else:
    print("❌ No CSV files found!")
    print("\nLooking in these locations:")
    for path in data_paths:
        full_path = os.path.abspath(path)
        print(f"  • {full_path}")
        if os.path.exists(path):
            print(f"    (folder exists, files: {os.listdir(path) if os.listdir(path) else 'empty'})")