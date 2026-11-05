"""Display helpers that work in every Quarto output format."""

from __future__ import annotations

import pandas as pd
from IPython.display import Markdown


def table(df: pd.DataFrame) -> Markdown:
    """Render a DataFrame as a Markdown pipe table (safe for HTML, Typst, DOCX and EPUB).

    Give the cell a ``label: tbl-...`` and ``tbl-cap`` option to caption and
    cross-reference the table.
    """
    clean = df.copy()
    for col in clean.columns:
        clean[col] = clean[col].map(
            lambda v: "" if pd.isna(v) else str(v).replace("|", "\\|").replace("\n", " ")
        )
    return Markdown(clean.to_markdown(index=False, tablefmt="pipe"))


def _num(value: float) -> str:
    return "" if pd.isna(value) else f"{value:g}"


def works_table(df: pd.DataFrame) -> pd.DataFrame:
    """Compact presentation of a ``cps.works()`` result."""
    return pd.DataFrame(
        {
            "ID": df["qid"],
            "Title": df["label"],
            "Year": df["year"],
            "Materials": df["materials"].where(df["materials"] != "", df["materialsStated"]),
            "Size (cm)": [
                " × ".join(x for x in (_num(h), _num(w), _num(d)) if x)
                for h, w, d in zip(df["height"], df["width"], df["depth"])
            ],
        }
    )
