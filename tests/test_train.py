# tests/test_train.py
import os
import csv
import tempfile
import shutil
import numpy as np
import pandas as pd
import pytest

# Import target functions from your module.
# If your package layout is src/model/train.py and tests run from repo root,
# `from model.train import ...` should work (as in your original tests).
# If imports fail, run pytest from repo root or adjust PYTHONPATH so `src/` is on sys.path.
from model.train import get_csvs_df, split_data, train_model


def _make_csv(path, filename, df):
    p = os.path.join(path, filename)
    df.to_csv(p, index=False)
    return p


def _build_sample_dataframe(n_rows=10,
                            include_categorical=True,
                            include_bool=True,
                            include_nans=True,
                            name_prefix="row"):
    """Create a small sample DataFrame covering numeric, categorical, bool, and NaNs."""
    rng = np.random.default_rng(42)
    df = pd.DataFrame({
        "num1": rng.integers(0, 100, size=n_rows).astype(float),
        "num2": rng.normal(size=n_rows),
    })
    if include_categorical:
        df["cat1"] = ["A" if i % 2 == 0 else "B" for i in range(n_rows)]
    if include_bool:
        df["flag"] = [(i % 3) == 0 for i in range(n_rows)]
    # create binary target column
    df["label"] = [0 if i < n_rows // 2 else 1 for i in range(n_rows)]
    if include_nans:
        # add some NaNs in numeric column
        if n_rows >= 3:
            df.loc[1, "num1"] = np.nan
            df.loc[2, "num2"] = np.nan
    return df


def test_get_csvs_df_errors_for_missing_path(tmp_path):
    # non-existent path
    bad_path = tmp_path / "does_not_exist"
    with pytest.raises(RuntimeError, match="Cannot use non-existent path provided"):
        get_csvs_df(str(bad_path))


def test_get_csvs_df_errors_for_no_csv(tmp_path):
    # create an empty directory (no csv)
    empty = tmp_path / "empty_dir"
    empty.mkdir()
    with pytest.raises(RuntimeError, match="No CSV files found in provided data"):
        get_csvs_df(str(empty))


def test_get_csvs_df_concatenates_csvs(tmp_path):
    # create two small CSVs and assert concatenation
    d = tmp_path / "data"
    d.mkdir()
    df1 = _build_sample_dataframe(n_rows=7)
    df2 = _build_sample_dataframe(n_rows=5)
    _make_csv(str(d), "a.csv", df1)
    _make_csv(str(d), "b.csv", df2)

    out = get_csvs_df(str(d))
    # should be 7 + 5 = 12 rows
    assert len(out) == 12
    # should contain expected columns
    for col in ["num1", "num2", "label"]:
        assert col in out.columns


def test_split_data_auto_detect_target_and_preprocessing():
    # Build a DataFrame with mixed types and a target named "label" (auto-detect)
    df = _build_sample_dataframe(n_rows=30)
    X_train, X_test, y_train, y_test = split_data(df, target_col=None, test_size=0.2, random_state=0)

    # target arrays lengths
    assert len(X_train) + len(X_test) == len(df)
    assert len(y_train) + len(y_test) == len(df)

    # categorical columns should be one-hot encoded (cat1 -> cat1_B with drop_first True)
    # note: after get_dummies with drop_first, we expect at least one new column for cat1
    cat_cols = [c for c in X_train.columns if c.startswith("cat1")]
    assert len(cat_cols) >= 1

    # bool column should be converted to numeric (flag -> 0/1)
    assert "flag" in X_train.columns
    assert X_train["flag"].dtype.kind in ("i", "u")  # integer dtype

    # numeric NaNs should be filled (no NaNs left in numeric columns)
    numeric_cols = X_train.select_dtypes(include=[np.number]).columns
    assert not X_train[numeric_cols].isnull().any().any()


def test_split_data_with_explicit_target_column():
    # name the target something non-standard and pass target_col explicitly
    df = _build_sample_dataframe(n_rows=50)
    df = df.rename(columns={"label": "my_target"})
    X_train, X_test, y_train, y_test = split_data(df, target_col="my_target", test_size=0.25, random_state=1)

    # check the target returned matches the column passed
    assert len(y_train) > 0
    assert y_train.name == "my_target"


def test_train_model_logs_metrics(monkeypatch):
    # Build small dataset and call train_model; monkeypatch mlflow.log_metric to capture calls
    df = _build_sample_dataframe(n_rows=40)
    X_train, X_test, y_train, y_test = split_data(df, target_col="label", test_size=0.25, random_state=7)

    logged = {}

    def fake_log_metric(name, value):
        # record that the metric was logged and the numeric value
        logged.setdefault(name, []).append(value)

    # Monkeypatch mlflow.log_metric used inside train_model
    import mlflow
    monkeypatch.setattr(mlflow, "log_metric", fake_log_metric)

    # Call train_model - should not raise
    train_model(0.05, X_train, X_test, y_train, y_test)

    # Ensure at least the main metrics were logged
    for metric in ("accuracy", "precision", "recall", "f1"):
        assert metric in logged and len(logged[metric]) >= 1
        # value should be a real number between 0 and 1
        val = logged[metric][-1]
        assert isinstance(val, (int, float))
        assert 0.0 <= float(val) <= 1.0
