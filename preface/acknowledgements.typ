#import "/util/translated.typ": acknowledgements

#let acknowledgements-bookmark = context [
  #let acknowledgements = acknowledgements.at(text.lang)
  = #acknowledgements #label(acknowledgements)
]

#v(1cm)

#acknowledgements-bookmark

// TODO: write acknowledgements
// I would dearly like to... put acknowledgements on the final version of this thesis.
