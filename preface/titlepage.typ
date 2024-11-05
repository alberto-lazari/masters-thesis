#import "/config/translated.typ": *

#let titlepage(affiliation, title, supervisor, candidate, academic-year, accent-color) = page(
  footer: [],
  margin: (bottom: 1.7cm),
[
  #show: align.with(center)

  #image(height: 6cm, "../images/unipd-logo.png")
  #v(10pt)

  #text(size: 22pt, strong(affiliation.university))

  #line(length: 100%, stroke: .5pt + rgb("#777777"))
  #v(-.5em)

  #text(size: 14pt, smallcaps(affiliation.department))

  #text(size: 12pt, smallcaps(affiliation.degree))

  #v(30pt)
  #text(size: 20pt, fill: accent-color, strong(title))

  #v(20pt)

  #text(size: 14pt, style: "oblique", degree)

  #v(40pt)

  #grid(
    columns: (1fr, 1fr),
    align(left)[
      _ #supervisor-prefix _

      #supervisor.name \
      #supervisor.affiliation
    ],
    align(right)[
      _ #candidate-prefix _

      #candidate.name \
      #candidate.id
    ]
  )

  #align(center + bottom)[
    #line(length: 100%, stroke: .5pt + rgb("#777777"))
    #smallcaps[#academic-year-prefix #academic-year]
  ]
])
