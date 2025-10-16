# tests/test_train.py
import os
import numpy as np
import pandas as pd
import pytest

from model.train import get_csvs_df, split_data, train_model


def _make_csv(path, filename, df):
    p = os.path.join(path, filename)
    df.to_csv(p, index=False)
    return p


def _build_sample_dataframe(n_rows=10, include_categorical=True,
                            include_bool=True, include_nans=True):
    """Create a small sample DataFrame covering numeric, categorical,
    bool, and NaNs."""
    rng = np.random.default_rng(42)
    df = pd.DataFrame({
        "num1": rng.integers(0, 100, size=n_rows).astype(float),
        "num2": rng.normal(size=n_rows),
    })
    if include_categorical:
        df["cat1"] = ["A" if i % 2 == 0 else "B"
                      for i in range(n_rows)]
    if include_bool:
        df["flag"] = [(i % 3) == 0 for i in range(n_rows)]
    df["label"] = [0 if i < n_rows // 2 else 1
                   for i in range(n_rows)]
    if include_nans and n_rows >= 3:
        df.loc[1, "num1"] = np.nan
        df.loc[2, "num2"] = np.nan
    return df


def test_get_csvs_df_errors_for_missing_path(tmp_path):
    bad_path = tmp_path / "does_not_exist"
    with pytest.raises(
        RuntimeError, match="Cannot use non-existent path provided"
    ):
        get_csvs_df(str(bad_path))


def test_get_csvs_df_errors_for_no_csv(tmp_path):
    empty = tmp_path / "empty_dir"
    empty.mkdir()
    with pytest.raises(
        RuntimeError, match="No CSV files found in provided data"
    ):
        get_csvs_df(str(empty))


def test_get_csvs_df_concatenates_csvs(tmp_path):
    d = tmp_path / "data"
    d.mkdir()
    df1 = _build_sample_dataframe(n_rows=7)
    df2 = _build_sample_dataframe(n_rows=5)
    _make_csv(str(d), "a.csv", df1)
    _make_csv(str(d), "b.csv", df2)

    out = get_csvs_df(str(d))
    assert len(out) == 12
    for col in ["num1", "num2", "label"]:
        assert col in out.columns


def test_split_data_auto_detect_target_and_preprocessing():
    df = _build_sample_dataframe(n_rows=30)
    X_train, X_test, y_train, y_test = split_data(
        df, target_col=None, test_size=0.2, random_state=0
    )

    assert len(X_train) + len(X_test) == len(df)
    assert len(y_train) + len(y_test) == len(df)

    cat_cols = [c for c in X_train.columns if c.startswith("cat1")]
    assert len(cat_cols) >= 1

    assert "flag" in X_train.columns
    assert X_train["flag"].dtype.kind in ("i", "u")

    numeric_cols = X_train.select_dtypes(include=[np.number]).columns
    assert not X_train[numeric_cols].isnull().any().any()


def test_split_data_with_explicit_target_column():
    df = _build_sample_dataframe(n_rows=50)
    df = df.rename(columns={"label": "my_target"})
    X_train, X_test, y_train, y_test = split_data(
        df, target_col="my_target", test_size=0.25, random_state=1
    )
    assert len(y_train) > 0
    assert y_train.name == "my_target"


def test_train_model_logs_metrics(monkeypatch, tmp_path):
    df = _build_sample_dataframe(n_rows=40)
    X_train, X_test, y_train, y_test = split_data(
        df, target_col="label", test_size=0.25, random_state=7
    )

    logged = {}

    def fake_log_metric(name, value):
        logged.setdefault(name, []).append(value)

    import mlflow
    monkeypatch.setattr(mlflow, "log_metric", fake_log_metric)

    # create an isolated output directory for this test and pass its path
    out_dir = tmp_path / "model_outputs"
    out_dir.mkdir()
    # pass explicit output path to match production usage
    train_model(0.05, X_train, X_test, y_train, y_test, str(out_dir))

    for metric in ("accuracy", "precision", "recall", "f1"):
        assert metric in logged and len(logged[metric]) >= 1
        val = logged[metric][-1]
        assert isinstance(val, (int, float))
        assert 0.0 <= float(val) <= 1.0

    # optional: assert artifacts were created (supports .pkl or .joblib)
    assert (out_dir / "model.pkl").exists()
    assert (out_dir / "metrics.json").exists()
