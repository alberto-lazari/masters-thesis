#import "../config/translated.typ": acknowledgements

#let acknowledgements-bookmark = context hide(place(dy: -page.margin.top)[
  #let acknowledgements = acknowledgements.at(text.lang)
  = #acknowledgements #label(acknowledgements)
])

#let acknowledgements() = page[
  #acknowledgements-bookmark

  #v(1cm)

  #heading(outlined: false)[Acknowledgements]

  #v(1cm)
]
