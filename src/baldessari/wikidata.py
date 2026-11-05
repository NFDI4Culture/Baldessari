"""Queries against the Wikidata Query Service."""

from __future__ import annotations

import pandas as pd

from .sparql import run_query

ENDPOINT = "https://query.wikidata.org/sparql"

BALDESSARI = "Q683378"  # John Baldessari

# Wikidata properties used to describe an artist.
PROFILE_PROPERTIES = {
    "P569": "date of birth",
    "P570": "date of death",
    "P19": "place of birth",
    "P20": "place of death",
    "P27": "country of citizenship",
    "P106": "occupation",
    "P135": "movement",
    "P69": "educated at",
    "P108": "employer",
    "P166": "award received",
    "P800": "notable work",
}

RELATION_PROPERTIES = {
    "P1066": "student of",
    "P802": "student",
    "P737": "influenced by",
    "P451": "partner in business or sport",
    "P26": "spouse",
}


def _values(qids: list[str]) -> str:
    return " ".join(f"wd:{q}" for q in qids)


def entities(qids: list[str]) -> pd.DataFrame:
    """Label, description, instance-of and image for the given Wikidata QIDs."""
    qids = sorted({q for q in qids if q})
    if not qids:
        return pd.DataFrame(columns=["qid", "label", "description", "instanceOf", "image"])
    query = f"""
    SELECT ?item ?itemLabel ?itemDescription
           (GROUP_CONCAT(DISTINCT ?instLabel; separator = "; ") AS ?instanceOf)
           (SAMPLE(?img) AS ?image)
    WHERE {{
      VALUES ?item {{ {_values(qids)} }}
      OPTIONAL {{ ?item wdt:P31 ?inst . ?inst rdfs:label ?instLabel . FILTER(LANG(?instLabel) = "en") }}
      OPTIONAL {{ ?item wdt:P18 ?img }}
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
    }}
    GROUP BY ?item ?itemLabel ?itemDescription
    """
    df = run_query(ENDPOINT, query)
    df["qid"] = df["item"].str.rsplit("/", n=1).str[-1]
    return df.rename(
        columns={"itemLabel": "label", "itemDescription": "description"}
    )[["qid", "label", "description", "instanceOf", "image"]]


def statements(qid: str, properties: dict[str, str]) -> pd.DataFrame:
    """Selected statements for one item as (property, value) rows."""
    props = " ".join(f"wdt:{p}" for p in properties)
    query = f"""
    SELECT ?property ?propertyLabel ?value ?valueLabel
    WHERE {{
      VALUES ?item {{ wd:{qid} }}
      VALUES ?wdtProp {{ {props} }}
      ?item ?wdtProp ?value .
      ?property wikibase:directClaim ?wdtProp .
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
    }}
    ORDER BY ?propertyLabel ?valueLabel
    """
    df = run_query(ENDPOINT, query)
    df["pid"] = df["property"].str.rsplit("/", n=1).str[-1]
    return df


def artist_profile(qid: str = BALDESSARI) -> pd.DataFrame:
    return statements(qid, PROFILE_PROPERTIES)


def artist_relations(qid: str = BALDESSARI) -> pd.DataFrame:
    return statements(qid, RELATION_PROPERTIES)
