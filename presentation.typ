#import "@preview/xarrow:0.3.1": xarrow
#import "presentation-theme.typ": (
  unipd-theme,
  title-slide,
  slide,
  filled-slide,
  pause,
  meanwhile,
  uncover,
  only,
  grey,
  outline-slide,
)

#show: unipd-theme

#title-slide(
  title: [Towards Secure Virtual Apps: Bringing Android Permission Model to Application Virtualization],
  subtitle: [Master's degree in Computer Science],
  authors: (
    [_Candidate:_ Alberto Lazari],
    [_Supervisor:_ Prof. Eleonora Losiouk]
  ),
  date: [December 12, 2024],
)

#slide(section: [Summary])[
  - App-level virtualization: run applications inside a container app

  #grey(2)[
  - Permissions for virtual apps shared with container
  ]

  #meanwhile
  #grey(3)[
  - Android's sandbox model violated: unintended access to restricted resources
  ]

  #meanwhile
  #grey(4)[
  - Analyze Android's permission model -> emulate it in virtual environment
  ]

]

#outline-slide()

= Background
== Android App-Level Virtualization
Apps can load code dynamically to extend its functionalities.

#pause
Imagine if an app loaded another app's code...

#meanwhile
#v(30%)
#pause

#pause
#align(center + horizon,
grid(columns: (33%, 10%, 33%),
  {
    place(center + horizon, dy: -65%, block(stroke: 1pt, inset: .5em,
      image(width: 40%, "/images/presentation/android-blue.png") + block(stroke: 1pt, inset: .5em, image(width: 30%, "/images/presentation/messages.png"))
    ))
  },
  xarrow(width: 7em, sym: sym.arrow.l)[Install],
  block(stroke: 1pt, inset: .5em, image(width: 30%, "/images/presentation/messages.png")),
))

== Use Cases
- Virtual apps isolation from system

- App clones (multiple instances)

- Isolated environments for testing and security

- Finer control over app's environment

== Dynamic Proxies
- Redirect virtual apps requests to the system

- Necessary because apps live inside the container

- Android knows nothing about them

#pause
- Let's see an example

---

// Place holder
#block(height: 45%, [])

#only(1,
place(bottom + center,
align(center + horizon,
grid(columns: (auto, 34%, auto), rows: (20%, 43%),
  grid.cell(rowspan: 2,
  block(height: 100%, stroke: 1pt,
  grid(rows: (auto, 35%, auto), inset: (x: 1em, y: .7em),
    image(width: 60%, "/images/presentation/android-blue.png"),
    rotate(-90deg, xarrow[`readContacts()`]),
    block(stroke: 1pt, inset: 10%, image(width: 50%, "/images/presentation/messages.png")),
  ))),
  xarrow[(container) `readContacts()`],
  grid.cell(rowspan: 2, align(top, image(height: 80%, "/images/presentation/android.png"))),
))))

#only(2,
place(bottom + center,
align(center + horizon,
grid(columns: (auto, 34%, auto), rows: (20%, 43%),
  grid.cell(rowspan: 2,
  block(height: 100%, stroke: 1pt,
  grid(rows: (auto, 35%, auto), inset: (x: 1em, y: .7em),
    image(width: 60%, "/images/presentation/android-blue.png"),
    hide(rotate(-90deg, xarrow[`readContacts()`]))
      + place(center + horizon,
        rotate(-90deg,
        xarrow(sym: sym.arrow.l, text(1.1em)[Contacts]))),
    block(stroke: 1pt, inset: 10%, image(width: 50%, "/images/presentation/messages.png")),
  ))),
  xarrow(width: 9em, sym: sym.arrow.l)[(container) Contacts],
  grid.cell(rowspan: 2, align(top, image(height: 80%, "/images/presentation/android.png"))),
))))


= Motivation
== Permissions in Virtual Frameworks
- The system enforces permissions normally on the container

#grey(2)[
- Android knows nothing about virtual apps
]
#grey(3)[
#v(-.5em) #h(1.85em)
=> container has full responsibility over virtual apps
]
#grey(4)[
#v(-.5em) #h(1.85em)
=> permissions are not enforced on virtual apps
]

#pause
#pause
#pause
#pause
- Works fine for a single app

---

// Place holder
#block(height: 45%, [])

