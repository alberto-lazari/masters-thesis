#import "printed.typ": printed

#let code(content, caption: none, breakable: false) = figure(caption: caption, {
  set text(.9em)
  set block(
    breakable: breakable,
    inset: .7em,
    // Grey borders are too light on paper
    stroke: .3pt + if not printed { luma(150) } else { black },
  )
  content
})
