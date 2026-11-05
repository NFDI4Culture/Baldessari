"""Access to the Deutsche Nationalbibliothek (DNB) via SRU (MARC21-xml)."""

from __future__ import annotations

import re
import time
import unicodedata
import xml.etree.ElementTree as ET

import pandas as pd
import requests

from .sparql import USER_AGENT

SRU_ENDPOINT = "https://services.dnb.de/sru/dnb"
_NS = {"srw": "http://www.loc.gov/zing/srw/", "marc": "http://www.loc.gov/MARC21/slim"}
_PAGE_SIZE = 100


def _subfields(record: ET.Element, tag: str, code: str) -> list[str]:
    path = f"marc:datafield[@tag='{tag}']/marc:subfield[@code='{code}']"
    return [_normalize(e.text) for e in record.findall(path, _NS) if e.text]


def _normalize(text: str) -> str:
    """Compose Unicode (NFC) and drop MARC non-sorting-block control characters."""
    text = unicodedata.normalize("NFC", text)
    return re.sub(r"[\x80-\x9f]", "", text).strip()


def _first(values: list[str]) -> str | None:
    return values[0] if values else None


def _clean(text: str | None) -> str | None:
    if text is None:
        return None
    return re.sub(r"\s*[/:,;]\s*$", "", text).strip() or None


def _parse_record(record: ET.Element) -> dict[str, str | None]:
    idn = _first([e.text for e in record.findall("marc:controlfield[@tag='001']", _NS) if e.text])
    title = _clean(_first(_subfields(record, "245", "a")))
    subtitle = _clean(_first(_subfields(record, "245", "b")))
    year = _first(_subfields(record, "264", "c")) or _first(_subfields(record, "260", "c"))
    year_match = re.search(r"\d{4}", year or "")
    return {
        "idn": idn,
        "title": title,
        "subtitle": subtitle,
        "responsibility": _clean(_first(_subfields(record, "245", "c"))),
        "author": _clean(_first(_subfields(record, "100", "a"))),
        "publisher": _clean(_first(_subfields(record, "264", "b")) or _first(_subfields(record, "260", "b"))),
        "place": _clean(_first(_subfields(record, "264", "a")) or _first(_subfields(record, "260", "a"))),
        "year": int(year_match.group()) if year_match else None,
        "isbn": _first(_subfields(record, "020", "a")),
        "url": f"https://d-nb.info/{idn}" if idn else None,
    }


def search(query: str, max_records: int = 100, retries: int = 3) -> pd.DataFrame:
    """Run a CQL query (e.g. ``per="Baldessari, John"``) and return records as a DataFrame."""
    rows: list[dict[str, str | None]] = []
    start = 1
    total = None
    while total is None or (start <= total and len(rows) < max_records):
        params = {
            "version": "1.1",
            "operation": "searchRetrieve",
            "recordSchema": "MARC21-xml",
            "maximumRecords": min(_PAGE_SIZE, max_records - len(rows)),
            "startRecord": start,
            "query": query,
        }
        for attempt in range(retries):
            try:
                response = requests.get(
                    SRU_ENDPOINT, params=params, headers={"User-Agent": USER_AGENT}, timeout=60
                )
                response.raise_for_status()
                break
            except requests.RequestException:
                if attempt == retries - 1:
                    raise
                time.sleep(2**attempt)
        root = ET.fromstring(response.content)
        total = int(root.findtext("srw:numberOfRecords", default="0", namespaces=_NS))
        records = root.findall(".//marc:record", _NS)
        if not records:
            break
        rows.extend(_parse_record(r) for r in records)
        start += len(records)
    columns = ["idn", "title", "subtitle", "responsibility", "author", "publisher", "place", "year", "isbn", "url"]
    df = pd.DataFrame(rows, columns=columns)
    df["year"] = pd.to_numeric(df["year"], errors="coerce").astype("Int64")
    return df


def by_idn(idn: str) -> pd.DataFrame:
    """Fetch one DNB record by its identifier (the CPS ``DNB edition ID``, P44)."""
    return search(f"num={idn}", max_records=1)


def about_baldessari(max_records: int = 200) -> pd.DataFrame:
    """Publications in the DNB catalogue by or about John Baldessari."""
    return search('per="Baldessari, John"', max_records=max_records)
