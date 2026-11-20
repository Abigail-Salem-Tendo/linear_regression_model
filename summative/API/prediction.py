from pathlib import Path
import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from pydantic import BaseModel, Field
from retrain import retrain_model
from fastapi.middleware.cors import CORSMiddleware

BASE_DIR = Path(__file__).parent
MODEL_PATH = BASE_DIR / "best_model.pkl"

# Same column order as the training data
FEATURES = [
    "C031B",
    "C006",
    "DISTRICT",
    "HI04",
    "TYPEHH",
    "C008",
    "C012",
    "C018",
    "C019",
    "C026",
    "C028B",
    "C038",
]

app = FastAPI(title="Rwanda Outage Duration API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://YOUR-SERVICE.onrender.com",   # replace after deploying on Render
        "http://localhost:5000",               # Flutter web debug (--web-port=5000)
        "http://127.0.0.1:5000",
    ],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
    allow_credentials=False,
)

# Loaded once at startup. /retrain will replace state["model"].
state = {"model": joblib.load(MODEL_PATH)}


class OutageInput(BaseModel):
    C031B: int = Field(
        ..., ge=1, le=30, description="Number of outages in a typical week"
    )
    C006: int = Field(..., ge=0, le=60, description="Years connected to the grid")
    DISTRICT: int = Field(..., ge=11, le=57, description="District code")
    HI04: int = Field(..., ge=1, le=2, description="Household survey code (1 or 2)")
    TYPEHH: int = Field(..., ge=1, le=3, description="Household type code")
    C008: int = Field(..., ge=1, le=3, description="C008 survey code")
    C012: int = Field(..., ge=1, le=555, description="C012 survey code")
    C018: int = Field(..., ge=1, le=555, description="C018 survey code")
    C019: int = Field(
        ..., ge=1, le=555, description="How electricity usage is paid (code)"
    )
    C026: int = Field(..., ge=1, le=2, description="C026 survey code (1 or 2)")
    C028B: int = Field(..., ge=0, le=1, description="C028B (0 or 1)")
    C038: int = Field(..., ge=0, le=1, description="Wiring insulated (0 or 1)")


@app.post("/predict")
def predict(data: OutageInput):
    row = pd.DataFrame([data.model_dump()])[FEATURES]
    prediction = state["model"].predict(row)[0]
    prediction = min(max(float(prediction), 0), 300)  # target was capped at 300 minutes
    return {"predicted_outage_minutes": round(prediction, 1)}


@app.post("/retrain")
async def retrain(file: UploadFile = File(...)):
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file")

    contents = await file.read()
    try:
        new_model, info = retrain_model(state["model"], contents, FEATURES)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    state["model"] = new_model  # /predict now uses the new model, no redeploy
    return {"message": "Model retrained and now in use", **info}
