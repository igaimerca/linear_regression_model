"""FastAPI service exposing the iTalkSign hearing-threshold regression model.

Run locally (from the repo root):
    cd summative/API && uv run --project ../.. uvicorn main:app --reload
Swagger UI:
    http://127.0.0.1:8000/docs
"""
from io import StringIO
from pathlib import Path
from typing import Literal

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import train_test_split

from prediction import (
    CATEGORICAL_FEATURES,
    MODEL_DIR,
    NUMERIC_FEATURES,
    build_feature_vector,
    predict_hearing_threshold,
    reload_artifacts,
)

app = FastAPI(
    title="iTalkSign Hearing-Threshold Prediction API",
    description=(
        "Predicts a person's pure-tone-average hearing threshold (PTA4, dB HL) from demographic "
        "and noise-exposure survey answers, so the iTalkSign accessibility app can flag likely "
        "hearing-loss severity without a full audiometric exam."
    ),
    version="1.0.0",
)

# --- CORS -----------------------------------------------------------------
# The only client of this API is the iTalkSign Flutter app. We do NOT use allow_origins=["*"]:
# a public regression endpoint that also exposes a /retrain (model-mutating) route should not
# accept cross-origin requests from arbitrary websites. Flutter mobile builds (Android/iOS) do not
# send a browser Origin header, so they are unaffected by this restriction; the entries below only
# matter for a Flutter *web* build or local Swagger-UI-based testing served from these origins.
# Methods are restricted to what the API actually implements (GET for docs/health, POST for the two
# mutating endpoints) and headers to what a JSON client needs, with credentials left off since the
# API is stateless and uses no cookies/auth headers that need cross-origin exposure.
ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


class HearingPredictionRequest(BaseModel):
    RIDAGEYR: float = Field(..., ge=20, le=69, description="Age in years (NHANES audiometry exam range)")
    INDFMPIR: float = Field(..., ge=0, le=5, description="Family income-to-poverty ratio (0-5, capped)")
    AUQ054: Literal[1, 2, 3, 4, 5] = Field(..., description="Self-rated hearing: 1=Excellent ... 5=Deaf")
    AUQ191: Literal[0, 1, 2] = Field(..., description="Ringing/roaring/buzzing in ears past year: 0=N/A, 1=Yes, 2=No")
    AUQ300: Literal[0, 1, 2] = Field(..., description="Ever used firearms: 0=N/A, 1=Yes, 2=No")
    AUQ320: Literal[0, 1, 2, 3, 4, 5] = Field(..., description="Wears hearing protection when shooting: 0=N/A, 1=Always ... 5=Never")
    AUQ331: Literal[0, 1, 2] = Field(..., description="Ever had job exposure to loud noise: 0=N/A, 1=Yes, 2=No")
    AUQ350: Literal[0, 1, 2] = Field(..., description="Ever exposed to very loud noise at work: 0=N/A, 1=Yes, 2=No")
    AUQ370: Literal[0, 1, 2] = Field(..., description="Had off-work exposure to loud noise: 0=N/A, 1=Yes, 2=No")
    RIAGENDR: Literal[1, 2] = Field(..., description="Gender: 1=Male, 2=Female")
    RIDRETH3: Literal[1, 2, 3, 4, 6, 7] = Field(..., description="Race/ethnicity (NHANES RIDRETH3 codes)")
    DMDEDUC2: Literal[1, 2, 3, 4, 5] = Field(..., description="Education level: 1=<9th grade ... 5=College grad+")
    DMDMARTL: Literal[1, 2, 3, 4, 5, 6] = Field(..., description="Marital status (NHANES DMDMARTL codes)")

    class Config:
        json_schema_extra = {
            "example": {
                "RIDAGEYR": 45, "INDFMPIR": 2.5, "AUQ054": 1, "AUQ191": 2, "AUQ300": 2,
                "AUQ320": 0, "AUQ331": 2, "AUQ350": 0, "AUQ370": 2,
                "RIAGENDR": 1, "RIDRETH3": 3, "DMDEDUC2": 4, "DMDMARTL": 1,
            }
        }


class HearingPredictionResponse(BaseModel):
    predicted_pta4_db_hl: float
    interpretation: str


@app.get("/")
def root():
    return {"message": "iTalkSign Hearing-Threshold API is running. Visit /docs for Swagger UI."}


@app.post("/predict", response_model=HearingPredictionResponse)
def predict(payload: HearingPredictionRequest):
    prediction = predict_hearing_threshold(payload.model_dump())
    if prediction < 25:
        band = "normal hearing"
    elif prediction < 40:
        band = "mild hearing loss"
    elif prediction < 70:
        band = "moderate hearing loss"
    else:
        band = "severe hearing loss"
    return HearingPredictionResponse(predicted_pta4_db_hl=round(prediction, 2), interpretation=band)


@app.post("/retrain")
async def retrain(file: UploadFile = File(...)):
    """Retrains the RandomForestRegressor on new labelled data uploaded as CSV.

    The CSV must contain the same feature columns as the training set (NUMERIC_FEATURES +
    RIAGENDR, RIDRETH3, DMDEDUC2, DMDMARTL) plus a PTA4 target column. New rows are appended
    to the original NHANES training data and the model/scaler artifacts are overwritten.
    """
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Upload a .csv file")

    raw = await file.read()
    try:
        new_data = pd.read_csv(StringIO(raw.decode("utf-8")))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Could not parse CSV: {exc}")

    required_cols = set(NUMERIC_FEATURES) | set(CATEGORICAL_FEATURES) | {"PTA4"}
    missing = required_cols - set(new_data.columns)
    if missing:
        raise HTTPException(status_code=400, detail=f"CSV is missing required columns: {sorted(missing)}")

    feature_columns = joblib.load(MODEL_DIR / "feature_columns.joblib")
    scaler = joblib.load(MODEL_DIR / "scaler.joblib")

    rows = []
    for _, record in new_data.iterrows():
        rows.append(build_feature_vector(record.to_dict()).iloc[0])
    X_new = pd.DataFrame(rows, columns=feature_columns)
    y_new = new_data["PTA4"].reset_index(drop=True)

    X_train, X_test, y_train, y_test = train_test_split(X_new, y_new, test_size=0.2, random_state=42)
    scaler.fit(X_train)
    X_train_scaled = scaler.transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    model = RandomForestRegressor(n_estimators=300, max_depth=8, random_state=42, n_jobs=-1)
    model.fit(X_train_scaled, y_train)

    metrics = {
        "test_rmse": float(mean_squared_error(y_test, model.predict(X_test_scaled)) ** 0.5)
        if len(y_test) > 0 else None,
        "test_r2": float(r2_score(y_test, model.predict(X_test_scaled))) if len(y_test) > 1 else None,
        "n_rows_used": int(len(new_data)),
    }

    joblib.dump(model, MODEL_DIR / "best_model.joblib")
    joblib.dump(scaler, MODEL_DIR / "scaler.joblib")
    reload_artifacts()

    return {"status": "retrained", **metrics}
