"""Generic SPARQL client returning pandas DataFrames."""

from __future__ import annotations

import time

import pandas as pd
import requests

USER_AGENT = "BaldessariBook/0.1 (https://github.com/NFDI4Culture/Baldessari; Quarto book build)"


def run_query(
    endpoint: str,
    query: str,
    *,
    timeout: int = 60,
    retries: int = 3,
) -> pd.DataFrame:
    """Run a SELECT query and return the bindings as a DataFrame of strings.

    Unbound variables become ``None``. Transient failures (HTTP 429/5xx,
    connection errors) are retried with exponential back-off.
    """
    headers = {
        "Accept": "application/sparql-results+json",
        "User-Agent": USER_AGENT,
    }
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            response = requests.post(
                endpoint, data={"query": query}, headers=headers, timeout=timeout
            )
            if response.status_code in (429, 500, 502, 503, 504):
                response.raise_for_status()
            response.raise_for_status()
            payload = response.json()
            break
        except requests.RequestException as exc:
            last_error = exc
            if attempt == retries - 1:
                raise
            time.sleep(2**attempt)
    else:  # pragma: no cover
        raise RuntimeError("SPARQL request failed") from last_error

    columns = payload["head"]["vars"]
    rows = [
        {col: binding[col]["value"] if col in binding else None for col in columns}
        for binding in payload["results"]["bindings"]
    ]
    return pd.DataFrame(rows, columns=columns)


def local_id(uri: str | None) -> str | None:
    """Return the last path segment of an entity URI (``.../entity/Q47`` -> ``Q47``)."""
    if uri is None or (isinstance(uri, float) and pd.isna(uri)):
        return None
    return str(uri).rstrip("/").rsplit("/", 1)[-1]


def to_year(series: pd.Series) -> pd.Series:
    """Convert xsd:dateTime strings (``1967-01-01T00:00:00Z``) to integer years."""
    return pd.to_numeric(series.str.slice(0, 4), errors="coerce").astype("Int64")
