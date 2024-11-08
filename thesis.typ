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
)
#for chapter in chapters {
  include "chapters/" + chapter + ".typ"
}

= Background <background>
== App-level Virtualization
- Different types
- Standard way of managing permissions in sandbox applications (once for entire host app)

== Android Architecture
- User layer (app-level)
- System layer
- Framework
- ART
- Binder
- Services

== VirtualXposed
Aim of the project
=== VirtualApp
- How VirtualXposed uses VirtualApp and wraps its functionalities in a complete app
- High-level structure
- Relevant components and how it works (dynamic proxies to catch services behavior)
- Lack of permission management for virtual apps

== Permission Model
Description and evolution


= Related Work <related_work>
Boxify? Different approach


= Securing the Virtual Apps <implementation>
== Preliminary Work
- Updating VirtualXposed to latest Android version
- Assign unique UIDs to virtual apps

== Design
=== General Permission Model
- Inspired by Android real model, but simplified
- Install-time permissions: why they need to be managed
=== Runtime Permissions
- Android implementation details
- My implementation
- Permission dialog
- Host permissions management
=== Implementation Peculiarities
- Override individual runtime permissions (with respect to its group)
- Install-time permissions could be revoked (no settings for that though)
- Dialog is not always a perfect replica (location, background permissions, ...)

== Implementation
=== Architecture
- Model
- `VPermissionManager`
- Dialog
- Settings activities
=== Replace System Manager With Custom Implementation
==== Technical Solutions
Different methods:
- Dynamic proxies
- Native interface
==== Examples
Custom permission model implemented for:
- `checkPermission`
- `requestPermissions`
- Camera permission checking
- Contacts content provider permissions


= Evaluation <evaluation>
- Test app
- Real world example: Telegram


= Discussion <discussion>
== Finding a General Solution
=== Binder Calls
- System implementation once performing a binder call
- Manual hook implementations are required for many methods
=== Lack of Comprehensive Permission Mapping
Not possible to implement a naive automated solution by hooking every method and throwing `SecurityException`
=== Complex Hooks Implementation
Every hook for a specific method has to reimplement its Android counterpart logic, leading to difficulties in automating the process


= Conclusions <conclusions>
- Not really feasible to implement the original idea
- Future work: permission mapping for platform methods (still needed for recent Android versions)

#bibliography("sources.bib")
