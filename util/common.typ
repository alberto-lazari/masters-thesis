#let code(content, caption: none, breakable: false) = figure(caption: caption, {
  set text(.9em)
  set block(
    breakable: breakable,
    inset: .7em,
    stroke: .3pt + luma(150),
  )
  content
})
