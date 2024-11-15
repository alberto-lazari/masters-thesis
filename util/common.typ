#let code(content, caption: none, breakable: false) = figure(caption: caption, {
  set text(.9em)
  set align(left)
  set block(
    breakable: breakable,
    inset: .7em,
    stroke: .3pt + luma(150), width: 100%,
  )
  content
})
