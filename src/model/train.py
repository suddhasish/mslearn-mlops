# train.py

# Import libraries
import argparse
import glob
import os
import pandas as pd
from sklearn.linear_model import LogisticRegression

# 🟥 >>> ADDED CODE START
import logging
import json
import joblib
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
)
import mlflow

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s - %(message)s",
)
logger = logging.getLogger(__name__)
# 🟥 >>> ADDED CODE END


def main(args):
    # Enable autologging
    mlflow.autolog()
    logger.info("Starting training run")
    logger.info("Arguments: %s", args)

    # Determine output folder: prefer args.output
    env_output = (
        os.environ.get("AZURE_ML_OUTPUT_model")
        or os.environ.get("AZURE_ML_OUTPUT_MODEL")
    )
    out_path = args.output if args.output else env_output
    if not out_path:
        out_path = "outputs/model"  # final fallback for local runs/tests

    # log & print resolved path so you can find it in container logs
    logger.info("Resolved output path: %s (args.output=%s env_output=%s)", 
        out_path, args.output, env_output)
    print("OUTPUT_PATH_IN_CONTAINER=", out_path, flush=True)

    # create marker (so you can see it in uploads)
    try:
        os.makedirs(out_path, exist_ok=True)
        with open(os.path.join(out_path, "RUN_MARKER.txt"), "w") as fh:
            fh.write("written_by_train.py\n")
        logger.info("Wrote RUN_MARKER.txt to output folder")
    except Exception as e:
        logger.warning("Failed marker file in output folder: %s", e)

    # read data
    df = get_csvs_df(args.training_data)

    # split data
    X_train, X_test, y_train, y_test = split_data(
        df,
        target_col=args.target_col,
        test_size=args.test_size,
        random_state=args.random_state,
    )

    # train model
    train_model(args.reg_rate, X_train, X_test, y_train, y_test, out_path)

    # final listing to ensure we see what was created (printed to stdout)
    try:
        files = os.listdir(out_path)
        logger.info(" contents of output (%s): %s", out_path, files)
        print("OUTPUT_DIR_LISTING=", files, flush=True)
    except Exception as e:
        logger.warning("Failed to list output dir contents: %s", e)


def get_csvs_df(path):
    if not os.path.exists(path):
        raise RuntimeError(
            f"Cannot use non-existent path provided: {path}"
        )
    csv_files = glob.glob(os.path.join(path, "*.csv"))
    if not csv_files:
        raise RuntimeError(
            f"No CSV files found in provided data path: {path}"
        )
    return pd.concat((pd.read_csv(f) for f in csv_files), sort=False)


# 🟥 >>> ADDED CODE START
def split_data(
    df, target_col: str = None, test_size: float = 0.2, random_state: int = 42
):
    """Split dataframe into train/test sets."""

    if target_col and target_col in df.columns:
        target = target_col
        logger.info("Using specified target column: %s", target)
    else:
        candidates = [c for c in ("target", "label", "y") if c in df.columns]
        target = candidates[0] if candidates else df.columns[-1]
        logger.info("Auto-detected target column: %s", target)

    y = df[target]
    X = df.drop(columns=[target])

    X = X.dropna(axis=1, how="all")
    for col in X.select_dtypes(include=["bool"]).columns:
        X[col] = X[col].astype(int)

    obj_cols = X.select_dtypes(include=["object", "category"]).columns.tolist()
    if obj_cols:
        logger.info("Encoding categorical columns: %s", obj_cols)
        X = pd.get_dummies(X, columns=obj_cols, drop_first=True)

    for col in X.select_dtypes(include=[np.number]).columns:
        X[col] = X[col].fillna(X[col].median())

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=test_size,
        random_state=random_state,
        stratify=(y if y.nunique() > 1 else None),
    )

    return X_train, X_test, y_train, y_test
# 🟥 >>> ADDED CODE END


def train_model(reg_rate, X_train, X_test, y_train, y_test, output_dir: str):
    logger.info("Training model with reg_rate=%s", reg_rate)
    clf = LogisticRegression(C=1 / reg_rate, solver="liblinear").fit(
        X_train, y_train
    )
    preds = clf.predict(X_test)

    acc = accuracy_score(y_test, preds)
    prec = precision_score(
        y_test,
        preds,
        average="binary" if len(np.unique(y_test)) == 2 else "weighted",
        zero_division=0,
    )
    rec = recall_score(
        y_test,
        preds,
        average="binary" if len(np.unique(y_test)) == 2 else "weighted",
        zero_division=0,
    )
    f1 = f1_score(
        y_test,
        preds,
        average="binary" if len(np.unique(y_test)) == 2 else "weighted",
        zero_division=0,
    )

    logger.info(
        "Metrics: accuracy=%.4f, precision=%.4f, recall=%.4f, f1=%.4f",
        acc,
        prec,
        rec,
        f1,
    )

    try:
        mlflow.log_metric("accuracy", acc)
        mlflow.log_metric("precision", prec)
        mlflow.log_metric("recall", rec)
        mlflow.log_metric("f1", f1)
    except Exception as e:
        logger.warning("MLflow logging failed: %s", e)

    # -------------------------
    # Save model and metrics to provided output_dir
    # -------------------------
    out_dir = output_dir if output_dir else "outputs/model"
    os.makedirs(out_dir, exist_ok=True)

    model_path = os.path.join(out_dir, "model.pkl")
    try:
        joblib.dump(clf, model_path)
        logger.info("Saved model to %s", model_path)
        print("SAVED_MODEL_AT=", model_path, flush=True)
    except Exception as e:
        logger.warning("Failed to save model: %s", e)

    metrics = {
        "accuracy": float(acc),
        "precision": float(prec),
        "recall": float(rec),
        "f1": float(f1),
    }
    metrics_path = os.path.join(out_dir, "metrics.json")
    try:
        with open(metrics_path, "w") as fh:
            json.dump(metrics, fh)
        logger.info("Saved metrics to %s", metrics_path)
    except Exception as e:
        logger.warning("Failed to save metrics: %s", e)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--training_data", dest="training_data", type=str, required=True
    )
    parser.add_argument(
        "--reg_rate", dest="reg_rate", type=float, default=0.01
    )
    # 🟥 >>> ADDED CODE START
    parser.add_argument(
        "--target_col", dest="target_col", type=str, default=None
    )
    parser.add_argument(
        "--test_size", dest="test_size", type=float, default=0.2
    )
    parser.add_argument(
        "--random_state", dest="random_state", type=int, default=42
    )
    parser.add_argument(
        "--output", dest="output", type=str, default=None,
        help="For Azure ML outputs use ${{outputs.model}}"
    )
    # 🟥 >>> ADDED CODE END
    args = parser.parse_args()
    return args


if __name__ == "__main__":
    print("\n\n")
    print("*" * 60)

    args = parse_args()
    main(args)

    print("*" * 60)
    print("\n\n")
