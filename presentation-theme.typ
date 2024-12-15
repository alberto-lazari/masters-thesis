#import "@preview/touying:0.5.2": *

#let _header-logo = (colors, ..args) => {
  let original = read("images/presentation/logo_text.svg")
  let colored = original.replace("#B20E10", colors.neutral-lightest.to-hex())
  image.decode(colored, ..args)
}

#let _footer-wave = (colors, ..args) => {
  let original = read("images/presentation/bg_wave.svg")
  let colored = original.replace("#9b0014", colors.primary.to-hex())
  image.decode(colored, ..args)
}

#let _title-background = (colors, ..args) => {
  let original = read("images/presentation/bg.svg")
  let colored = original.replace("#9b0014", colors.primary.to-hex()).replace("#484f59", colors.secondary.to-hex())
  image.decode(colored, ..args)
}

#let _background-logo = (colors, ..args) => {
  let original = read("images/presentation/logo_text.svg")
  let colored = original.replace("#B20E10", colors.primary.to-hex())
  image.decode(colored, ..args)
}

#let _header(self, section: utils.display-current-heading(level: 1)) = {
  set align(top)
  place(rect(width: 100%, height: 100%, stroke: none, fill: self.colors.primary))
  place(horizon + right, dx: -1.5%, _header-logo(self.colors, height: 90%))
  place(horizon + left, dx: 2.5%, text(size: 34pt, fill: self.colors.neutral-lightest, section))
}

#let _footer(self) = {
  place(bottom, _footer-wave(self.colors, width: 100%))
  place(
    bottom + right, dx: -7%, dy: -27%,
    text(
      size: 18pt,
      fill: self.colors.primary
        .lighten(100%)
        .saturate(30%),
      context utils.slide-counter.display() + " of " + utils.last-slide-number
    )
  )
}

#let outline-slide(title: utils.i18n-outline-title, ..bodies) = touying-slide-wrapper(self => {
  let self = utils.merge-dicts(
    self,
    config-page(
      header: _header.with(section: title),
      footer: _footer,
    ),
  )
  let setting = body => {
    show: block.with(width: 100%, height: 104%, inset: (left: 11em), breakable: false)
    set text(size: 1.3em, fill: self.colors.primary, weight: "medium")
    v(2.5fr)
    body
    v(2fr)
  }
  touying-slide(self: self, setting: setting, components.custom-progressive-outline(
    depth: 1,
    alpha: 20%,
    vspace: (.4em,),
  ))
})

#let slide(
  title: utils.display-current-heading(level: 2),
  section: utils.display-current-heading(level: 1),
  config: (:),
  repeat: auto,
  setting: body => body,
  composer: auto,
  ..bodies,
) = touying-slide-wrapper(self => {
  let self = utils.merge-dicts(
    self,
    config-page(
      header: _header.with(section: section),
      footer: _footer,
    ),
  )
  let new-setting = body => {
    show: block.with(width: 100%, height: 104%, inset: (x: 3em), breakable: false)
    set text(fill: self.colors.neutral-darkest)
    show: setting
    v(2.5fr)
    if title != none {
      show: block.with(inset: (y: -.5em))
      set text(size: 34pt, weight: "bold", fill: self.colors.primary)
      title
      v(.7em)
    }
    body
    v(2fr)
  }
  touying-slide(self: self, config: config, repeat: repeat, setting: new-setting, composer: composer, ..bodies)
})

