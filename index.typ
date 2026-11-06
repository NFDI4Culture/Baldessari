// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 2.5cm,y: 2.5cm,),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [John Baldessari - A Linked Open Exhibition Guide],
  subtitle: [A data-driven book sourced from OCR, CPS Wikibase, Wikidata, and the DNB],
  author: "CPS",
  date: "2026-11-06",
  lang: "en",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 2,
  supplement-chapter: "Chapter",
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

= Preface
<preface>
This book presents the work of the artist John Baldessari (1931--2020) as it is described in a linked-data knowledge graph. Every table and figure is generated from live data when the book is built:

- #strong[OCR catalogue extraction], which provides structured data extracted from the exhibition catalogue,
- the #strong[CPS Wikibase] at #link("https://cps.tibwiki.io/"), which records artworks, materials, persons, exhibitions and their catalogue,
- #strong[Wikidata], which supplies context and shared identifiers, and
- the #strong[Deutsche Nationalbibliothek (DNB)], which supplies bibliographic records.

The book is written in #link("https://quarto.org/")[Quarto] with Python and is published as a website, a PDF, a Word document and an ePUB. The source code and the build workflow are on #link("https://github.com/NFDI4Culture/Baldessari")[GitHub].

#block[
#callout(
body: 
[
The data are a work in progress. The CPS Wikibase is edited continuously, so figures in this book reflect the state of the data on the build date shown on the title page.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== How to read this book
<how-to-read-this-book>
#ref(<sec-introduction>, supplement: [Chapter]) describes the data sources and the data model. The first part, #link("exhibition-catalogue.qmd")[Exhibition catalogue], presents the exhibition, the artist, the catalogue and the works on view for curators. The chapters in the next part follow the item types of the CPS Wikibase: artworks, paintings, photographs, films, materials, persons, and exhibitions with their catalogue. The following part connects the CPS data to Wikidata and the DNB, and the following parts document OCR extraction and data portability. The final part, #link("how-to.qmd")[A How-to], explains in three steps how to publish an exhibition as a public record on Wikidata.

== Copyright and licensing
<copyright-and-licensing>
All materials here are open-licensed unless otherwise stated and follow FAIR data principles and the UNESCO Recommendation on Open Science @unesco2021openscience.

#strong[Source catalogue.] The exhibition data is extracted from the printed catalogue #emph[Baldessari: while something is happening here, something else is happening there: works 1988--1999] (Köln: Verlag der Buchhandlung Walther König, 1999), ISBN #link("https://www.tib.eu/de/suchen/id/gwlb:302796398?cHash=d9b2700b8cf3934df61d65f43f2e6278")[978-3-88375-396-6], DNB record #link("https://d-nb.info/957409494"). Texts by Meg Cranston, Diedrich Diederichsen and Thomas Weski; published for the exhibition at the Sprengel Museum Hannover and the Staatliche Kunstsammlungen Dresden, Gemäldegalerie Neue Meister. The catalogue, including its texts, photographs and reproductions of the artworks, remains protected by copyright held by the publisher, authors, artist and other rights holders. It is not republished here: only factual catalogue data (such as titles, dates, materials, dimensions and catalogue numbers) is extracted, and no catalogue texts or images are reproduced. The bibliographic record is provided by the Deutsche Nationalbibliothek under #link("https://creativecommons.org/publicdomain/zero/1.0/")[CC0 1.0].

The project combines several licensing arrangements.

- The text, figures and generated content of this book are licensed under #link("https://creativecommons.org/licenses/by/4.0/")[CC BY 4.0]. The code is released under the MIT licence.
- The catalogue data extracted from the OCR work is released under #link("https://creativecommons.org/publicdomain/zero/1.0/")[CC0 1.0 Universal], so the underlying data may be reused without restriction for research, teaching and public scholarship. Data published on Wikidata is also CC0.
- For research use, this project also recognises that text and data mining (TDM) may be permitted under the UK and German legal frameworks for scientific research, including UK copyright exceptions and the German research exception in § 60d UrhG. These provisions are jurisdiction-specific and do not replace a review of any third-party rights or source-specific conditions.

== Acknowledgements
<acknowledgements>
#link("https://nfdi4culture.github.io/linked-open-exhibition/")[Linked Open Exhibitions]

#strong[Authors:] Simon Worthington (Hochschule Hannover -- University of Applied Sciences and Arts (HsH); TIB -- Leibniz Information Centre for Science and Technology and University Library) and Chloë Farr (TIB; University of Victoria).

A project made with the students of the Bachelor of Arts #link("https://f3.hs-hannover.de/en/courses/bachelor-studiengaenge/information-management-bim")[Information Management (BIM)] of Hannover University of Applied Sciences and Arts in partnership with the #link("https://nfdi4culture.de/services/details/computational-publishing-service.html")[Computational Publishing Service] from the Open Science Lab, #link("https://www.tib.eu/en/")[TIB] -- Leibniz Information Centre for Science and Technology and University Library, and with #link("https://www.nfdi4culture.de/")[NFDI4Culture] -- Consortium for Research Data on Material and Immaterial Cultural Heritage, as part of the National Research Data Infrastructure (NFDI).

#box(image("assets/logos/hsh-logo.png", alt: "Hochschule Hannover", width: 180px)) #box(image("assets/logos/tib-logo.png", alt: "TIB", width: 180px)) #box(image("assets/logos/nfdi4c-logo.jpg", alt: "NFDI4Culture", width: 180px))

= Introduction
<sec-introduction>
== Data sources
<data-sources>
#table(
  columns: (30.77%, 30.77%, 38.46%),
  align: (auto,auto,auto,),
  table.header([Source], [Access], [Used for],),
  table.hline(),
  [OCR catalogue extraction], [Notebook and CSV outputs from the linked-open-exhibition pipeline], [Structured artwork metadata extracted from scanned catalogue pages],
  [CPS Wikibase], [SPARQL, #NormalTok("https://cps.tibwiki.io/query/proxy/sparql");], [Works, materials, persons, exhibition, catalogue],
  [Wikidata], [SPARQL, #NormalTok("https://query.wikidata.org/sparql");], [Context about the artist and linked entities],
  [DNB], [SRU, #NormalTok("https://services.dnb.de/sru/dnb"); (MARC21-xml)], [Publications by and about the artist],
)
All queries are stored as #NormalTok(".rq"); files in #NormalTok("src/baldessari/queries/"); or as strings in the Python package #NormalTok("baldessari");, so they can be reused outside the book.

== Data model of the CPS Wikibase
<data-model-of-the-cps-wikibase>
Each CPS item has one or more #emph[types] (property P3). An item can carry several types at once: a work may be both an #emph[artwork] and a #emph[painting]. The figures below therefore count items per type and do not add up to the total number of items.

#figure([
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Type], [Items],),
  table.hline(),
  [artwork], [73],
  [material], [33],
  [painting], [21],
  [photograph], [19],
  [Super-8 film loop (originally 16 mm)], [13],
  [object type], [12],
  [person], [5],
  [film loop], [4],
  [Super-8 film loop], [4],
  [Super-8 film], [3],
  [wallpaper], [2],
  [exhibition], [2],
  [place], [2],
  [illustration], [1],
  [video loop], [1],
  [16 mm film], [1],
  [catalogue], [1],
  [organization], [1],
)
], caption: figure.caption(
position: top, 
[
Number of CPS items per type.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-types>


#figure([
#box(image("introduction_files/figure-typst/fig-types-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
Number of CPS items per type.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-types>


#ref(<tbl-types>, supplement: [Table]) and #ref(<fig-types>, supplement: [Figure]) show how the knowledge graph is composed. The CPS data describe a catalogue of works together with the materials and persons needed to describe them.

== Catalogue used as a source
<catalogue-used-as-a-source>
Much of the data was derived from the exhibition catalogue #cite(<baldessari1999>, form: "prose") through OCR-assisted extraction and curation. The catalogue is itself an item in the CPS Wikibase and is linked to the DNB (see #ref(<sec-dnb>, supplement: [Chapter])).

#part[Exhibition]
= Public catalogue
<sec-exhibition-catalogue>
This part of the book presents the exhibition itself: where and when it was shown, the artist, the catalogue that accompanied it, and the works, with a mark for each work that was on view.

== Exhibition
<exhibition-1>
#block[
#emph[BALDESSARI : While something is happening here, something else is happening there : Works 1988--1999]

Venue
Dates
Works on view
Wikidata
Sprengel Museum Hannover
26 September 1999 -- 2 January 2000
35
#link("https://www.wikidata.org/wiki/Q141747732")[View on Wikidata]
Staatliche Kunstsammlungen Dresden, Galerie Neue Meister
15 January 2000 -- 2 April 2000
35
#link("https://www.wikidata.org/wiki/Q142068274")[View on Wikidata]
#block[
#callout(
body: 
[
The exhibition is also described in Wikidata, the free knowledge base. Follow the link to see its open, reusable record:

- #link("https://www.wikidata.org/wiki/Q141747732")[Sprengel Museum Hannover]
- #link("https://www.wikidata.org/wiki/Q142068274")[Staatliche Kunstsammlungen Dresden, Galerie Neue Meister]

]
, 
title: 
[
Find the exhibition on Wikidata
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
] <exhibition-info>
== Artist
<artist>
#block[
#strong[John Baldessari] (#link("https://www.wikidata.org/wiki/Q683378")[Wikidata])

- #strong[Born:] 17 June 1931, National City
- #strong[Died:] 2 January 2020, Venice
- #strong[Nationality:] United States
- #strong[Works as:] architect, conceptual artist, draftsperson, illustrator, installation artist, painter, photographer, printmaker, sculptor, video artist
- #strong[Studied at:] San Diego State University; University of California, Berkeley
- #strong[Awards:] Fellow of the American Academy of Arts and Sciences; Goslarer Kaiserring; Guggenheim Fellowship; Spectrum -- Internationaler Preis für Fotografie

] <artist-info>
== Book catalogue
<book-catalogue>
#block[
- #strong[Title:] BALDESSARI : While something is happening here, something else is happening there : Works 1988--1999
- #strong[Authors:] Thomas Weski; Diedrich Diederichsen; Meg Cranston
- #strong[Publisher:] König
- #strong[Year:] 1999
- #strong[ISBN:] 978-3-88375-396-6

] <catalogue-info>
== Artworks
<artworks>
#block[
The catalogue documents #strong[73 works]. #strong[35] of them were on view in the exhibition (marked ✓); the other 38 are reproduced in the catalogue only.

