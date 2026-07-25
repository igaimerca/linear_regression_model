# iTalkSign - Hearing-Loss Risk Regression

**Mission & problem:** iTalkSign builds offline, low-end-device AI for real-time communication for
deaf and hard-of-hearing individuals. This project predicts a person's pure-tone-average hearing
threshold (PTA4, dB HL) from demographic and noise-exposure survey answers, so the app can flag
likely hearing-loss severity without a full audiometric exam.

**Dataset:** NHANES 2015–2016 (CDC/NCHS open data), merging demographics, an audiometry
questionnaire (noise exposure, tinnitus, hearing-aid use), and measured hearing thresholds:
- Demographics: https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2015/DataFiles/DEMO_I.htm
- Audiometry Questionnaire: https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2015/DataFiles/AUQ_I.htm
- Audiometry Exam: https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2015/DataFiles/AUX_I.htm

## Repository layout

```
linear_regression_model/
├── summative/
│   ├── linear_regression/
│   │   ├── multivariate.ipynb      # EDA, feature engineering, model comparison, best-model save
│   │   ├── build_notebook.py       # generates multivariate.ipynb programmatically
│   │   ├── data/                   # raw NHANES XPT files (DEMO_I, AUQ_I, AUX_I)
│   │   ├── best_model.joblib       # best-performing regressor (RandomForestRegressor)
│   │   ├── scaler.joblib, feature_columns.joblib
│   │   └── *.png                   # saved plots
│   ├── API/
│   │   ├── main.py                 # FastAPI app: /predict, /retrain, CORS, Pydantic validation
│   │   ├── prediction.py           # loads model, builds feature vector, predicts
│   │   ├── requirements.txt
│   │   └── Procfile
│   └── FlutterApp/                 # single-page Flutter app (hearing_predictor)
├── pyproject.toml / uv.lock
└── README.md
```

## Live links

- **API (Swagger UI):** `<PASTE-YOUR-RENDER-URL>/docs` - update after deploying to Render.
- **YouTube demo video (≤7 min):** `<PASTE-YOUR-YOUTUBE-LINK>`

## Running the notebook / retraining locally

```bash
cd linear_regression_model
uv sync
uv run jupyter nbconvert --to notebook --execute --inplace summative/linear_regression/multivariate.ipynb
```

## Running the API locally

```bash
cd linear_regression_model/summative/API
uv run --project ../.. uvicorn main:app --reload
# Swagger UI at http://127.0.0.1:8000/docs
```

### Deploying to Render

1. Push this repo to GitHub.
2. On Render: New → Web Service → connect the repo.
3. Root directory: `summative/API`.
4. Build command: `pip install -r requirements.txt`.
5. Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`.
6. Once live, Swagger UI is at `https://<your-service>.onrender.com/docs`.

## Running the Flutter app

```bash
cd linear_regression_model/summative/FlutterApp
flutter pub get
```

Before running, open `lib/main.dart` and set `kApiBaseUrl` to your deployed Render URL (or
`http://10.0.2.2:8000` for the Android emulator / `http://127.0.0.1:8000` for iOS
simulator/desktop, if the API is running locally). Then:

```bash
flutter run            # pick your connected device/simulator
```

The app is a single page: enter the 13 input values (dropdowns for categorical fields, text
fields for age and income-to-poverty ratio), tap **Predict**, and the predicted hearing threshold
(dB HL) and severity band are shown, or a validation/error message if a value is out of range or
missing.

## CORS configuration rationale

The API restricts `allow_origins` to explicit local/dev origins (no `allow_origins=["*"]`), since
one of the two POST endpoints (`/retrain`) mutates the deployed model and should not be reachable
from arbitrary third-party web origins. Native Flutter mobile builds don't send a browser `Origin`
header so they're unaffected; the origin list only matters for a Flutter web build or
browser-based Swagger testing. `allow_methods` is limited to `GET`/`POST` (all this API
implements) and `allow_headers` to `Content-Type`; `allow_credentials` is left off since the API
uses no cookies/auth headers that need cross-origin exposure.
