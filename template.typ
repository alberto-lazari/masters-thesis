#import "config/printed.typ": pagebreak-to-right, pagebreak-to-left, left-right-margins, printed, printed-header

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
  accent-color: rgb("#B5121B"),
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
  set par(
    justify: true,
    first-line-indent: 1em,
    spacing: .8em,
  )
  show heading: it => {
    smallcaps(it)
  }
  set outline(depth: 3)
  show link: it => {
    set text(fill: accent-color)
    it
  }

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
      let chapter-opening = next_chapters.len() > 0 and next_chapters.at(0).location().page() == here().page()
      let page-number = counter(page).get().at(0)
      let chapter = [
        #numbering("1", counter(heading).get().at(0)).
        #smallcaps(query(selector(heading.where(level: 1)).before(here())).last().body)
      ]
      let subsection = {
        let number = numbering("1.1.", ..counter(heading).get())
        let head = query(selector(heading).before(here(), inclusive: true)).last()
        let after = query(selector(heading).after(here(), inclusive: true)).first()
        // If the header is exactly above a new section write that
        if locate(after.location()).position().y < 130pt {
          number = numbering("1.1.", ..counter(heading).at(after.location()))
          head = after
        }
        // Display a heading that is at most nested at level 3
        if head.level > 3 {
          number = numbering("1.1.", ..counter(heading).get().slice(0, count: 3))
          head = query(selector(heading.where(level: 3)).before(here(), inclusive: true)).last()
        }
        let title = head.body
        let characters
        if title.has("text") {
          characters = title.at("text", default: "").len()
        } else if title.has("children") {
          characters = title.at("children", default: ())
            .fold("", (acc, it) => acc + it.at("text", default: " "))
            .len()
        }
        let text-size = 1em
        if characters > 30 {
          // Prevent line breaks by shrinking long titles
          text-size -= 0.015em * (characters - 30)
        }
        set text(size: text-size)
        [#number #smallcaps(head.body)]
      }
      let line = {
        v(-.5em)
        line(length: 100%, stroke: .3pt)
      }

      if printed {
        printed-header(
          page-number: page-number,
          chapter: chapter,
          subsection: subsection,
          chapter-opening: chapter-opening,
          line: line,
        )
      } else if not chapter-opening {
        grid(
          align: (left, right),
          columns: (auto, 1fr),
          [#chapter],
          [#subsection],
        )
        line
      }
    }

    set page(
      numbering: "1",
      header: header,
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
        h(.2em)
      }
    }

    set list(indent: 0.5em)

    show math.equation: it => {
      show ".": math.class("punctuation", ".")
      it
    }

    body
  }
}
