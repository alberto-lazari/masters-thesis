#import "../config/translated.typ": degree

#let no-linebreak(body) = {
  show linebreak: none
  body
}

#let copyright(name, title, date) = page(align(bottom)[
  #name:
  _#no-linebreak(title)_,
  #degree,
  #sym.copyright #date.display("[month repr:long] [year]").
])
