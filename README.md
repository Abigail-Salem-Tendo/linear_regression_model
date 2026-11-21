# Rwanda Electricity Outage Duration Prediction

## Mission and problem
My mission is to improve access to reliable electricity in Africa. Grid-connected households in Rwanda still face unscheduled outages, and providers lack a quick way to see which households are likely to face long interruptions.
This project predicts the total outage time a grid-connected household experiences in a typical week, so electricity providers can prioritise maintenance and plan better for those households.


## Dataset
**Rwanda Multi-Tier Framework (MTF) Energy Survey, 2022**, Section C1 (`SECTION_C1.csv`): 5,706 households and 280 columns on grid connection, outages, billing, wiring and location. The model uses the 1,782 grid-connected households that report their outage duration, with 12 features (2 numeric, 10 categorical) and the target `outage_duration_minutes`.
Source: https://microdata.worldbank.org/catalog/6429/data-dictionary/F11?file_name=SECTION_C1

## API (Swagger UI)
https://rwanda-outage-api.onrender.com/docs

- `POST /predict`: takes the 12 inputs and returns the predicted outage minutes
- `POST /retrain`: upload a CSV with the same columns to retrain the model and use it straight away

The free Render service sleeps when idle, so the first request can take up to a minute.

## Video demo
https://www.youtube.com/watch?v=hxE4ijyayyI

## Running the mobile app
1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) and Android Studio, and create an Android emulator (or connect an Android phone with USB debugging on).
2. Clone the repository:
   ```bash
   git clone https://github.com/Abigail-Salem-Tendo/linear_regression_model.git
   cd linear_regression_model/summative/FlutterApp
   ```
3. Install the packages:
   ```bash
   flutter pub get
   ```
4. Start the emulator, then run the app:
   ```bash
   flutter run
   ```
5. Fill in all 12 fields using the allowed values shown under each one, then tap **Predict**. The app calls the deployed API set in `lib/api_service.dart`.

## Repository Structure
- ``summative/linear_regression/multivariate.ipynb``: model training notebook
- ``summative/API``: FastAPI service (``prediction.py``, ``requirements.txt``, ``best_model.pkl``)
- ``summative/FlutterApp/``: Flutter mobile app

## Running the API and notebook locally (optional)
Requires [uv](https://docs.astral.sh/uv/).
```bash
# API
cd summative/API
uv sync
uv run uvicorn prediction:app --reload      

# then open http://127.0.0.1:8000/docs

# Notebook
cd summative
uv sync
uv run jupyter notebook linear_regression/multivariate.ipynb
```