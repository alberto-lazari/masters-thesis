#let printed = {
  let input = sys.inputs.at("printed", default: "true")
  if input in ("true": true, "false": false) {
    input == "true"
  } else {
    panic("Invalid input `printed`: value must be true or false")
  }
}

#let pagebreak-to(to, weak, printed) = {
  pagebreak(weak: weak, to: if printed { to } else { none })
}

#let pagebreak-to-right(weak: false, printed: printed) = pagebreak-to("odd", weak, printed)

#let pagebreak-to-left(weak: false, printed: printed) = pagebreak-to("even", weak, printed)

#let left-right-margins(page, printed: printed) = {
  if not printed {
    return (left: 3cm, right: 3cm)
  }

  if calc.rem(page, 2) == 0 {
    return (left: 3cm, right: 4cm)
  } else {
    return (left: 4cm, right: 3cm)
  }
}
