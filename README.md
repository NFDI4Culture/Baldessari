# John Baldessari in Linked Open Data

A [Quarto](https://quarto.org/) book generated from live data of the [CPS Wikibase](https://cps.tibwiki.io/), [Wikidata](https://www.wikidata.org/) and the Deutsche Nationalbibliothek (DNB). Outputs: website (responsive, mobile friendly), PDF (Typst), DOCX and ePUB.

Published at <https://nfdi4culture.github.io/Baldessari/>.

## Requirements

- [Quarto](https://quarto.org/docs/get-started/) 1.5 or newer (includes Typst)
- Python 3.10 or newer

## Build locally

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
quarto render --profile web --to html
quarto render --to typst --no-clean
quarto render --to docx --no-clean
quarto render --to epub --no-clean
```

The `web` profile (`_quarto-web.yml`) adds the Imprint, Privacy Policy, Data Protection and Accessibility pages and the footer links to the website only; PDF, DOCX and ePUB are rendered without them. Run `quarto render` without a profile to build everything without the legal pages.

On Linux or macOS activate with `source .venv/bin/activate`. The output is written to `_book/`. Use `quarto preview --profile web` for a live preview of the website.

## Layout

| Path | Purpose |
|------|---------|
| `_quarto.yml` | Book and format configuration |
| `_quarto-web.yml` | Web-only profile: legal pages and footer links |
| `*.qmd`, `artworks.ipynb` | Chapters |
| `src/baldessari/` | Python package: SPARQL client, CPS, Wikidata and DNB helpers, plots |
| `src/baldessari/queries/` | SPARQL queries as `.rq` files |
| `assets/` | Styles, DOCX template, ePUB cover and metadata |
| `_freeze/` | Cached execution results (committed) |
| `.github/workflows/` | Publishing to GitHub Pages and scheduled data refresh |

## Data and caching

Chapters query the endpoints when they are rendered. `freeze: auto` stores the results in `_freeze/`, so unchanged chapters are not re-executed. To refresh all data, delete `_freeze/` and render again, or run the *Refresh data* workflow.

To query another Wikibase instance (for example a local Docker installation) set the environment variable `CPS_ENDPOINT`.

## Publishing

In the GitHub repository settings set **Pages > Source** to **GitHub Actions**. The *Publish* workflow then builds and deploys the book on every push to `main`.

## Licence

Text: [CC BY 4.0](LICENSE). Code: MIT.
