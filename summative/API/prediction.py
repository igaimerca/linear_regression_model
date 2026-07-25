"""Loads the best-performing hearing-threshold regression model and exposes a
single prediction function used by the FastAPI app in main.py."""
from pathlib import Path

import joblib
import pandas as pd

MODEL_DIR = Path(__file__).resolve().parent.parent / "linear_regression"

NUMERIC_FEATURES = [
    "RIDAGEYR", "INDFMPIR", "AUQ054", "AUQ191",
    "AUQ300", "AUQ320", "AUQ331", "AUQ350", "AUQ370",
]
# category -> the one-hot values pd.get_dummies(drop_first=True) produced during training
CATEGORICAL_FEATURES = {
    "RIAGENDR": [1.0, 2.0],
    "RIDRETH3": [1.0, 2.0, 3.0, 4.0, 6.0, 7.0],
    "DMDEDUC2": [1.0, 2.0, 3.0, 4.0, 5.0],
    "DMDMARTL": [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
}


def _load_artifacts():
    model = joblib.load(MODEL_DIR / "best_model.joblib")
    scaler = joblib.load(MODEL_DIR / "scaler.joblib")
    feature_columns = joblib.load(MODEL_DIR / "feature_columns.joblib")
    return model, scaler, feature_columns


model, scaler, feature_columns = _load_artifacts()


def reload_artifacts():
    """Re-reads the model/scaler/feature_columns from disk (used after retraining)."""
    global model, scaler, feature_columns
    model, scaler, feature_columns = _load_artifacts()


def build_feature_vector(payload: dict) -> pd.DataFrame:
    row = {col: 0 for col in feature_columns}
    for feat in NUMERIC_FEATURES:
        row[feat] = payload[feat]
    for feat, categories in CATEGORICAL_FEATURES.items():
        dummy_col = f"{feat}_{float(payload[feat])}"
        if dummy_col in row:
            row[dummy_col] = True
    return pd.DataFrame([row], columns=feature_columns)


def predict_hearing_threshold(payload: dict) -> float:
    """payload keys must match NUMERIC_FEATURES + CATEGORICAL_FEATURES."""
    X = build_feature_vector(payload)
    X_scaled = scaler.transform(X)
    return float(model.predict(X_scaled)[0])


if __name__ == "__main__":
    sample = {
        "RIDAGEYR": 45, "INDFMPIR": 2.5, "AUQ054": 1, "AUQ191": 2, "AUQ300": 2,
        "AUQ320": 0, "AUQ331": 2, "AUQ350": 0, "AUQ370": 2,
        "RIAGENDR": 1, "RIDRETH3": 3, "DMDEDUC2": 4, "DMDMARTL": 1,
    }
    print(f"Predicted PTA4 hearing threshold: {predict_hearing_threshold(sample):.2f} dB HL")
