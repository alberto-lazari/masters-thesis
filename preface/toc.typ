#let extra-outline(title: none, target: none) = context {
  if query(target).len() != 0 {
    if query(target).any(it => it.caption == none) {
      panic("Figure without caption")
    }
    outline(title: title, indent: auto, target: target, fill: repeat([.]))
  }
}

#show outline.entry.where(level: 1): it => {
  show repeat: none
  v(12pt, weak: true)
  strong(smallcaps(it))
}

#outline(title: [= Index] + v(-30pt), indent: auto)
// Ignore extras
// #extra-outline(title: [= Index of figures] + v(.5em), target: figure.where(kind: image))
// #extra-outline(title: [= Index of tables] + v(.5em), target: figure.where(kind: table))
