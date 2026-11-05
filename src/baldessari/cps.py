"""Queries against the CPS Wikibase (https://cps.tibwiki.io/).

The endpoint can be overridden with the ``CPS_ENDPOINT`` environment variable,
e.g. to query a local Docker Wikibase during development.
"""

from __future__ import annotations

import os
from importlib import resources

import pandas as pd

from .sparql import local_id, run_query, to_year

ENDPOINT = os.environ.get("CPS_ENDPOINT", "https://cps.tibwiki.io/query/proxy/sparql")
ENTITY_BASE = "https://cps.tibwiki.io/entity/"
WIKI_BASE = "https://cps.tibwiki.io/wiki/"

# Item types (P3) used in the CPS knowledge graph.
TYPE_ARTWORK = "Q1"
TYPE_PERSON = "Q2"
TYPE_EXHIBITION = "Q3"
TYPE_MATERIAL = "Q5"
TYPE_PAINTING = "Q15"
TYPE_PHOTOGRAPH = "Q17"
TYPE_FILM = ("Q45", "Q46", "Q200", "Q201", "Q202", "Q204")

BALDESSARI = "Q47"  # John Baldessari in CPS (Wikidata Q683378, GND 118506153)


def _query_text(name: str) -> str:
    return resources.files("baldessari").joinpath("queries", f"{name}.rq").read_text(encoding="utf-8")


def _run(name: str, **substitutions: str) -> pd.DataFrame:
    text = _query_text(name)
    for key, value in substitutions.items():
        text = text.replace("{{" + key + "}}", value)
    return run_query(ENDPOINT, text)


def item_url(qid: str) -> str:
    return f"{WIKI_BASE}Item:{qid}"


def type_counts() -> pd.DataFrame:
    """Number of items per type."""
    df = _run("type_counts")
    df["type"] = df["type"].map(local_id)
    df["items"] = df["items"].astype(int)
    return df


def works(*types: str) -> pd.DataFrame:
    """Items of the given type QIDs (e.g. ``works("Q1")``) with descriptive fields."""
    flat: list[str] = []
    for t in types:
        flat.extend(t if isinstance(t, (tuple, list)) else [t])
    values = " ".join(f"cps:{t}" for t in flat)
    df = _run("works", TYPES=values)
    df["qid"] = df["item"].map(local_id)
    df["year"] = to_year(df["date"].fillna(""))
    for col in ("height", "width", "depth"):
        df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def artworks() -> pd.DataFrame:
    return works(TYPE_ARTWORK)


def paintings() -> pd.DataFrame:
    return works(TYPE_PAINTING)


def photographs() -> pd.DataFrame:
    return works(TYPE_PHOTOGRAPH)


def films() -> pd.DataFrame:
    return works(TYPE_FILM)


def materials() -> pd.DataFrame:
    df = _run("materials")
    df["qid"] = df["item"].map(local_id)
    df["works"] = df["works"].astype(int)
    return df


def persons() -> pd.DataFrame:
    df = _run("persons")
    df["qid"] = df["item"].map(local_id)
    df["works"] = df["works"].astype(int)
    return df


def exhibitions() -> pd.DataFrame:
    df = _run("exhibitions")
    df["qid"] = df["item"].map(local_id)
    df["works"] = df["works"].astype(int)
    return df


def exhibited_works() -> pd.DataFrame:
    df = _run("exhibited_works")
    df["qid"] = df["item"].map(local_id)
    return df


def catalogues() -> pd.DataFrame:
    df = _run("catalogues")
    df["qid"] = df["item"].map(local_id)
    return df


def wikidata_links() -> pd.DataFrame:
    """CPS items that carry a Wikidata QID (P24)."""
    df = _run("wikidata_links")
    df["qid"] = df["item"].map(local_id)
    return df
