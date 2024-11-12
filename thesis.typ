#import "template.typ": template

#show: template.with(
  affiliation: (
    university:   [University of Padua],
    department:   [Department of Mathematics "Tullio Levi-Civita"],
    degree:       [Master's Degree in Computer Science],
  ),

  title:          [Towards Secure Virtual Apps: Bringing Android Permission Model to Application Virtualization],
  keywords: (
                  "Android virtualization",
                  "Android sandbox",
                  "Android permission model",
                  "VirtualApp",
  ),

  supervisor: (
    name:         [Prof. Eleonora Losiouk],
    affiliation:  [University of Padua],
  ),
  candidate: (
    name:         "Alberto Lazari",
    id:           2089120,
  ),
  academic-year:  [2023--2024],
  date:           datetime(year: 2024, month: 12, day: 13),

  lang:           "en",
)

#let chapters = (
  "introduction",
  "background",
  "related-work",
  "implementation",
  "evaluation",
  "discussion",
  "conclusions",
)
#for chapter in chapters {
  include "chapters/" + chapter + ".typ"
}

#bibliography("sources.bib", style: "bib-style.csl")
