import io
from pathlib import Path

import joblib
import pandas as pd
from sklearn.base import clone

base_dir = Path(__file__).parent
data_path = base_dir / "model_data.csv"  # training data (original + any retrained rows)
model_path = base_dir / "best_model.pkl"
target = "outage_duration_minutes"


def retrain_model(current_model, csv_bytes, features):
    new_df = pd.read_csv(io.BytesIO(csv_bytes))

    missing = [c for c in features + [target] if c not in new_df.columns]
    if missing:
        raise ValueError(f"CSV is missing columns: {missing}")

    # Same cleaning as the notebook: numbers only, 888 in C038 = "don't know",
    # drop rows without a target, cap the target at 300 minutes
    new_df = new_df[features + [target]].apply(pd.to_numeric, errors="coerce")
    new_df["C038"] = new_df["C038"].replace(888, float("nan"))
    new_df = new_df.dropna(subset=[target])
    new_df[target] = new_df[target].clip(upper=300)
    if new_df.empty:
        raise ValueError("CSV has no usable rows")

    # Random Forest has no partial_fit, so refit on the existing data + new rows
    old_df = pd.read_csv(data_path)[features + [target]]
    all_df = pd.concat([old_df, new_df], ignore_index=True)

    new_model = clone(current_model)  # same pipeline and settings, unfitted
    new_model.fit(all_df[features], all_df[target])

    # Save both so the next retrain builds on this one
    # (on Render's free plan these are lost on restart, which the brief accepts)
    joblib.dump(new_model, model_path)
    all_df.to_csv(data_path, index=False)

    return new_model, {
        "previous_rows": len(old_df),
        "new_rows": len(new_df),
        "total_rows_used": len(all_df),
    }