#let title-slide(
  extra: none,
  ..args,
) = touying-slide-wrapper(self => {
  let info = self.info + args.named()
  let body = {
    // Background
    place(top, _title-background(self.colors, width: 107%))

    // Normalize data
    if type(info.subtitle) == none {
      info.subtitle = ""
    }
    if type(info.authors) != array {
      info.authors = (info.authors,)
    }
    if type(info.date) == none {
      info.date = ""
    }

    set text(fill: self.colors.neutral-lightest)
    set par(leading: .45em, spacing: .8em)

    // Images
    v(10%)
    align(center, block(width: 95%, height: 15%, grid(
      columns: (1fr, 1fr),
      image("images/presentation/computer-science.png"),
      align(horizon, image(height: 65%, "images/presentation/dm-logo.png")),
    )))
    v(5%)
    // Title
    align(
      center,
      box(inset: (x: 4em), text(size: 40pt, info.title))
    )
    v(1%)
    // Subtitle
    align(
      center,
      box(inset: (x: 2em), text(size: 24pt, info.subtitle))
    )
    // Authors
    place(bottom, dx: 7.5%, dy: -20%, text(size: 20pt, {
      info.authors.fold([], (acc, author) => acc + [#author \ ])
      parbreak()
      info.date
    }))
    // Logo
    place(
      bottom + right, dx: -5%, dy: -3%,
      _background-logo(self.colors, height: 17%)
    )
  }
  self = utils.merge-dicts(
    self,
    config-common(freeze-slide-counter: true),
    config-page(fill: self.colors.neutral-lightest, margin: 0em),
  )
  touying-slide(self: self, body)
})

#let filled-slide(
  config: (:),
  repeat: auto,
  setting: body => body,
  composer: auto,
  ..bodies,
) = touying-slide-wrapper(self => {
  let self = utils.merge-dicts(self, config-page(margin: 0em))
  let new-setting = body => {
    set text(size: 44pt, fill: self.colors.neutral-lightest)
    show: box.with(width: 100%, height: 100%, fill: self.colors.primary)
    show: align.with(center + horizon)
    show: setting
    body
  }
  touying-slide(self: self, config: config, repeat: repeat, setting: new-setting, composer: composer, ..bodies)
})

#let new-section(title) = heading(level: 1, depth: 2, title)

#let new-section-slide(
  config: (:),
  repeat: auto,
  setting: body => body,
  composer: auto,
  title,
) = touying-slide-wrapper(self => {
  let self = utils.merge-dicts(
    self,
    config-page(
      header: _header,
      footer: _footer,
    ),
  )
  let new-setting = body => {
    show: align.with(center + horizon)
    set text(size: 46pt, fill: self.colors.primary.lighten(15%), weight: "bold")
    show: setting
    body
  }
  touying-slide(self: self, config: config, repeat: repeat, setting: new-setting, composer: composer,
    underline(stroke: 5pt, offset: .4em, utils.display-current-heading(level: 1))
  )
})

#let unipd-theme(
  ..args,
  body,
) = {
  show: touying-slides.with(
    config-page(
      paper: "presentation-4-3",
      header-ascent: 0em,
      footer-descent: 0em,
      margin: (x: 0em, top: 12%, bottom: 12%),
    ),
    config-common(
      slide-fn: slide,
      new-section-slide-fn: outline-slide.with(title: utils.display-current-heading(level: 1)),
    ),
    config-methods(
      init: (self: none, body) => {
        set text(font: "Helvetica", size: 22pt, fill: self.colors.neutral-darkest)
        show heading.where(level: 2): set text(fill: self.colors.primary)
        show heading.where(level: 2): it => it + v(1em)
        set list(indent: 1em, marker: text(font: "Arial", "•", fill: self.colors.primary.darken(5%)))
        set enum(indent: 1em, numbering: n => text([#n.], fill: self.colors.primary.darken(5%)))
        show "->": sym.arrow
        show "=>": $=>$
        show raw: set text(1.1em, font: "Menlo")
        body
      },
      cover: (self: none, body) => box(hide(body)),
    ),
    config-colors(
      primary: rgb(155, 0, 20),
      secondary: rgb(72, 79, 89),
      tertiary: rgb(0, 128, 0),
      neutral-lightest: rgb("#ffffff"),
      neutral-darkest: rgb("#000000"),
      cover: self => self.colors.neutral-dark.lighten(80%)
    ),
    ..args
  )

  body
}

#let grey(n, content) = {
  let color = gray.lighten(50%)
  only("-" + str(n - 1), {
    set text(color)
    set list(indent: 1em, marker: text(font: "Arial", "•", fill: color))
    set enum(indent: 1em, numbering: n => text([#n.], fill: color))
    content
  })
  only(str(n) + "-", content)
}

#let (alert-block, normal-block, example-block) = {
  let make_block_fn(mk-header-color) = (title, body) => touying-fn-wrapper((self: none) => {
    show: it => align(center, it)
    show: it => box(width: 85%, it)
    let slot = box.with(width: 100%, outset: 0em, stroke: self.colors.neutral-darkest)
    stack(
      slot(
        inset: 0.5em, fill: mk-header-color(self),
        align(left, heading(level: 3, text(fill: self.colors.neutral-lightest, weight: "regular")[#title]))
      ),
      slot(
        inset: (x: 0.6em, y: 0.75em),
        fill: self.colors.neutral-lighter.lighten(50%), align(left, body)
      )
    )
  })

  (
    make_block_fn(self => self.colors.primary),
    make_block_fn(self => self.colors.secondary),
    make_block_fn(self => self.colors.tertiary),
  )
}