#only(1,
place(bottom + center,
align(center + horizon,
grid(columns: (auto, 34%, auto), rows: (20%, 43%),
  grid.cell(rowspan: 2,
  block(height: 100%, stroke: 1pt,
  grid(rows: (auto, 35%, auto), inset: (x: 1em, y: .7em),
    image(width: 60%, "/images/presentation/android-blue.png"),
    rotate(-90deg, xarrow[`readContacts()`]),
    block(stroke: 1pt, inset: 10%, image(width: 50%, "/images/presentation/messages.png")),
  ))),
  xarrow[(container) `readContacts()`],
  grid.cell(rowspan: 2, align(top, image(height: 80%, "/images/presentation/android.png"))),
))))

#only(2,
place(bottom + center,
align(center + horizon,
grid(columns: (auto, 34%, auto), rows: (20%, 43%),
  grid.cell(rowspan: 2,
  block(height: 100%, stroke: 1pt,
  grid(rows: (auto, 35%, auto), inset: (x: 1em, y: .7em),
    image(width: 60%, "/images/presentation/android-blue.png"),
    hide(rotate(-90deg, xarrow[`readContacts()`])),
    block(stroke: 1pt, inset: 10%, image(width: 50%, "/images/presentation/messages.png")),
  ))),
  hide(xarrow[(container) `readContacts()`])
    + place(center + horizon, dx: 15%)[
      #set text(size: .8em)
      Ok, container has Contacts permission
    ],
  grid.cell(rowspan: 2, align(top, image(height: 80%, "/images/presentation/android.png"))),
))))

#only(3,
place(bottom + center,
align(center + horizon,
grid(columns: (auto, 34%, auto), rows: (20%, 43%),
  grid.cell(rowspan: 2,
  block(height: 100%, stroke: 1pt,
  grid(rows: (auto, 35%, auto), inset: (x: 1em, y: .7em),
    image(width: 60%, "/images/presentation/android-blue.png"),
    hide(rotate(-90deg, xarrow[`readContacts()`]))
      + place(center + horizon,
        rotate(-90deg,
        xarrow(sym: sym.arrow.l, text(1.1em)[Contacts]))),
    block(stroke: 1pt, inset: 10%, image(width: 50%, "/images/presentation/messages.png")),
  ))),
  xarrow(width: 9em, sym: sym.arrow.l)[(container) Contacts],
  grid.cell(rowspan: 2, align(top, image(height: 80%, "/images/presentation/android.png"))),
))))

== What About Multiple Apps?
- Add notes app, declaring no permissions

#pause
- Messages app requests contacts

#pause
- Notes app is granted the permission too

#meanwhile
#align(center + horizon, grid(columns: (23%, auto, 15%), rows: (20%, 15%), inset: .5em,
  grid.cell(rowspan: 2, block(height: 100%, stroke: 1pt, inset: 5%,
    image(width: 50%, "/images/presentation/android-blue.png") +
    v(weak: true, 10%) +
    grid(columns: (1fr, 1fr),
      block(stroke: 1pt, inset: 5%, image(width: 70%, "/images/presentation/noteit.png")),
      block(stroke: 1pt, inset: 5%, image(width: 70%, "/images/presentation/messages.png")),
    )
  )),
  pause + xarrow(width: 10em, []),
  image.decode(width: 50%, read("/images/presentation/contacts.svg").replace("#e8eaed", "#495d92")),
))

---

- Containers usually have many permissions \
  => extensive attack surface for malicious apps

#grey(2)[
- Need to isolate virtual apps -> *virtual permission model*
]
#grey(3)[
- Consistency with Android's model -> *analyze it*
]


= Android Permission Model
== Permissions Overview
Three _protection levels_, based on information sensitivity:

#grey(2)[
- Normal: minimal effects on system
]

#grey(3)[
- Dangerous: access user's private informations
]
#grey(4)[
- Signature: features available to same developer
]

#v(5%)

#pause
#pause
#pause
#pause
Two categories, based on protection level:

- Install-time: normal + signature

- Runtime: dangerous

== Permission Groups
Runtime permissions require direct user approval \
#pause
=> too many requests.

#pause
#grid(columns: (2fr, 1fr))[
  One dialog to rule them all:

  - Similar permissions are requested once

  - Reduce user interaction

  - Hide complexity guiding choices
][
  #place(right + horizon, dy: -20%, image(width: 65%, "/images/cool-location-request.png"))
]

