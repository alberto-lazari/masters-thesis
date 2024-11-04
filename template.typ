#import "config/printed.typ": pagebreak-to-right, pagebreak-to-left, left-right-margins, printed

#import "preface/titlepage.typ": titlepage
#import "preface/copyright.typ": copyright
#import "preface/acknowledgements.typ": acknowledgements
#import "preface/summary.typ": summary
#import "preface/toc.typ": toc

#let template(
  affiliation: (
    university: "University of Padua",
    department: [Department of Mathematics "Tullio Levi-Civita"],
    degree: "Master's Degree in Computer Science",
  ),
  title: "Titolo della tesi",
  supervisor: (
    name: "Prof. Nome Cognome",
    affiliation: "University of Padua",
  ),
  candidate: (
    name: "Nome Cognome",
    id: 1234256
  ),
  academic-year: "AAAA-AAAA",

  keywords: (),

  lang: "it",
  accent-color: rgb("#A5020B"),
  date: datetime.today(),

  body
) = {
  set document(
    title: title,
    author: candidate.name,
    keywords: keywords,
    date: date,
  )

  set page(
    margin: (top: 1in + 22pt + 18pt + 12pt, x: 3.5cm, bottom: 3.5cm),
    header-ascent: 12pt + 18pt
  )
  set text(lang: lang)
  set text(font: "New Computer Modern", size: 11pt)
  set par(justify: true)

  {
    set heading(numbering: none)

    set page(numbering: "i")
    titlepage(
      affiliation,
      title,
      supervisor,
      candidate,
      academic-year,
      accent-color,
    )
    pagebreak-to-right(weak: true)
    copyright(candidate.name, title, date)
    pagebreak-to-right(weak: true)
    acknowledgements()
    pagebreak-to-right(weak: true)
    summary()
    pagebreak-to-right(weak: true)
    toc()
    pagebreak-to-right(weak: true)
  }

  {
    let header = context {
      set text(size: 13pt)

      let next_chapters = query(selector(heading.where(level: 1)).after(here()))

      if next_chapters.len() > 0 and next_chapters.at(0).location().page() == here().page() {
        align(right)[#counter(page).get().at(0)]
      } else {
        let chapter = query(selector(heading.where(level: 1)).before(here())).last()
        if calc.rem(here().page(), 2) == 0 {
          grid(
            align: (left, right),
            columns: (auto, 1fr),
            [#counter(page).get().at(0)],
            [#numbering("1", counter(heading).get().at(0)). #smallcaps(chapter.body)],
          )
        } else {
          let subsection = query(selector(heading).before(here())).last()

          grid(
            align: (left, right),
            columns: (1fr, auto),
            [#numbering("1.1", ..counter(heading).get()). #smallcaps(subsection.body)],
            [#counter(page).get().at(0)],
          )
        }
      }
    }

    set page(numbering: "1", header: if printed { header }, footer: if printed { [] } else { none })
    counter(page).update(1)

    set heading(numbering: "1.1.1")
    show heading.where(level: 1): it => {
      pagebreak-to-right(weak: true)
      h(-.3em)
      strong(text(size: 100pt, fill: accent-color, counter(heading).display(it.numbering)))
      v(-10pt)
      text(size: 24pt, it.body)
      v(1.5em)
    }
    show heading.where(level: 2): it => {
      text(size: 18pt, it)
      v(0.5em)
    }

    set list(indent: 0.5em)

    show math.equation: it => {
      show ".": math.class("punctuation", ".")
      it
    }

    body
  }
}