#block[
Title
Year
Medium
Size (cm)
Exhibited
Duck Pond Bar, National City, California
1967
Acrylic and photoemulsion on canvas
152 × 170
--
Isocephaly
1968
color
--
What To Leave Out
1968
color
--
Black Curtain
1970
black-and-white; sound
--
Black Painting
1970
black-and-white; sound
--
Cremation
1970
black-and-white; sound
--
Folding Hat
1970
black-and-white; sound
--
Folding Hat: Version 1
1970
black-and-white; sound
--
Life Drawing
1970
black-and-white; sound
--
Proust
1970
16 mm; color
--
Black-Out
1971
black-and-white; sound
--
New York City Art History
1971
color
--
Police Drawing
1971
color; sound
--
Easel Painting
1972
color
--
Inventory
1972
black-and-white
--
Teaching A Plant The Alphabet
1972
color; sound
--
The Eye Does Not Naturally Pan
1972
black-and-white; sound
--
The Hollywood Film
1972
color; sound
--
Time-Temperature
1972
color
--
Walking Forward Running Past
1972
color
--
Water To Wine To Water
1972
color
--
How We Do Art Now
1973
black-and-white; sound
--
Throwing Leaves Back At Tree
1973
color; sound
--
Ice Cubes Sliding
1974
color
--
Taking A Slate: David
1974
black-and-white; sound
--
Taking A Slate: Ilene And David (\#2)
1974
black-and-white; sound
--
The Italian Tape
1974
color
--
Two Colorful Melodies
1977
sound
--
Goya Series: These Too
1978
--
The Life and Opinions of Tristan Shandy, Gentleman
1978
--
Box (Blind Fate and Culture)
1987
Black and white photographs, acrylic
122 × 122
--
Team
1987
Color and black and white photographs, acrylic, metallic paper
156 × 225
--
Hands/Feet
1988
Black and white photographs
244 × 267
--
Man Running/Men Carrying Box
1988
Black and white photographs, vinyl paint, oil tint
123 × 268
✓ Both venues
Six Ways To Pronounce Fiddles Tick (For L. Sterne)
1988
Oil stain on gelatin silver photographs mounted on aluminium
305 × 406
✓ Both venues
Size /Shape (Destiny)
1988
Black and white photographs
198 × 259
--
Tetrad Series: Real Shadows
1989
Digital printing; hand lettering; acrylic paint on canvas
239 × 239
✓ Both venues
Three Active Persons / With Standing Person
1990
Color photographs, vinyl paint
234 × 147
✓ Both venues
Two Voided Books
1990
Black and white photographs, vinyl paint
157 × 245
✓ Both venues
Telephone (For Kafka)
1991
Color photograph, black and white photograph, vinyl paint
243 × 488
✓ Both venues
Flying Saucer: Rainbow/Two Cyclists/ Dog/Gorilla And Bananas/Chaotic Situation / Couple/Tortoise/Gunman (Fallen)
1992
Color photographs, black and white photographs, acrylic paint, Masonite
259 × 411
✓ Both venues
Four Fabrics (Patterned): Two Glasses/ Passers-By
1992
Color photographs, black and white photographs, oil tint, Masonite
250 × 219
✓ Both venues
Man With Handlebar Mustache/ Two Branches (With Black Intrusion)
1992
Color photograph, black and white photograph, photocopy on Gandhi Ashram paper, acrylic wash, paper stickers, crayon, oil enamel on rubber, oil enamel on formica, mounted on Masonite
210 × 249
✓ Both venues
The Phone Call: Faceless Man (Orange) With Glasses / Entanglement Of Worms
1992
Color photographs, acrylic paint, crayon
203 × 119
✓ Both venues
Potatoes, Face (Smiling), Garbage Can, Landscape, Four Shapes + Red And Green Lines
1994
Color photograph, black and white photograph, acrylic, oil pastel and pencil on paper
166 × 215
✓ Both venues
Pointing Hand, Desk, Lights, And Observers (Courtroom)
1995
Black and white photographs, color photographs, acrylic, oil stick, pencil on paper
255 × 229
✓ Both venues
Three Running Figures (One Splashed). Trash Cans, And Poles (With Large Blue Shape)
1995
Black and white photographs, color photographs, acrylic, oil stick, pencil on paper
193 × 106
✓ Both venues
1121 East Second Street, National City, Calif.
1996
Acrylic and photoemulsion on canvas
150 × 114
✓ Both venues
Arrive (With Motives And Reasons)
1996
Color photographs, acrylic paint, crayon
235 × 327
✓ Both venues
Earl Scheib Auto Painting, 111 National City Blvd., National City, Calif.
1996
Acrylic and photoemulsion on canvas
150 × 114
✓ Both venues
Former Site Of Duck Pond Bar, 3003 National City Blvd., National City, Calif.
1996
Acrylic and photoemulsion on canvas
150 × 114
✓ Both venues
Lourdes Restaurant, 1125 National City Blvd., National City, Calif.
1996
Acrylic and photoemulsion on canvas
150 × 114
✓ Both venues
Pink Pig, Highland Ave., National City, Calif.
1996
Acrylic and photoemulsion on canvas
150 × 114
✓ Both venues
Star Theater, 4762 Ridgeway Drive, Lincoln Acres, National City, Calif.
1996
Acrylic and photoemulsion on canvas
150 × 114
✓ Both venues
Sunny Donuts, 724 Highland Avenue, National City, Calif.
1996
Acrylic and ink-jet on canvas
150 × 114
✓ Both venues
The Former Site Of Duck Pond Bar, 3003 National City Blvd., National City California
1996
Acrylic and photoemulsion on canvas
150 × 114
--
Goya Series: And
1997
Ink-jet print and hand lettering on canvas
190 × 152
✓ Both venues
Goya Series: As Is
1997
Ink-jet print and hand lettering on canvas
190 × 152
✓ Both venues
Goya Series: So Much And More
1997
Ink-jet print and hand lettering on canvas
190 × 152
✓ Both venues
Goya Series: Strange
1997
Ink jet on canvas
190 × 152
--
Goya Series: There Isn't Time
1997
Ink-jet print and hand lettering on canvas
190 × 152
✓ Both venues
Goya Series: These Too
1997
Ink-jet print and hand lettering on canvas
190 × 152
✓ Both venues
Lamp (Rotterdam \#3)
1997
Black and white photograph
183 × 183
✓ Both venues
Plant (Rotterdam \#3)
1997
Black and white photograph
183 × 183
✓ Both venues
Potato And Lightbulb
1997
wallpaper
--
Pretzel And Ear
1997
wallpaper
--
Elbow Series: Auk
1999
Ink-jet on canvas; Folio D process on vinyl; hand lettering and acrylic paint
213.5 × 213.5
✓ Both venues
Elbow Series: Emu
1999
Ink-jet on canvas, Folio D process on vinyl, hand lettering and acrylic paint
213.5 × 213.5
✓ Both venues
Elbow Series: Gnu
1999
Ink-jet on canvas; Folio D process on vinyl; hand lettering and acrylic paint
213.5 × 213.5
✓ Both venues
Elbow Series: Yak
1999
Ink-jet on canvas; Folio D process on vinyl; hand lettering and acrylic paint
213.5 × 213.5
✓ Both venues
Tetrad Series. All Getting On Together
1999
Digital printing; hand lettering; acrylic paint on canvas
239 × 239
✓ Both venues
Installation photograph of Lamp
✓ Both venues
Installation photograph of Plant
✓ Both venues
]
] <artwork-list>
== Download the exhibition data
<download-the-exhibition-data>
All the data shown on this page (exhibitions, catalogue and artworks) is available as a single download:

#strong[#link("downloads/baldessari-exhibition-data.zip")[Download the exhibition data (ZIP of CSV files)]]

The files open in Excel, Numbers or any spreadsheet. For the complete linked data behind the whole book, see #link("book-as-data.qmd")[Data Downloads].

#part[The CPS catalogue]
= Artworks
<sec-artworks>
This chapter is a Jupyter notebook. It queries the CPS Wikibase for all items of type #emph[artwork] (Q1) and shows how the data layer of this book works.

== Querying the CPS Wikibase
<querying-the-cps-wikibase>
The function #NormalTok("cps.artworks()"); sends a SPARQL query (#NormalTok("src/baldessari/queries/works.rq");) to the CPS endpoint and returns the result as a pandas #NormalTok("DataFrame");.

#Skylighting(([#ImportTok("from");#NormalTok(" pathlib ");#ImportTok("import");#NormalTok(" Path");],
[#ImportTok("import");#NormalTok(" sys");],
[#NormalTok("sys.path.insert(");#DecValTok("0");#NormalTok(", ");#BuiltInTok("str");#NormalTok("(Path.cwd() ");#OperatorTok("/");#NormalTok(" ");#StringTok("\"src\"");#NormalTok("))");],
[],
[#ImportTok("from");#NormalTok(" baldessari ");#ImportTok("import");#NormalTok(" cps, plots, table, works_table");],
[],
[#NormalTok("artworks ");#OperatorTok("=");#NormalTok(" cps.artworks()");],
[#NormalTok("artworks.shape");],));
#Skylighting(([#NormalTok("(73, 20)");],));
== All artworks
<all-artworks>
#figure([
#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header([ID], [Title], [Year], [Materials], [Size (cm)],),
  table.hline(),
  [Q89], [Installation photograph of Lamp], [], [], [],
  [Q90], [Installation photograph of Plant], [], [], [],
  [Q50], [Duck Pond Bar, National City, California], [1967.0], [canvas; acrylic paint; photoemulsion], [152 × 170],
  [Q99], [Isocephaly], [1968.0], [color], [],
  [Q102], [What To Leave Out], [1968.0], [color], [],
  [Q111], [Black Curtain], [1970.0], [sound; black-and-white], [],
  [Q109], [Black Painting], [1970.0], [sound; black-and-white], [],
  [Q103], [Cremation], [1970.0], [sound; black-and-white], [],
  [Q107], [Folding Hat], [1970.0], [sound; black-and-white], [],
  [Q106], [Folding Hat: Version 1], [1970.0], [sound; black-and-white], [],
  [Q112], [Life Drawing], [1970.0], [sound; black-and-white], [],
  [Q115], [Proust], [1970.0], [color; 16 mm], [],
  [Q108], [Black-Out], [1971.0], [sound; black-and-white], [],
  [Q104], [New York City Art History], [1971.0], [color], [],
  [Q118], [Police Drawing], [1971.0], [color; sound], [],
  [Q110], [Easel Painting], [1972.0], [color], [],
  [Q122], [Inventory], [1972.0], [black-and-white], [],
  [Q97], [Teaching A Plant The Alphabet], [1972.0], [color; sound], [],
  [Q105], [The Eye Does Not Naturally Pan], [1972.0], [sound; black-and-white], [],
  [Q117], [The Hollywood Film], [1972.0], [color; sound], [],
  [Q113], [Time-Temperature], [1972.0], [color], [],
  [Q114], [Walking Forward Running Past], [1972.0], [color], [],
  [Q116], [Water To Wine To Water], [1972.0], [color], [],
  [Q101], [How We Do Art Now], [1973.0], [sound; black-and-white], [],
  [Q119], [Throwing Leaves Back At Tree], [1973.0], [color; sound], [],
  [Q121], [Ice Cubes Sliding], [1974.0], [color], [],
  [Q100], [Taking A Slate: David], [1974.0], [sound; black-and-white], [],
  [Q98], [Taking A Slate: Ilene And David (\#2)], [1974.0], [sound; black-and-white], [],
  [Q120], [The Italian Tape], [1974.0], [color], [],
  [Q123], [Two Colorful Melodies], [1977.0], [color; sound], [],
  [Q56], [Goya Series: These Too], [1978.0], [], [],
  [Q57], [The Life and Opinions of Tristan Shandy, Gentleman], [1978.0], [], [],
  [Q58], [Box (Blind Fate and Culture)], [1987.0], [acrylic paint; black-and-white photograph], [122 × 122],
  [Q59], [Team], [1987.0], [acrylic paint; black-and-white photograph; color photograph; metallic paper], [156 × 225],
  [Q60], [Hands/Feet], [1988.0], [black-and-white photograph], [244 × 267],
  [Q62], [Man Running/Men Carrying Box], [1988.0], [black-and-white photograph; vinyl paint; oil tint], [123 × 268],
  [Q61], [Six Ways To Pronounce Fiddles Tick (For L. Sterne)], [1988.0], [oil stain; gelatin silver print; aluminium], [305 × 406],
  [Q52], [Size /Shape (Destiny)], [1988.0], [black-and-white photograph], [198 × 259],
  [Q95], [Tetrad Series: Real Shadows], [1989.0], [canvas; acrylic paint; hand lettering; digital printing], [239 × 239],
  [Q63], [Three Active Persons / With Standing Person], [1990.0], [color photograph; vinyl paint], [234 × 147],
  [Q64], [Two Voided Books], [1990.0], [black-and-white photograph; vinyl paint], [157 × 245],
  [Q65], [Telephone (For Kafka)], [1991.0], [black-and-white photograph; color photograph; vinyl paint], [243 × 488],
  [Q68], [Flying Saucer: Rainbow/Two Cyclists/ Dog/Gorilla And Bananas/Chaotic Situation / Couple/Tortoise/Gunman (Fallen)], [1992.0], [acrylic paint; black-and-white photograph; color photograph; Masonite], [259 × 411],
  [Q66], [Four Fabrics (Patterned): Two Glasses/ Passers-By], [1992.0], [black-and-white photograph; color photograph; oil tint; Masonite], [250 × 219],
  [Q69], [Man With Handlebar Mustache/ Two Branches (With Black Intrusion)], [1992.0], [acrylic paint; black-and-white photograph; color photograph; Masonite; crayon; photocopy; Gandhi Ashram paper; paper stickers; oil enamel; rubber; Formica], [210 × 249],
  [Q67], [The Phone Call: Faceless Man (Orange) With Glasses / Entanglement Of Worms], [1992.0], [acrylic paint; color photograph; crayon], [203 × 119],
  [Q70], [Potatoes, Face (Smiling), Garbage Can, Landscape, Four Shapes + Red And Green Lines], [1994.0], [acrylic paint; black-and-white photograph; color photograph; oil pastel; pencil; paper], [166 × 215],
  [Q71], [Pointing Hand, Desk, Lights, And Observers (Courtroom)], [1995.0], [acrylic paint; black-and-white photograph; color photograph; pencil; paper; oil stick], [255 × 229],
  [Q72], [Three Running Figures (One Splashed). Trash Cans, And Poles (With Large Blue Shape)], [1995.0], [acrylic paint; black-and-white photograph; color photograph; pencil; paper; oil stick], [193 × 106],
  [Q76], [1121 East Second Street, National City, Calif.], [1996.0], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q80], [Arrive (With Motives And Reasons)], [1996.0], [acrylic paint; color photograph; crayon], [235 × 327],
  [Q75], [Earl Scheib Auto Painting, 111 National City Blvd., National City, Calif.], [1996.0], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q74], [Former Site Of Duck Pond Bar, 3003 National City Blvd., National City, Calif.], [1996.0], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q77], [Lourdes Restaurant, 1125 National City Blvd., National City, Calif.], [1996.0], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q78], [Pink Pig, Highland Ave., National City, Calif.], [1996.0], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q79], [Star Theater, 4762 Ridgeway Drive, Lincoln Acres, National City, Calif.], [1996.0], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q73], [Sunny Donuts, 724 Highland Avenue, National City, Calif.], [1996.0], [canvas; acrylic paint; inkjet], [150 × 114],
  [Q51], [The Former Site Of Duck Pond Bar, 3003 National City Blvd., National City California], [1996.0], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q84], [Goya Series: And], [1997.0], [canvas; hand lettering; inkjet], [190 × 152],
  [Q82], [Goya Series: As Is], [1997.0], [canvas; hand lettering; inkjet], [190 × 152],
  [Q83], [Goya Series: So Much And More], [1997.0], [canvas; hand lettering; inkjet], [190 × 152],
  [Q55], [Goya Series: Strange], [1997.0], [canvas; inkjet], [190 × 152],
  [Q81], [Goya Series: There Isn\'t Time], [1997.0], [canvas; hand lettering; inkjet], [190 × 152],
  [Q85], [Goya Series: These Too], [1997.0], [canvas; hand lettering; inkjet], [190 × 152],
  [Q88], [Lamp (Rotterdam \#3)], [1997.0], [black-and-white photograph], [183 × 183],
  [Q86], [Plant (Rotterdam \#3)], [1997.0], [black-and-white photograph], [183 × 183],
  [Q53], [Potato And Lightbulb], [1997.0], [wallpaper], [],
  [Q54], [Pretzel And Ear], [1997.0], [wallpaper], [],
  [Q93], [Elbow Series: Auk], [1999.0], [canvas; acrylic paint; hand lettering; Folio D process; vinyl; inkjet], [213.5 × 213.5],
  [Q91], [Elbow Series: Emu], [1999.0], [canvas; acrylic paint; hand lettering; Folio D process; vinyl; inkjet], [213.5 × 213.5],
  [Q94], [Elbow Series: Gnu], [1999.0], [canvas; acrylic paint; hand lettering; Folio D process; vinyl; inkjet], [213.5 × 213.5],
  [Q92], [Elbow Series: Yak], [1999.0], [canvas; acrylic paint; hand lettering; Folio D process; vinyl; inkjet], [213.5 × 213.5],
  [Q96], [Tetrad Series. All Getting On Together], [1999.0], [canvas; acrylic paint; hand lettering; digital printing], [239 × 239],
)
], caption: figure.caption(
position: top, 
[
Artworks in the CPS Wikibase.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-artworks>


== Artworks over time
<artworks-over-time>
#figure([
#box(image("artworks_files/figure-typst/fig-artworks-per-year-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
Artworks by year of creation (five-year bins).
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-artworks-per-year>


#ref(<fig-artworks-per-year>, supplement: [Figure]) includes only the works with a recorded date of creation (P7).

== Object types as stated in the catalogue
<object-types-as-stated-in-the-catalogue>
The property #emph[Object type (as stated)] (P37) keeps the wording of the source catalogue.

#figure([
#box(image("artworks_files/figure-typst/fig-object-types-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
Most frequent object types as stated in the catalogue.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-object-types>


= Paintings
<sec-paintings>
Paintings are items of type #emph[painting] (Q15) in the CPS Wikibase. Most of them are also typed as #emph[artwork].

The CPS Wikibase contains #strong[21] paintings.

#figure([
#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header([ID], [Title], [Year], [Materials], [Size (cm)],),
  table.hline(),
  [Q50], [Duck Pond Bar, National City, California], [1967], [canvas; acrylic paint; photoemulsion], [152 × 170],
  [Q95], [Tetrad Series: Real Shadows], [1989], [canvas; acrylic paint; hand lettering; digital printing], [239 × 239],
  [Q76], [1121 East Second Street, National City, Calif.], [1996], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q75], [Earl Scheib Auto Painting, 111 National City Blvd., National City, Calif.], [1996], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q74], [Former Site Of Duck Pond Bar, 3003 National City Blvd., National City, Calif.], [1996], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q77], [Lourdes Restaurant, 1125 National City Blvd., National City, Calif.], [1996], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q78], [Pink Pig, Highland Ave., National City, Calif.], [1996], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q79], [Star Theater, 4762 Ridgeway Drive, Lincoln Acres, National City, Calif.], [1996], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q73], [Sunny Donuts, 724 Highland Avenue, National City, Calif.], [1996], [canvas; acrylic paint; inkjet], [150 × 114],
  [Q51], [The Former Site Of Duck Pond Bar, 3003 National City Blvd., National City California], [1996], [canvas; acrylic paint; photoemulsion], [150 × 114],
  [Q84], [Goya Series: And], [1997], [canvas; hand lettering; inkjet], [190 × 152],
  [Q82], [Goya Series: As Is], [1997], [canvas; hand lettering; inkjet], [190 × 152],
  [Q83], [Goya Series: So Much And More], [1997], [canvas; hand lettering; inkjet], [190 × 152],
  [Q55], [Goya Series: Strange], [1997], [canvas; inkjet], [190 × 152],
  [Q81], [Goya Series: There Isn\'t Time], [1997], [canvas; hand lettering; inkjet], [190 × 152],
  [Q85], [Goya Series: These Too], [1997], [canvas; hand lettering; inkjet], [190 × 152],
  [Q93], [Elbow Series: Auk], [1999], [canvas; acrylic paint; hand lettering; Folio D process; vinyl; inkjet], [213.5 × 213.5],
  [Q91], [Elbow Series: Emu], [1999], [canvas; acrylic paint; hand lettering; Folio D process; vinyl; inkjet], [213.5 × 213.5],
  [Q94], [Elbow Series: Gnu], [1999], [canvas; acrylic paint; hand lettering; Folio D process; vinyl; inkjet], [213.5 × 213.5],
  [Q92], [Elbow Series: Yak], [1999], [canvas; acrylic paint; hand lettering; Folio D process; vinyl; inkjet], [213.5 × 213.5],
  [Q96], [Tetrad Series. All Getting On Together], [1999], [canvas; acrylic paint; hand lettering; digital printing], [239 × 239],
)
], caption: figure.caption(
position: top, 
[
Paintings in the CPS Wikibase.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-paintings>


== Materials
<materials>
#figure([
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Material], [Paintings],),
  table.hline(),
  [canvas], [21],
  [acrylic paint], [15],
  [hand lettering], [11],
  [inkjet], [11],
  [photoemulsion], [8],
  [Folio D process], [4],
  [vinyl], [4],
  [digital printing], [2],
)
], caption: figure.caption(
position: top, 
[
Materials used for paintings, by number of paintings.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-painting-materials>


== Dimensions
<dimensions>
#figure([
#box(image("paintings_files/figure-typst/fig-painting-sizes-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
Height and width of paintings with recorded dimensions.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-painting-sizes>


#ref(<fig-painting-sizes>, supplement: [Figure]) plots the 21 paintings for which both height and width are recorded.

= Photographs
<sec-photographs>
Photographs are items of type #emph[photograph] (Q17).

The CPS Wikibase contains #strong[19] photographs.

#figure([
#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header([ID], [Title], [Year], [Materials], [Size (cm)],),
  table.hline(),
  [Q58], [Box (Blind Fate and Culture)], [1987], [acrylic paint; black-and-white photograph], [122 × 122],
  [Q59], [Team], [1987], [acrylic paint; black-and-white photograph; color photograph; metallic paper], [156 × 225],
  [Q60], [Hands/Feet], [1988], [black-and-white photograph], [244 × 267],
  [Q62], [Man Running/Men Carrying Box], [1988], [black-and-white photograph; vinyl paint; oil tint], [123 × 268],
  [Q61], [Six Ways To Pronounce Fiddles Tick (For L. Sterne)], [1988], [oil stain; gelatin silver print; aluminium], [305 × 406],
  [Q52], [Size /Shape (Destiny)], [1988], [black-and-white photograph], [198 × 259],
  [Q63], [Three Active Persons / With Standing Person], [1990], [color photograph; vinyl paint], [234 × 147],
  [Q64], [Two Voided Books], [1990], [black-and-white photograph; vinyl paint], [157 × 245],
  [Q65], [Telephone (For Kafka)], [1991], [black-and-white photograph; color photograph; vinyl paint], [243 × 488],
  [Q68], [Flying Saucer: Rainbow/Two Cyclists/ Dog/Gorilla And Bananas/Chaotic Situation / Couple/Tortoise/Gunman (Fallen)], [1992], [acrylic paint; black-and-white photograph; color photograph; Masonite], [259 × 411],
  [Q66], [Four Fabrics (Patterned): Two Glasses/ Passers-By], [1992], [black-and-white photograph; color photograph; oil tint; Masonite], [250 × 219],
  [Q69], [Man With Handlebar Mustache/ Two Branches (With Black Intrusion)], [1992], [acrylic paint; black-and-white photograph; color photograph; Masonite; crayon; photocopy; Gandhi Ashram paper; paper stickers; oil enamel; rubber; Formica], [210 × 249],
  [Q67], [The Phone Call: Faceless Man (Orange) With Glasses / Entanglement Of Worms], [1992], [acrylic paint; color photograph; crayon], [203 × 119],
  [Q70], [Potatoes, Face (Smiling), Garbage Can, Landscape, Four Shapes + Red And Green Lines], [1994], [acrylic paint; black-and-white photograph; color photograph; oil pastel; pencil; paper], [166 × 215],
  [Q71], [Pointing Hand, Desk, Lights, And Observers (Courtroom)], [1995], [acrylic paint; black-and-white photograph; color photograph; pencil; paper; oil stick], [255 × 229],
  [Q72], [Three Running Figures (One Splashed). Trash Cans, And Poles (With Large Blue Shape)], [1995], [acrylic paint; black-and-white photograph; color photograph; pencil; paper; oil stick], [193 × 106],
  [Q80], [Arrive (With Motives And Reasons)], [1996], [acrylic paint; color photograph; crayon], [235 × 327],
  [Q88], [Lamp (Rotterdam \#3)], [1997], [black-and-white photograph], [183 × 183],
  [Q86], [Plant (Rotterdam \#3)], [1997], [black-and-white photograph], [183 × 183],
)
], caption: figure.caption(
position: top, 
[
Photographs in the CPS Wikibase.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-photographs>


== Works per period
<works-per-period>
#figure([
#box(image("photographs_files/figure-typst/fig-photos-per-year-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
Photographs by year of creation (five-year bins).
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-photos-per-year>


= Films
<sec-films>
The CPS Wikibase distinguishes several film and video types, such as #emph[Super-8 film loop], #emph[film loop], #emph[16 mm film] and #emph[video loop]. This chapter groups them together.

The CPS Wikibase contains #strong[26] works of a film or video type.

#figure([
#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header([ID], [Title], [Year], [Materials], [Size (cm)],),
  table.hline(),
  [Q99], [Isocephaly], [1968], [color], [],
  [Q102], [What To Leave Out], [1968], [color], [],
  [Q111], [Black Curtain], [1970], [sound; black-and-white], [],
  [Q109], [Black Painting], [1970], [sound; black-and-white], [],
  [Q103], [Cremation], [1970], [sound; black-and-white], [],
  [Q107], [Folding Hat], [1970], [sound; black-and-white], [],
  [Q106], [Folding Hat: Version 1], [1970], [sound; black-and-white], [],
  [Q112], [Life Drawing], [1970], [sound; black-and-white], [],
  [Q115], [Proust], [1970], [color; 16 mm], [],
  [Q108], [Black-Out], [1971], [sound; black-and-white], [],
  [Q104], [New York City Art History], [1971], [color], [],
  [Q110], [Easel Painting], [1972], [color], [],
  [Q122], [Inventory], [1972], [black-and-white], [],
  [Q97], [Teaching A Plant The Alphabet], [1972], [color; sound], [],
  [Q105], [The Eye Does Not Naturally Pan], [1972], [sound; black-and-white], [],
  [Q117], [The Hollywood Film], [1972], [color; sound], [],
  [Q113], [Time-Temperature], [1972], [color], [],
  [Q114], [Walking Forward Running Past], [1972], [color], [],
  [Q116], [Water To Wine To Water], [1972], [color], [],
  [Q101], [How We Do Art Now], [1973], [sound; black-and-white], [],
  [Q119], [Throwing Leaves Back At Tree], [1973], [color; sound], [],
  [Q121], [Ice Cubes Sliding], [1974], [color], [],
  [Q100], [Taking A Slate: David], [1974], [sound; black-and-white], [],
  [Q98], [Taking A Slate: Ilene And David (\#2)], [1974], [sound; black-and-white], [],
  [Q120], [The Italian Tape], [1974], [color], [],
  [Q123], [Two Colorful Melodies], [1977], [color; sound], [],
)
], caption: figure.caption(
position: top, 
[
Films and video works in the CPS Wikibase.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-films>


== Film types
<film-types>
#figure([
#box(image("films_files/figure-typst/fig-film-types-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
Number of film and video works per type.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-film-types>


= Materials
<sec-materials>
Materials are items of type #emph[material] (Q5). Works link to them with the property #emph[Material] (P10). Where available, materials are connected to Wikidata (P24) or the Art & Architecture Thesaurus (P26).

The CPS Wikibase describes #strong[33] materials, of which #strong[33] are used by at least one work.

#figure([
#box(image("materials_files/figure-typst/fig-materials-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
The most frequently used materials.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-materials>


#figure([
#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header([ID], [Material], [Works], [Wikidata], [AAT],),
  table.hline(),
  [Q11], [acrylic paint], [24], [Q207849], [],
  [Q10], [canvas], [21], [Q4259259], [],
  [Q198], [sound], [16], [], [],
  [Q18], [black-and-white photograph], [15], [], [],
  [Q197], [color], [15], [], [],
  [Q199], [black-and-white], [12], [], [],
  [Q22], [color photograph], [11], [], [],
  [Q41], [hand lettering], [11], [], [],
  [Q9], [inkjet], [11], [Q130443678], [],
  [Q16], [photoemulsion], [8], [], [],
  [Q42], [Folio D process], [4], [], [],
  [Q43], [vinyl], [4], [], [],
  [Q27], [vinyl paint], [4], [Q2135874], [],
  [Q29], [Masonite], [3], [], [],
  [Q30], [crayon], [3], [], [],
  [Q39], [paper], [3], [], [],
  [Q38], [pencil], [3], [], [],
  [Q44], [digital printing], [2], [], [],
  [Q40], [oil stick], [2], [Q7081466], [],
  [Q28], [oil tint], [2], [], [],
  [Q20], [wallpaper], [2], [Q191529], [],
  [Q203], [16 mm], [1], [], [],
  [Q36], [Formica], [1], [], [],
  [Q32], [Gandhi Ashram paper], [1], [], [],
  [Q26], [aluminium], [1], [], [],
  [Q25], [gelatin silver print], [1], [Q64029133], [],
  [Q23], [metallic paper], [1], [], [],
  [Q34], [oil enamel], [1], [], [],
  [Q37], [oil pastel], [1], [], [],
  [Q24], [oil stain], [1], [], [],
  [Q33], [paper stickers], [1], [], [],
  [Q31], [photocopy], [1], [], [],
  [Q35], [rubber], [1], [], [],
)
], caption: figure.caption(
position: top, 
[
Materials, number of works and external identifiers.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-materials>


= Persons
<sec-persons>
Persons are items of type #emph[person] (Q2). They are creators (P6) of works or authors (P40) of the catalogue, and can be linked to Wikidata (P24) and the Gemeinsame Normdatei (GND, P25).

#figure([
#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header([ID], [Name], [Works created], [Wikidata], [GND],),
  table.hline(),
  [Q47], [John Baldessari], [72], [Q683378], [118506153],
  [Q48], [Laurence Sterne], [1], [Q218960], [11861794X],
  [Q209], [Diedrich Diederichsen], [0], [Q101521], [130448001],
  [Q208], [Meg Cranston], [0], [Q6807973], [119555522],
  [Q210], [Thomas Weski], [0], [Q93431275], [119093022],
)
], caption: figure.caption(
position: top, 
[
Persons in the CPS Wikibase with their identifiers.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-persons>


= Exhibitions and catalogue
<sec-exhibitions>
The CPS Wikibase records exhibitions (type Q3) and the catalogue (type Q205) that documents them. Works are linked to exhibitions with #emph[Exhibited at] (P21) and to the catalogue with #emph[Appears in catalogue] (P48). The catalogue statement can carry a #emph[Scan page] qualifier (P49) that points to the page of a digitised copy.

== Exhibition
<exhibition-2>
#figure([
#table(
  columns: 7,
  align: (auto,auto,auto,auto,auto,auto,auto,),
  table.header([ID], [Exhibition], [Host], [Start], [End], [Works], [Wikidata],),
  table.hline(),
  [Q213], [BALDESSARI : While something is happening here, something else is happening there : Works 1988--1999], [Staatliche Kunstsammlungen Dresden, Galerie Neue Meister], [2000-01-15], [2000-04-02], [35], [],
  [Q49], [BALDESSARI : While something is happening here, something else is happening there : Works 1988--1999], [Sprengel Museum Hannover], [1999-09-26], [2000-01-02], [35], [Q141747732],
)
], caption: figure.caption(
position: top, 
[
Exhibitions in the CPS Wikibase.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-exhibitions>


== Catalogue
<catalogue>
#figure([
#table(
  columns: 7,
  align: (auto,auto,auto,auto,auto,auto,auto,),
  table.header([ID], [Title], [Authors], [Publisher], [Year], [ISBN-13], [DNB ID],),
  table.hline(),
  [Q211], [BALDESSARI : While something is happening here, something else is happening there : Works 1988--1999], [Thomas Weski; Diedrich Diederichsen; Meg Cranston], [König], [1999], [978-3-88375-396-6], [957409494],
)
], caption: figure.caption(
position: top, 
[
Catalogue records in the CPS Wikibase.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-catalogue>


== Works and catalogue pages
<works-and-catalogue-pages>
#strong[70] work-to-exhibition links are recorded. For #strong[0] of them a scan page in the catalogue has been recorded so far.

#part[External sources]
= Wikidata
<sec-wikidata>
CPS items can be linked to Wikidata with the property #emph[Wikidata item] (P24). This chapter lists those links and uses Wikidata to describe John Baldessari.

== Links from the CPS Wikibase
<links-from-the-cps-wikibase>
#strong[22] CPS items point to Wikidata.

#figure([
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([CPS ID], [Label], [Types], [Wikidata],),
  table.hline(),
  [Q49], [BALDESSARI : While something is happening here, something else is happening there : Works 1988--1999], [exhibition], [Q141747732],
  [Q209], [Diedrich Diederichsen], [person], [Q101521],
  [Q47], [John Baldessari], [person], [Q683378],
  [Q48], [Laurence Sterne], [person], [Q218960],
  [Q208], [Meg Cranston], [person], [Q6807973],
  [Q14], [Sprengel Museum Hannover], [place], [Q510144],
  [Q212], [Staatliche Kunstsammlungen Dresden, Galerie Neue Meister], [place], [Q472706],
  [Q210], [Thomas Weski], [person], [Q93431275],
  [Q11], [acrylic paint], [material], [Q207849],
  [Q10], [canvas], [material], [Q4259259],
  [Q8], [centimetre], [], [Q174728],
  [Q25], [gelatin silver print], [material], [Q64029133],
  [Q21], [illustration], [object type], [Q178659],
  [Q9], [inkjet], [material], [Q130443678],
  [Q13], [mixed media], [object type], [Q1902763],
  [Q40], [oil stick], [material], [Q7081466],
  [Q15], [painting], [object type], [Q3305213],
  [Q17], [photograph], [object type], [Q125191],
  [Q12], [print], [object type], [Q11060274],
  [Q27], [vinyl paint], [material], [Q2135874],
  [Q20], [wallpaper], [material], [Q191529],
  [Q19], [wallpaper], [object type], [Q191529],
)
], caption: figure.caption(
position: top, 
[
CPS items linked to Wikidata.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-wikidata-links>


== John Baldessari on Wikidata
<john-baldessari-on-wikidata>
#figure([
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Property], [Value],),
  table.hline(),
  [award received], [Fellow of the American Academy of Arts and Sciences; Goslarer Kaiserring; Guggenheim Fellowship; Spectrum -- Internationaler Preis für Fotografie],
  [country of citizenship], [United States],
  [date of birth], [1931-06-17],
  [date of death], [2020-01-02],
  [educated at], [San Diego State University; University of California, Berkeley],
  [movement], [contemporary art],
  [occupation], [architect; conceptual artist; draftsperson; illustrator; installation artist; painter; photographer; printmaker; sculptor; video artist],
  [place of birth], [National City],
  [place of death], [Venice],
)
], caption: figure.caption(
position: top, 
[
Selected Wikidata statements about John Baldessari (Q683378).
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-wikidata-profile>


== Entities referenced by the CPS data
<entities-referenced-by-the-cps-data>
#figure([
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Wikidata], [Label], [Description],),
  table.hline(),
  [Q101521], [Diedrich Diederichsen], [German author, journalist and cultural critic (born 1957)],
  [Q218960], [Laurence Sterne], [Anglo-Irish novelist and Anglican cleric (1713--1768)],
  [Q683378], [John Baldessari], [American artist (1931--2020)],
  [Q6807973], [Meg Cranston], [American artist (born 1960)],
  [Q93431275], [Thomas Weski], [],
  [Q472706], [Galerie Neue Meister], [art museum in Dresden, Germany; part of Staatliche Kunstsammlungen Dresden],
  [Q141747732], [BALDESSARI : While something is happening here, something else is happening there : Works 1988--1999], [An art exhibition by the artists John Baldessari at the Sprengel-Museum Hannover, 26.9.1999--2.1.2000],
  [Q174728], [centimetre], [SI unit of length equal to one hundredth of a metre],
  [Q191529], [wallpaper], [material used to cover and decorate interior walls],
  [Q7081466], [Oil stick], [art medium],
  [Q207849], [acrylic paint], [type of fast-drying paint that consists of pigments or dyes bound in an emulsion of acrylic],
  [Q510144], [Sprengel Museum], [art museum in Hannover, Germany],
  [Q2135874], [vinyl paint], [water-based paint that contains vinyl resins],
  [Q1902763], [mixed media], [artistic technique that uses more than one medium],
  [Q11060274], [print], [work of art printed from a block or plate],
  [Q3305213], [painting], [visual artwork, surface artistically covered with paint],
  [Q125191], [photograph], [image created by light falling on a light-sensitive surface],
  [Q178659], [illustration], [graphic image printed with or inserted in the text of a publication as an embellishment or to complement or elucidate the text],
  [Q4259259], [canvas], [extremely heavy-duty plain-woven fabric],
  [Q64029133], [gelatin silver print], [type of photographic print made using gelatin silver process],
  [Q130443678], [inkjet print], [printing made with an inkjet printer, which uses a computer-controlled, non-impact printing process in which tiny droplets of ink are projected from the nozzles onto the paper],
)
], caption: figure.caption(
position: top, 
[
Descriptions of Wikidata entities referenced from CPS.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-wikidata-entities>


= Deutsche Nationalbibliothek
<sec-dnb>
The DNB catalogue is queried through its SRU interface. The CPS catalogue item carries a #emph[DNB edition ID] (P44) and the artist has a #emph[GND ID] (P25).

== The catalogue record
<the-catalogue-record>
#figure([
#table(
  columns: 7,
  align: (auto,auto,auto,auto,auto,auto,auto,),
  table.header([DNB ID], [Title], [Subtitle], [Place], [Publisher], [Year], [ISBN],),
  table.hline(),
  [957409494], [Baldessari], [while something is happening here, something else is happening there \; works 1988 - 1999 \; Spectrum - Internationaler Preis für Fotografie der Stiftung Niedersachsen \; \[Sprengel-Museum Hannover, 26.9.1999 - 2.1.2000 und Staatliche Kunstsammlungen Dresden, Gemäldegalerie Neue Meister, 15.1. - 2.4.2000\]], [Köln], [König], [1999], [9783883753966],
)
], caption: figure.caption(
position: top, 
[
DNB record of the catalogue that is described in the CPS Wikibase.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-dnb-record>


== Publications by and about John Baldessari
<publications-by-and-about-john-baldessari>
A search for the person heading #emph[Baldessari, John] returns #strong[40] records.

#figure([
#box(image("dnb_files/figure-typst/fig-dnb-years-output-1.png"))
], caption: figure.caption(
position: bottom, 
[
DNB records for John Baldessari by year of publication (five-year bins).
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-dnb-years>


#figure([
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([Year], [Title], [Publisher], [ISBN],),
  table.hline(),
  [2024], [John Baldessari Ahmedabad 1992], [Sprüth Magers], [9783753307176],
  [2021], [The space between], [Verlag der Buchhandlung Walther und Franz König], [9783960988304],
  [2020], [John Baldessari], [Koenig Books], [9783960987956],
  [2017], [Learning To Read with John Baldessari], [JRP Ringier Kunstverlag], [9783037645185],
  [2015], [The Städel paintings], [Hirmer], [9783777424491],
  [2014], [Museum of the Future], [JRP Ringier Kunstverlag], [9783037643839],
  [2012], [Baldessari sings LeWitt], [Rollo Press], [],
  [2012], [John Baldessari], [Distanz], [9783954760039],
  [2012], [Julião Sarmento], [Hatje Cantz], [9783775735292],
  [2012], [Julião Sarmento], [Hatje Cantz], [9783775735308],
  [2010], [Riss - Lücke - Scharnier A], [Scheidegger & Spiess], [9783858813015],
  [2009], [John Baldessari - Hans Ulrich Obrist], [König], [9783865605009],
  [2009], [John Baldessari], [Kerber], [9783866783065],
  [2009], [Miracle chips], [Little Steidl], [9783865216779],
  [2009], [Pure beauty - John Baldessari], [Prestel], [9783791343457],
  [2008], [Kavalierstart], [DuMont], [9783832190972],
  [2007], [Music], [König], [9783865602480],
  [2007], [Retrospective], [König], [9783865603449],
  [2007], [Again the Metaphor Problem and Other Engaged Critical Discourses about Art], [Springer Vienna], [9783211692998],
  [2007], [Again the metaphor problem and other engaged critical discourses about art], [Springer], [9783211298213],
  [2006], [A walk to remember], [Revolver], [9783865882240],
  [2006], [From fact to fiction], [Lang], [9783631543467],
  [2006], [Liam Gillick, Lawrence Weiner, John Baldessari], [Springer Wien], [9783211298213],
  [2006], [Prima facie: Marilyn\'s dress], [König], [9783865600882],
  [2005], [John Baldessari], [König], [9783902490100],
)
], caption: figure.caption(
position: top, 
[
Most recent DNB records for John Baldessari.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-dnb-publications>


#part[Catalogue OCR]
= Data Extraction
<data-extraction>
This section documents the OCR + LLM workflow used to extract structured artwork data from scanned exhibition catalogues. It is included here as project context for the Baldessari book and for future reuse with additional catalogues.

== Source Material
<source-material>
The extraction workflow and its implementation are documented in the linked-open-exhibition repository:

- Notebook: #link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/catalogues/catalogue-extraction/catalogue-ocr-llm-extraction.ipynb")[catalogue-ocr-llm-extraction.ipynb]
- Method notes: #link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/catalogues/catalogue-extraction/README.md")[README.md]
- Example output data: #link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/catalogues/catalogue-extraction/demo/baldessari-sprengel-artworks.csv")[baldessari-sprengel-artworks.csv]

== What the Workflow Produces
<what-the-workflow-produces>
For a catalogue PDF, the workflow produces a structured CSV of extracted artworks and related metadata. It combines:

- OCR on scanned pages
- LLM-assisted segmentation and field extraction
- quality checks and review markers for uncertain rows

The output can be used as a curated input for downstream integration into cultural heritage knowledge graphs and catalogue pipelines.

== Notes for This Book
<notes-for-this-book>
- This chapter is intentionally focused on method documentation and provenance.
- Additional OCR-derived pages can be added to this part of the book later.
- The implementation details remain maintained in the linked-open-exhibition repository referenced above.

#part[Book as data]
= Data Downloads
<data-downloads>
This chapter presents the data portability layer used to make the exhibition data reusable outside Wikibase. The model is based on the ER model and pipeline documented in the linked-open-exhibition portability work.

Source page:

- #link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/data-models/portability/er-model.qmd")[Entity-relationship model (er-model.qmd)]

== What is included
<what-is-included>
The data model combines:

- a conceptual ER model of entities and relationships
- a SQLite Entity-Attribute-Value (EAV) representation for querying and validation
- an XML export validated against a DTD
- a Turtle RDF export from the CPS Wikibase

Together, these files provide a portable representation of the dataset that can be inspected, queried, and reused in other workflows.

== Download the full dataset used for this book
<download-the-full-dataset-used-for-this-book>
The following files contain the full data used to build this book:

- #link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/data-models/portability/linked-open-exhibition.sqlite?raw=1")[SQLite database (linked-open-exhibition.sqlite)]
- #link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/data-models/portability/linked-open-exhibition.xml?raw=1")[XML export (linked-open-exhibition.xml)]
- #link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/data-models/portability/cps.ttl?raw=1")[Turtle RDF export (cps.ttl)]

If you want to regenerate the Turtle file directly from Wikibase, use:

- #link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/data-models/portability/dump_cps_rdf.py")[RDF export script (dump\_cps\_rdf.py)]
- #link("https://github.com/NFDI4Culture/linked-open-exhibition/tree/main/data-models/portability")[Portability folder]

The XML file can be opened and explored with XML Notepad.

- XML Notepad download: #link("https://github.com/microsoft/XmlNotepad/releases")

== Why this matters
<why-this-matters>
Publishing the same content in both SQLite and XML supports different audiences and tools:

- SQLite is practical for data analysis and reproducible queries.
- XML is practical for archival exchange and structured inspection.

This portability layer helps ensure that the exhibition knowledge in this book remains transparent, verifiable, and reusable.

== Explore the live Wikibase data
<explore-the-live-wikibase-data>
You can also explore the live CPS Wikibase data directly:

- #link("https://cps.tibwiki.io/")[CPS Wikibase]
- #link("https://cps.tibwiki.io/query/proxy/sparql")[SPARQL endpoint]
- #link("https://cps.tibwiki.io/wiki/Special:EntityData")[EntityData export (RDF formats)]

#part[A How-to]
= Publishing exhibition records
<sec-how-to>
This how-to shows, in three steps, how to turn an exhibition into a public record that anyone can query: connect the artworks to the exhibition, fill in the data fields, and upload the result to Wikidata via CPS. John Baldessari's exhibition #emph[While something is happening here, something else is happening there] is used as the running example.

+ #strong[Concept:] connect each artwork to the exhibition it was part of.
+ #strong[Data:] fill in the fields for the artwork, the exhibition, the catalogue and the artist.
+ #strong[Upload:] publish the data on Wikidata and link it back to the CPS Wikibase.

== Step 1: The concept of a public record
<sec-howto-concept>
A public record of an exhibition answers one question in a way that people and machines can both read: #emph[which artworks were shown, where and when, and where is it documented?]

The core of the record is a single connection between an #strong[artwork] and an #strong[exhibition]. In the CIDOC Conceptual Reference Model this connection is the property #strong[P9i #emph[forms part of]]: the artwork's presentation is a part of the exhibition, which is made up of many such parts (the inverse property, P9, reads #emph[consists of]). In the CPS Wikibase the connection is stored on the artwork as the property #strong[Exhibited at] (P21), which is mapped to CIDOC P9i and to Wikidata #strong[P608 #emph[exhibition history]].

Three further connections complete the record. The exhibition points to its #strong[catalogue], the catalogue documents the exhibition and the artworks (CIDOC #strong[P70i #emph[is documented in]]), and the #strong[artist] is recorded as the creator of each artwork.

#figure([
#box(image("how-to_files/figure-typst/fig-howto-p9i-output-1.png", alt: "Diagram with four boxes. The artist is connected to the artwork as creator. The artwork is connected to the exhibition with P9i forms part of. The exhibition and the artwork are both connected to the catalogue with P70i is documented in."))
], caption: figure.caption(
position: bottom, 
[
The exhibition record. Each artwork is connected to the exhibition with CIDOC P9i #emph[forms part of] (highlighted); the catalogue documents both.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-howto-p9i>


#block[
#callout(
body: 
[
The same connection has a different name in each system. CIDOC CRM: #strong[P9i] #emph[forms part of]. CPS Wikibase: #strong[P21] #emph[Exhibited at]. Wikidata: #strong[P608] #emph[exhibition history]. The CPS Wikibase stores the mapping, so data entered once can be published in the others.

]
, 
title: 
[
In CPS and in Wikidata
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Step 2: Fill in the data fields
<sec-howto-fields>
Only a small set of fields is needed to make a usable public record. Fill them in for the four kinds of record: artist, exhibition, catalogue and artwork. The type of each record (#emph[instance of]) is given by the kind of record, so you do not enter it.

#block[
#callout(
body: 
[
All fields below are ready to fill in as a spreadsheet with one sheet per kind of record, example rows, and drop-down lists that keep the records connected.

#strong[#link("downloads/baldessari-exhibition-template.xlsx")[Download the exhibition record template (Excel)]]

]
, 
title: 
[
Spreadsheet template
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Artist
<artist-1>
The artist usually exists already. Search first, then reuse the existing record instead of creating a new one.

#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header([Field], [What to enter], [Example], [CPS], [Wikidata],),
  table.hline(),
  [Name], [Name as commonly written], [John Baldessari], [label], [label],
  [Wikidata ID], [Optional. Existing Wikidata item], [Q683378], [P24], [],
)
=== Exhibition
<exhibition-3>
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Field], [What to enter], [Example], [CPS], [Wikidata],),
  table.hline(),
  [Title], [Title of the exhibition], [BALDESSARI : While something is happening here … : Works 1988--1999], [P5], [P1476],
  [Start date], [First day, as YYYY-MM-DD], [1999-09-26], [P27], [P580],
  [End date], [Last day, as YYYY-MM-DD], [2000-01-02], [P28], [P582],
  [Location], [Venue where it was shown], [Sprengel Museum Hannover], [P16], [P276],
  [Catalogue], [The catalogue that documents it], [the 1999 catalogue], [P47], [P1343],
)
A touring exhibition gets one row for each venue, so that each artwork can be linked to the show where it was actually seen.

=== Catalogue
<catalogue-1>
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Field], [What to enter], [Example], [CPS], [Wikidata],),
  table.hline(),
  [Title], [Title of the catalogue], [BALDESSARI : While something is happening here …], [P5], [P1476],
  [ISBN or identifier], [ISBN-13, or another identifier if there is none], [978-3-88375-396-6], [P43], [P212],
)
=== Artwork
<artwork>
Create one row for every artwork in the catalogue, including those that were not exhibited.

#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Field], [What to enter], [Example], [CPS], [Wikidata],),
  table.hline(),
  [Title], [Title of the work], [Man Running/Men Carrying Box], [P5], [P1476],
  [Artwork type], [What kind of object it is], [photograph], [P4], [P31],
  [Materials], [Materials and techniques], [black and white photographs, vinyl paint, oil tint], [P9], [P186],
  [Artist], [The artist], [John Baldessari], [P6], [P170],
  [Date created], [Year, or YYYY-MM-DD], [1988], [P7], [P571],
  [Width cm], [Width in centimetres], [268], [P12], [P2049],
  [Height cm], [Height in centimetres], [123], [P11], [P2048],
  [#strong[Exhibition]], [#strong[The exhibition, not the venue (Step 1)]], [#strong[#link("https://cps.tibwiki.io/wiki/Item:Q49")[BALDESSARI : While something is happening here … : Works 1988--1999]]], [#strong[P21] (CIDOC P9i)], [#strong[P608]],
  [Catalogue], [The catalogue the work appears in], [the 1999 catalogue], [P48], [P1343],
)
== Step 3: Upload the data to Wikidata
<sec-howto-wikidata>
Wikidata is open and anyone may add to it, so a few habits keep the record reliable. Data on Wikidata is released under CC0, so enter facts only, and do not upload images or texts that are protected by copyright.

#strong[\1. Check what already exists.] Search #link("https://www.wikidata.org")[wikidata.org] for the artist, the exhibition, the catalogue and each artwork. Reuse existing items to avoid duplicates. John Baldessari is #link("https://www.wikidata.org/wiki/Q683378")[Q683378], and the exhibition has an item as well: #link("https://www.wikidata.org/wiki/Q141747732")[Q141747732].

#strong[\2. Create the missing items.] Use your filled-in template as the source. Work in the order of its sheets, because later items refer to earlier ones: artist, exhibition, catalogue, artworks. Give each item a label, a short description, a type (#emph[instance of]) and the fields from Step 2. Add a reference, for example the catalogue or the museum website, to each statement that you did not observe yourself.

#strong[\3. Add the connection from Step 1.] On each artwork that was exhibited, add the statement #emph[exhibition history] (P608) with the exhibition item as value. For the catalogue, add #emph[described by source] (P1343) with the page (P304) as a qualifier.

#strong[\4. Upload in bulk with QuickStatements.] For more than a few artworks, use #link("https://quickstatements.toolforge.org")[QuickStatements] instead of editing by hand. The following template creates one artwork item and connects it to the exhibition. Replace the values in angle brackets with your own data.

#Skylighting(([#NormalTok("CREATE");],
[#NormalTok("LAST|Len|\"Man Running/Men Carrying Box\"");],
[#NormalTok("LAST|Den|\"1988 artwork by John Baldessari\"");],
[#NormalTok("LAST|P31|<class of the work, for example photograph>");],
[#NormalTok("LAST|P170|Q683378");],
[#NormalTok("LAST|P571|+1988-00-00T00:00:00Z/9");],
[#NormalTok("LAST|P608|Q141747732");],));
To change items that already exist, use the item number in place of #NormalTok("CREATE"); and #NormalTok("LAST");, for example #NormalTok("Q123456|P608|Q141747732");.

#strong[\5. Link back to the CPS Wikibase.] Copy each new Wikidata number into the #emph[Wikidata item] field (P24) of the matching CPS record. This closes the loop: the exhibition page of this book then shows a "View on Wikidata" link for it. At the moment the Hannover exhibition is linked, and the Dresden exhibition is not yet.

#strong[\6. Check the result.] Open the #link("https://query.wikidata.org")[Wikidata Query Service] and run the query below. It lists every artwork on Wikidata that is connected to the exhibition. Compare the list with the artworks marked as exhibited in the exhibition catalogue chapter.

#Skylighting(([#NormalTok("SELECT ?artwork ?artworkLabel WHERE {");],
[#NormalTok("  ?artwork wdt:P608 wd:Q141747732 .");],
[#NormalTok("  SERVICE wikibase:label { bd:serviceParam wikibase:language \"en\". }");],
[#NormalTok("}");],
[#NormalTok("ORDER BY ?artworkLabel");],));
= Summary
<sec-summary>
The CPS Wikibase currently describes #strong[73] artworks, including #strong[21] paintings and #strong[19] photographs, together with the materials, persons, exhibition and catalogue that document them.

Combining OCR-derived catalogue extraction with CPS data linked to Wikidata and the DNB makes it possible to add context and bibliographic evidence without duplicating it in the Wikibase. Because the book is generated from live queries and reproducible source files, it can be rebuilt at any time to follow the growth of the data.

== Possible next steps
<possible-next-steps>
- Fill the #emph[Scan page] qualifier (P49) for all catalogue appearances.
- Add Wikidata links (P24) for the remaining persons and materials.
- Record images (P17) so that works can be shown in the book.

#heading(level: 1, numbering: none)[References]
<references>
#block[
] <refs>
#show: appendices.with("Appendices", hide-parent: true)
#heading(level: 1, numbering: none)[Appendices]
= Data sources and licences
<sec-data-sources>
#table(
  columns: (22.86%, 28.57%, 48.57%),
  align: (auto,auto,auto,),
  table.header([Source], [Endpoint], [Licence / terms],),
  table.hline(),
  [CPS Wikibase], [#link("https://cps.tibwiki.io/query/proxy/sparql")], [See the licence statement on the #link("https://cps.tibwiki.io/")[CPS wiki]],
  [Wikidata], [#link("https://query.wikidata.org/sparql")], [#link("https://creativecommons.org/publicdomain/zero/1.0/")[CC0 1.0]],
  [Deutsche Nationalbibliothek], [#link("https://services.dnb.de/sru/dnb")], [DNB bibliographic data are available under CC0 1.0 (see the DNB data-licence page)],
  [OCR catalogue extraction], [#link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/catalogues/catalogue-extraction/catalogue-ocr-llm-extraction.ipynb")[Notebook], #link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/catalogues/catalogue-extraction/README.md")[Method notes], #link("https://github.com/NFDI4Culture/linked-open-exhibition/blob/main/catalogues/catalogue-extraction/demo/baldessari-sprengel-artworks.csv")[Output CSV]], [Source repository terms apply (see linked-open-exhibition)],
)
The text of this book is licensed under CC BY 4.0 and the code under the MIT licence.

#block[
#block[
#Skylighting(([#NormalTok("Built: 2026-11-06 15:34 UTC");],
[#NormalTok("CPS endpoint: https://cps.tibwiki.io/query/proxy/sparql");],));
]
] <build-info>



#bibliography(("references.bib"))

