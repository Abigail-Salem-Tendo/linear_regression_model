import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field, model_validator

from retrain import data_path, model_path, retrain_model

# Same column order as the training data
numeric = ["C031B", "C006"]
categorical = [
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
features = numeric + categorical


def known_codes(model):
    """Category codes the model's one-hot encoder was trained on, per column."""
    ct = model.named_steps["preprocess"]
    ohe = ct.named_transformers_["cat"].named_steps["ohe"]
    cols = next(c for name, _, c in ct.transformers_ if name == "cat")
    return {
        col: sorted(int(v) for v in cats) for col, cats in zip(cols, ohe.categories_)
    }


# Loaded once at startup. /retrain replaces both entries.
model = joblib.load(model_path)
state = {"model": model, "codes": known_codes(model)}

# Ranges come from the training data, so they match what the model has seen
data = pd.read_csv(data_path)
num_min = data[numeric].min().astype(int).to_dict()
num_max = data[numeric].max().astype(int).to_dict()
codes = state["codes"]
example = data[features].mode().iloc[0].astype(int).to_dict()  # most common value per column


def num_field(col, text):
    return Field(
        ...,
        ge=num_min[col],
        le=num_max[col],
        description=f"{text} ({num_min[col]} to {num_max[col]})",
    )


def code_field(col, text):
    return Field(
        ...,
        ge=min(codes[col]),
        le=max(codes[col]),
        description=f"{text}. Allowed codes: {codes[col]}",
    )


app = FastAPI(title="Rwanda Outage Duration API")

# CORS: only these browser origins may call the API (my Render URL and my local
# Flutter web debug server). Wildcard "*" is not used, so other websites can't call
# it from a user's browser. Only GET/POST are allowed (all the routes need), and only
# the Content-Type header (JSON bodies). allow_credentials=False because the API uses
# no cookies or auth. The Flutter mobile app is not a browser, so CORS doesn't affect it.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://rwanda-outage-api.onrender.com",  # deployed API on render
        "http://localhost:5000",  # Flutter web debug (--web-port=5000)
        "http://127.0.0.1:5000",
    ],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
    allow_credentials=False,
)


class OutageInput(BaseModel):
    # strict: "5" (a string) or 5.0 (a float) is rejected, only real integers pass
    model_config = ConfigDict(strict=True, json_schema_extra={"examples": [example]})

    C031B: int = num_field("C031B", "Number of unscheduled outages or blackouts in a typical week")
    C006: int = num_field("C006", "Number of years connected to the national grid")
    DISTRICT: int = code_field("DISTRICT", "District")
    HI04: int = code_field("HI04", "Urban/Rural")
    TYPEHH: int = code_field("TYPEHH", "Type of household")
    C008: int = code_field("C008", "How the household is wired internally to the national grid")
    C012: int = code_field("C012", "Who receives the payment for the electricity service")
    C018: int = code_field("C018", "How the household is billed for electricity")
    C019: int = code_field("C019", "How electricity usage is paid")
    C026: int = code_field("C026", "Is the quality of electricity the same all year")
    C028B: int = code_field("C028B", "Receives information about load shedding in typical months")
    C038: int = code_field("C038", "Is the electric wiring insulated")

    @model_validator(mode="after")
    def check_codes(self):
        # ge/le only checks the range; a code inside the range can still be one
        # the model never saw (e.g. district 20), so check the exact list too
        for col in categorical:
            value = getattr(self, col)
            if value not in state["codes"][col]:
                raise ValueError(
                    f"{col}={value} is not a valid code. Allowed: {state['codes'][col]}"
                )
        return self


@app.get("/")
def home():
    return {"message": "Rwanda Outage Duration API. See /docs"}


@app.post("/predict")
def predict(data: OutageInput):
    row = pd.DataFrame([data.model_dump()])[features]
    prediction = state["model"].predict(row)[0]
    prediction = min(max(float(prediction), 0), 300)  # target was capped at 300 minutes
    return {"predicted_outage_minutes": round(prediction, 1)}


@app.post("/retrain")
def retrain(file: UploadFile = File(...)):
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file")

    try:
        new_model, info = retrain_model(state["model"], file.file.read(), features)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # /predict now uses the new model, no redeploy
    state["model"] = new_model
    state["codes"] = known_codes(new_model)
    return {"message": "Model retrained and now in use", **info}