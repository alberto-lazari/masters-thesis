#import "printed.typ": printed

#let chapter(number: true) = context {
  let page-number = counter(page).get().at(0)
  let title = smallcaps(query(selector(heading.where(level: 1)).before(here())).last().body)
  let chapter-number = if number {
    numbering("1.", counter(heading).get().at(0))
  }

  [#chapter-number #title]
}

#let subsection() = context {
  let number = numbering("1.1.", ..counter(heading).get())
  let head = query(selector(heading).before(here(), inclusive: true)).last()
  let after = {
    let headings = query(selector(heading).after(here(), inclusive: true))
    if headings.len() > 0 {
      headings.first()
    }
  }
  // If the header is exactly above a new section write that
  let use-after = {
    if after != none {
      let position = locate(after.location()).position()
      let page-number = counter(page).get().at(0)
      position.page == page-number and position.y < 135pt
    } else {
      false
    }
  }
  if use-after {
    number = numbering("1.1.", ..counter(heading).at(after.location()))
    head = after
  }
  // Display a heading that is at most nested at level 3
  if head.level > 3 {
    head = query(selector(heading).before(here(), inclusive: true))
      .filter(it => it.level <= 3)
      .last()
    number = numbering("1.1.", ..counter(heading).get().slice(0, count: head.level))
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

  // Show only if a section or subsection. No need to show the chapter twice
  if head.level > 1 {
    [#number #smallcaps(head.body)]
  }
}

#let printed-header(
  page-number: none,
  chapter: none,
  subsection: none,
  chapter-opening: false,
  line: none,
) = {
  if chapter-opening {
    align(right)[#page-number]
  } else {
    if calc.rem(here().page(), 2) == 0 {
      grid(
        align: (left, right),
        columns: (auto, 1fr),
        [#page-number],
        [#chapter],
      )
    } else {
      grid(
        align: (left, right),
        columns: (1fr, auto),
        [#subsection],
        [#page-number],
      )
    }
    line
  }
}

#let header(chapter: chapter(), subsection: subsection()) = context {
  set text(size: 13pt)

  let page-number = counter(page).get().at(0)
  let chapter-opening = {
    let next_chapters = query(selector(heading.where(level: 1)).after(here()))
    next_chapters.len() > 0 and next_chapters.at(0).location().page() == here().page()
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
