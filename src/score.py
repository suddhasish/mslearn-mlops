import os
import io
import json
import logging
import traceback

import numpy as np

# Prefer joblib for sklearn models, fall back to pickle
try:
    import joblib as _joblib
except Exception:
    import pickle as _joblib

# Global model variable populated in init()
MODEL = None
MODEL_FILENAME_ENV = "AZUREML_MODEL_FILE"  # optional env var to point to model file
DEFAULT_MODEL_FILENAME = "model.pkl"       # default name inside the deployment container

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def _load_model_from_path(path):
    """
    Load a model object from a file path using joblib/pickle.
    """
    try:
        logger.info("Loading model from path: %s", path)
        # joblib.load for sklearn pipelines, pickle.load as fallback
        if hasattr(_joblib, "load"):
            model = _joblib.load(path)
        else:
            with open(path, "rb") as f:
                model = _joblib.load(f)
        logger.info("Model loaded successfully.")
        return model
    except Exception:
        logger.error("Failed loading model: %s", traceback.format_exc())
        raise


def init():
    """
    Called once when the deployment container starts.
    Responsible for loading the model into the global MODEL variable.
    """
    global MODEL

    try:
        # Determine model file path
        model_path = os.getenv(MODEL_FILENAME_ENV, DEFAULT_MODEL_FILENAME)

        # If the path is not absolute, try to resolve common locations
        if not os.path.isabs(model_path):
            # Azure ML often places the model files in the local working directory.
            candidate_paths = [
                model_path,
                os.path.join(os.getcwd(), model_path),
                os.path.join("/var/azureml-app", model_path),
                os.path.join("/tmp", model_path),
            ]
        else:
            candidate_paths = [model_path]

        found = False
        for p in candidate_paths:
            if p and os.path.exists(p):
                MODEL = _load_model_from_path(p)
                found = True
                break

        if not found:
            # If not found, try to load first file with .pkl, .joblib, or .model extension in cwd
            for fname in os.listdir(os.getcwd()):
                if fname.endswith((".pkl", ".joblib", ".model", ".sav")):
                    MODEL = _load_model_from_path(os.path.join(os.getcwd(), fname))
                    found = True
                    logger.warning("Model file auto-detected: %s", fname)
                    break

        if not found:
            msg = (
                "Model file not found. Set environment variable "
                f"{MODEL_FILENAME_ENV} to the model filename or place {DEFAULT_MODEL_FILENAME} in the working directory."
            )
            logger.error(msg)
            raise FileNotFoundError(msg)

    except Exception:
        logger.error("Exception in init(): %s", traceback.format_exc())
        raise


def _parse_request(data):
    """
    Parse the incoming JSON payload into a 2D array-like structure suitable for model.predict.
    Accepts several common formats:
      - {"input_data": [[...], [...]]}
      - {"instances": [[...], [...]]}
      - {"data": [[...], [...]]}
      - a raw list/ndarray: [[...], [...]]
      - a JSON string representing any of the above
    Returns a numpy.ndarray.
    """
    try:
        # If data is a JSON string, parse it
        if isinstance(data, str):
            data = json.loads(data)

        # If top-level is a dict, look for common keys
        if isinstance(data, dict):
            for key in ("input_data", "instances", "data", "inputs"):
                if key in data:
                    arr = data[key]
                    return np.array(arr)
            # Some callers might send {"columns": [...], "data": [[...]]}
            if "data" in data and isinstance(data["data"], (list, tuple)):
                return np.array(data["data"])
            # If dict looks like a single row with features by name, convert to 2D
            # e.g., {"feature1": 1.0, "feature2": 2.0}
            if all(isinstance(v, (int, float, str, bool, list)) for v in data.values()):
                return np.array([list(data.values())])
            raise ValueError("Unrecognized JSON payload format for prediction input.")

        # If already list-like or numpy array
        if isinstance(data, (list, tuple, np.ndarray)):
            return np.array(data)

        raise ValueError("Unsupported payload type: {}".format(type(data)))

    except Exception:
        logger.error("Failed to parse request payload: %s", traceback.format_exc())
        raise


def _format_predictions(pred):
    """
    Convert model prediction outputs to JSON serializable Python objects.
    - numpy arrays -> lists
    - numpy types -> native Python types
    """
    try:
        if isinstance(pred, np.ndarray):
            return pred.tolist()
        # Some models (sklearn) return list already
        # For probability outputs: convert list of lists
        if isinstance(pred, (list, tuple)):
            # ensure nested numpy types converted
            return json.loads(json.dumps(pred, default=_numpy_encoder))
        # Scalar predictions
        return json.loads(json.dumps(pred, default=_numpy_encoder))
    except Exception:
        logger.warning("Failed to format predictions, falling back to string representation.")
        return str(pred)


def _numpy_encoder(obj):
    """
    Helper for json.dumps to convert numpy types.
    """
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating,)):
        return float(obj)
    if isinstance(obj, (np.ndarray,)):
        return obj.tolist()
    return str(obj)


def run(request_body):
    """
    Entry point for a single prediction request.
    Expects request_body to be a JSON-serializable payload (see _parse_request).
    Returns a JSON-serializable dict, for example: {"predictions": [...]} or {"error": "..."}
    """
    global MODEL
    try:
        if MODEL is None:
            raise RuntimeError("Model is not loaded. init() must run before run().")

        # request_body may be a dict already (Azure ML passes parsed JSON)
        inputs = _parse_request(request_body)

        # If input is a 1D array representing a single sample, convert to 2D
        if inputs.ndim == 1:
            inputs = inputs.reshape(1, -1)

        # If the model expects a pandas DataFrame, try to handle those models by passing numpy array;
        # many scikit-learn pipelines accept numpy arrays.
        # Invoke predict/probabilities depending on availability
        prediction = None
        probabilities = None

        # Prefer predict_proba when available and request asks for probabilities (optional)
        try:
            # If client requested method in payload, e.g., {"method": "predict_proba"}
            if isinstance(request_body, dict) and request_body.get("method") == "predict_proba" and hasattr(MODEL, "predict_proba"):
                probabilities = MODEL.predict_proba(inputs)
            else:
                # Try to get probabilities if available by default only if model exposes it and request asks for 'with_proba'
                if isinstance(request_body, dict) and request_body.get("with_proba") and hasattr(MODEL, "predict_proba"):
                    probabilities = MODEL.predict_proba(inputs)
                # Always compute prediction
                if hasattr(MODEL, "predict"):
                    prediction = MODEL.predict(inputs)
                else:
                    # Fallback: model itself might be a callable (e.g., custom function)
                    prediction = MODEL(inputs)
        except Exception:
            # Some models raise on predict_proba; ignore and proceed with predict
            logger.warning("predict/predict_proba raised an exception: %s", traceback.format_exc())
            if prediction is None and hasattr(MODEL, "predict"):
                prediction = MODEL.predict(inputs)

        result = {}
        if prediction is not None:
            result["predictions"] = _format_predictions(prediction)
        if probabilities is not None:
            result["probabilities"] = _format_predictions(probabilities)

        # Optionally return input echo for debugging
        if isinstance(request_body, dict) and request_body.get("echo_input"):
            result["input"] = _format_predictions(inputs)

        return result

    except Exception as e:
        logger.error("Exception during run(): %s", traceback.format_exc())
        return {"error": str(e), "trace": traceback.format_exc()}
