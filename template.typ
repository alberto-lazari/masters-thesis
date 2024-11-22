#import "util/printed.typ": pagebreak-to-right, pagebreak-to-left, left-right-margins, printed
#import "util/header.typ": header, chapter

#import "preface/titlepage.typ": titlepage
#import "preface/copyright.typ": copyright

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
  accent-color: rgb("#B5121B"),
  date: datetime.today(),

  chapters: (),

  body
) = {
  set document(
    title: title,
    author: candidate.name,
    keywords: keywords,
    date: date,
  )

  set page(
    margin: if printed {(
      top: 1in + 22pt + 18pt + 12pt,
      inside: 3.7cm,
      outside: 2.3cm,
      bottom: 3.5cm,
    )} else {(
      top: 1in + 22pt + 18pt + 12pt,
      left: 3cm,
      right: 3cm,
      bottom: 3.5cm,
    )},
    header-ascent: 12pt + 18pt
  )
  set text(
    lang: lang,
    size: 11pt,
  )
  show heading: it => {
    smallcaps(it)
  }
  set outline(depth: 3)
  show link: set text(fill: accent-color)
  show raw: set text(font: "Menlo")
  show figure: it => {
    v(.5em)
    it
    v(.5em)
  }
  set list(marker: ([•], [◦], [--]))

  {
    set heading(numbering: none)
    show heading.where(level: 1): it => {
      set text(24pt)
      it
      v(1.2em)
    }

    set page(numbering: "i")
    titlepage(
      affiliation,
      title,
      supervisor,
      candidate,
      academic-year,
      accent-color,
    )
    copyright(candidate.name, title, date)
    let preface = (
      "acknowledgements",
      "summary",
      "toc",
    )
    for section in preface {
      include "preface/" + section + ".typ"
      pagebreak-to-right(weak: true)
    }
  }

  {

    set page(
      numbering: "1",
      header: header(),
      number-align: if printed { top } else { center + bottom },
    )
    counter(page).update(1)

    set heading(numbering: "1.1.1 ")
    show heading.where(level: 1): set heading(supplement: [Chapter])

    show heading: it => {
      let level = it.level
      if level == 1 {
        pagebreak-to-right(weak: true)
        block({
          set par(first-line-indent: 0pt)
          if it.numbering != none {
            box(strong(text(
              size: 100pt,
              fill: accent-color,
              counter(heading).display(it.numbering))))
              parbreak()
          }
          smallcaps(text(size: 26pt, it.body))
        })
        v(2em)
      } else if level == 2 {
        v(.5em)
        text(size: 16pt, it)
        v(.3em)
      } else if level == 3 {
        v(.2em)
        set text(size: 12pt)
        it
        v(.2em)
      } else if level > 3 {
        v(.5em)
        smallcaps(it.body) + [.]
        h(.1em)
      }
    }

    set list(indent: 0.5em)

    show math.equation: it => {
      show ".": math.class("punctuation", ".")
      it
    }

    for chapter in chapters {
      include "chapters/" + chapter + ".typ"
    }

    set page(
      header: header(chapter: chapter(number: false), subsection: none),
    )
    bibliography("sources.bib", style: "bib-style.csl")

    body
  }
}
