#import "/util/translated.typ": acknowledgements

#let acknowledgements-bookmark = context [
  #let acknowledgements = acknowledgements.at(text.lang)
  = #acknowledgements #label(acknowledgements)
]

#v(1cm)

// TODO
#acknowledgements-bookmark
