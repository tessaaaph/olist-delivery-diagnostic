import pandas as pd
import sqlite3
from pathlib import Path

# --- Paths ---
DATA_FOLDER = Path("data")
DB_PATH = Path("olist.db")

# --- Connect ---
conn = sqlite3.connect(DB_PATH)

# --- Load each CSV as its own table ---
csv_files = sorted(DATA_FOLDER.glob("*.csv"))
for csv_file in csv_files:
    # Strip "olist_" prefix and "_dataset" suffix for cleaner table names
    table_name = csv_file.stem.replace("olist_", "").replace("_dataset", "")
    print(f"Loading {table_name}...")
    df = pd.read_csv(csv_file)
    df.to_sql(table_name, conn, if_exists="replace", index=False)
    print(f"  -> {len(df):,} rows, {len(df.columns)} cols")

conn.close()
print("\nDatabase built.")