== How Does It Translate to Code?
#block(height: 65%, [])
#place(center + horizon, dy: 11%, {
  set image(height: 78%)
  only("-1", image("/images/system-classes-bw.svg"))
  only("2-", image("/images/system-classes.svg"))
})

== High-Level Components
#v(7%)
#figure(image(height: 45%, "/images/system-components.svg"))

#{
  set text(.9em)
  only("2-", place(left + horizon, [UI]))
  only("3-", place(horizon + center, dy: -18%, dx: 9%, [Operations]))
  only("4-", place(bottom + center, dy: -22%, dx: 45%, [Representation]))
  only("5-", place(bottom + center, dy: -10%, dx: -4%, [Storage]))
}


= Virtual Permission Model
== High-Level Components
#block(height: 75%, [])
#place(center + horizon, dy: 7%, {
  only(1, figure(image(height: 45%, "/images/system-components.svg")))
  only(2, figure(image(height: 80%, "/images/virtual-components.svg")))
})

== Final Architecture
#block(height: 75%, [])
#place(center + horizon, dy: 7%, {
  figure(image(height: 80%, "/images/virtual-classes.svg"))
})

== Components Flow
#block(height: 75%, [])
#place(left + horizon, dy: -23%, xarrow[`requestPermissions()`])
#place(center + horizon, dy: 7%, dx: 5%, {
  only(1, figure(image(height: 80%, "/images/presentation/components/virtual-components-bw.svg")))
  only(2, figure(image(height: 80%, "/images/presentation/components/redirection.svg")))
  only(3, figure(image(height: 80%, "/images/presentation/components/ui.svg")))
  only(4, figure(image(height: 80%, "/images/presentation/components/core.svg")))
  only(5, figure(image(height: 80%, "/images/presentation/components/model.svg")))
  only(6, figure(image(height: 80%, "/images/presentation/components/persistence.svg")))
})

== Implementation
#align(center + horizon, grid(columns: (1fr, 1fr),
  image(width: 20%, "/images/presentation/virtualxposed.png"),
  v(2%) + image(width: 100%, "/images/presentation/virtualapp.png"),
))

- VirtualXposed container app

- VirtualApp underlying virtualization framework
#grey(2)[
- Android 14 and technological update
]
#grey(3)[
- Actual components implementation
]


= Evaluation
== Permission Type Focus
- General model, different behaviors

- Protection levels:
  - Normal: less testing involved
  - Signature: not even available to container
  - Dangerous: most complicated, many edge cases

== TestApp
App designed to test key aspects of the model.

#align(center + horizon, grid(columns: (4fr, 3fr))[
  `PremissionRequestActivity`
  #grid(columns: (1fr, 1fr),
    image(height: 50%, "/images/testapp/permission-check.png"),
    image(height: 50%, "/images/testapp/permission-request.png"),
  )
][
  #pause
  `ContactsActivity`
  #image(height: 50%, "/images/testapp/mario.png")
])

== Telegram
#block(height: 20%)[]

#place(horizon, dy: 10%,
align(horizon,
grid(columns: (5fr, 2fr, 2fr), [
  - Test real-world scenario

  - Checks and requests work fine

  - Camera patch works
  ],
  figure(image(height: 50%, "/images/testapp/telegram-denied.png")),
  figure(image(height: 50%, "/images/testapp/camera-denied.png")),
)))

== Overall Result
- Proof of concept of general model

- Effective for basic use cases

#pause
- Limitations for actual applications


= Future Directions
== Limitations
- Framework hands off operations to system

- System services perform actual permission checks internally

- Model cannot redirect system's calls

== Solutions
- Manual hooks on all possible methods \
  (performed for contacts and camera)

#grey(2)[
- Automated permission analysis:
  block every call lacking permissions. \
  -> Problem: lack of exhaustive mapping
]
#grey(3)[
- Re-implement Android's services:
  include Android's source in virtual framework. \
  -> Problem: probably still requires adaptation effort
]


#filled-slide[
  Question Time?
]

#filled-slide[
  #let logo = read("images/presentation/logo_text.svg").replace("#B20E10", "#FFFFFF")
  #image.decode(width: 40%, logo)

  Thank you for your attention!

  #v(10%)
  #align(center, block(width: 85%, height: 13%, grid(
    columns: (1fr, 1fr),
    image("images/presentation/computer-science.png"),
    align(horizon, image(height: 65%, "images/presentation/dm-logo.png")),
  )))
]
