import io
from pathlib import Path

import joblib
import pandas as pd
from sklearn.base import clone

BASE_DIR = Path(__file__).parent
DATA_PATH = BASE_DIR / "model_data.csv"  # original training data
MODEL_PATH = BASE_DIR / "best_model.pkl"
TARGET = "outage_duration_minutes"


def retrain_model(current_model, csv_bytes, features):
    new_df = pd.read_csv(io.BytesIO(csv_bytes))

    missing = [c for c in features + [TARGET] if c not in new_df.columns]
    if missing:
        raise ValueError(f"CSV is missing columns: {missing}")

    # Same cleaning as training: numbers only, drop rows without a target, cap at 300
    new_df = new_df[features + [TARGET]].apply(pd.to_numeric, errors="coerce")
    new_df = new_df.dropna(subset=[TARGET])
    new_df[TARGET] = new_df[TARGET].clip(upper=300)
    if new_df.empty:
        raise ValueError("CSV has no usable rows")

    # Random Forest has no partial_fit, so refit on original data + new rows
    old_df = pd.read_csv(DATA_PATH)[features + [TARGET]]
    all_df = pd.concat([old_df, new_df], ignore_index=True)

    new_model = clone(current_model)  # same settings, unfitted
    new_model.fit(all_df[features], all_df[TARGET])
    joblib.dump(new_model, MODEL_PATH)

    return new_model, {
        "original_rows": len(old_df),
        "new_rows": len(new_df),
        "total_rows_used": len(all_df),
    }
