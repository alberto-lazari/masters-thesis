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

#let margin(printed: printed) = {
  let digital-margin = 3cm
  let printed-disparity = if printed { 1cm } else { 0pt }
  (
    top: 1in + 22pt + 18pt + 12pt,
    inside: digital-margin + printed-disparity,
    outside: digital-margin - printed-disparity,
    bottom: 3.5cm,
  )
}
