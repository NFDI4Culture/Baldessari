"""Build the downloadable spreadsheet template used in the how-to chapter.

Run from the repository root:  python assets/make_template.py
"""

from pathlib import Path

from openpyxl import Workbook
from openpyxl.comments import Comment
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.datavalidation import DataValidation

OUT = Path(__file__).resolve().parent.parent / "downloads" / "baldessari-exhibition-template.xlsx"
LAST_ROW = 500
COBALT = "0047AB"

TITLE = "BALDESSARI : While something is happening here, something else is happening there : Works 1988\u20131999"
ARTWORK_TYPES = [
    "painting",
    "photograph",
    "film",
    "video",
    "drawing",
    "print",
    "sculpture",
    "installation",
    "mixed media",
]

# header, width, note (Wikidata / CPS mapping), example, text format?
SHEETS = {
    "Artist": [
        ("Name", 28, "Name as commonly written. Label in Wikidata and CPS.", "John Baldessari", False),
        (
            "Wikidata ID",
            16,
            "Optional. Existing Wikidata item, for example Q683378. CPS P24.",
            "Q683378",
            False,
        ),
    ],
    "Exhibition": [
        ("Title", 60, "Title of the exhibition. Wikidata P1476, CPS P5.", TITLE, False),
        ("Start date", 14, "First day, written YYYY-MM-DD. Wikidata P580, CPS P27.", "1999-09-26", True),
        ("End date", 14, "Last day, written YYYY-MM-DD. Wikidata P582, CPS P28.", "2000-01-02", True),
        ("Location", 32, "Venue where it was shown. Wikidata P276, CPS P16.", "Sprengel Museum Hannover", False),
        (
            "Catalogue",
            40,
            "Pick the catalogue that documents the exhibition. Wikidata P1343, CPS P47, CIDOC P70i.",
            TITLE,
            False,
        ),
    ],
    "Catalogue": [
        ("Title", 60, "Title of the catalogue. Wikidata P1476, CPS P5.", TITLE, False),
        (
            "ISBN or identifier",
            24,
            "ISBN-13 if there is one, otherwise another identifier. Wikidata P212, CPS P43.",
            "978-3-88375-396-6",
            True,
        ),
    ],
    "Artwork": [
        ("Title", 40, "Title of the work. Wikidata P1476, CPS P5.", "Man Running/Men Carrying Box", False),
        (
            "Artwork type",
            16,
            "What kind of object it is. Pick from the list or type your own. Wikidata P31, CPS P4.",
            "photograph",
            False,
        ),
        (
            "Materials",
            40,
            "Materials and techniques. Wikidata P186, CPS P9.",
            "Black and white photographs, vinyl paint, oil tint",
            False,
        ),
        ("Artist", 24, "Pick the artist. Wikidata P170, CPS P6.", "John Baldessari", False),
        ("Date created", 14, "Year, or YYYY-MM-DD. Wikidata P571, CPS P7.", "1988", True),
        ("Width cm", 11, "Width in centimetres. Wikidata P2049, CPS P12.", 268, False),
        ("Height cm", 11, "Height in centimetres. Wikidata P2048, CPS P11.", 123, False),
        (
            "Exhibition",
            40,
            "The exhibition, not the venue. Leave empty if the work was not exhibited. "
            "CIDOC P9i forms part of, Wikidata P608, CPS P21.",
            TITLE,
            False,
        ),
        (
            "Catalogue",
            40,
            "The catalogue in which the work appears. Wikidata P1343, CPS P48.",
            TITLE,
            False,
        ),
    ],
}

README = [
    ("Exhibition record template", True),
    ("", False),
    ("Fill in one sheet per kind of record, in this order: Artist, Exhibition, Catalogue, Artwork.", False),
    ("Row 2 of every sheet is an example from the John Baldessari exhibition. Overwrite or delete it.", False),
    ("Where a cell has a drop-down arrow, pick a value you entered on another sheet so the records stay connected.", False),
    ("Hover over a column heading to see which Wikidata, CPS Wikibase and CIDOC property it maps to.", False),
    ("", False),
    ("The key connection is the Exhibition column on the Artwork sheet (CIDOC P9i forms part of).", False),
    ("Enter the exhibition, not the venue. Leave it empty for works that were not exhibited.", False),
    ("", False),
    ("Dates: write 1999-09-26 (year-month-day), or just the year for the date created.", False),
    ("Sizes: centimetres, numbers only.", False),
    ("", False),
    ("Guide: https://nfdi4culture.github.io/Baldessari/how-to.html", False),
]


def build() -> Path:
    wb = Workbook()
    readme = wb.active
    readme.title = "Read me"
    readme.column_dimensions["A"].width = 110
    for i, (text, bold) in enumerate(README, start=1):
        cell = readme.cell(row=i, column=1, value=text)
        cell.font = Font(bold=bold, size=14 if bold else 11, color=COBALT if bold else "000000")
        cell.alignment = Alignment(wrap_text=True, vertical="top")

    header_fill = PatternFill("solid", fgColor=COBALT)
    header_font = Font(bold=True, color="FFFFFF")
    example_font = Font(italic=True, color="808080")

    for name, columns in SHEETS.items():
        ws = wb.create_sheet(name)
        for col, (header, width, note, example, as_text) in enumerate(columns, start=1):
            letter = ws.cell(row=1, column=col).column_letter
            head = ws.cell(row=1, column=col, value=header)
            head.fill = header_fill
            head.font = header_font
            head.alignment = Alignment(horizontal="center", vertical="center")
            head.comment = Comment(note, "CPS")
            ws.column_dimensions[letter].width = width
            ex = ws.cell(row=2, column=col, value=example)
            ex.font = example_font
            if as_text:
                for row in range(2, LAST_ROW + 1):
                    ws.cell(row=row, column=col).number_format = "@"
        ws.row_dimensions[1].height = 24
        ws.freeze_panes = "A2"

    def add_list(ws, header, formula):
        columns = [c[0] for c in SHEETS[ws.title]]
        letter = ws.cell(row=1, column=columns.index(header) + 1).column_letter
        dv = DataValidation(type="list", formula1=formula, allow_blank=True, errorStyle="warning")
        dv.showErrorMessage = True
        dv.errorTitle = "Not on the list"
        dv.error = "This value is not on the matching sheet yet. Add it there first, or keep it anyway."
        ws.add_data_validation(dv)
        dv.add(f"{letter}2:{letter}{LAST_ROW}")

    for sheet, header, source in [
        ("Exhibition", "Catalogue", f"=Catalogue!$A$2:$A${LAST_ROW}"),
        ("Artwork", "Artist", f"=Artist!$A$2:$A${LAST_ROW}"),
        ("Artwork", "Exhibition", f"=Exhibition!$A$2:$A${LAST_ROW}"),
        ("Artwork", "Catalogue", f"=Catalogue!$A$2:$A${LAST_ROW}"),
        ("Artwork", "Artwork type", '"' + ",".join(ARTWORK_TYPES) + '"'),
    ]:
        add_list(wb[sheet], header, source)

    sizes = DataValidation(type="decimal", operator="greaterThan", formula1="0", allow_blank=True, errorStyle="warning")
    sizes.showErrorMessage = True
    sizes.error = "Enter the size in centimetres as a number."
    artwork = wb["Artwork"]
    artwork.add_data_validation(sizes)
    sizes.add(f"F2:G{LAST_ROW}")

    OUT.parent.mkdir(exist_ok=True)
    wb.save(OUT)
    return OUT


if __name__ == "__main__":
    print(build())
