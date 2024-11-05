= Introduction
- Android virtualization
- Android permission model
- Permission management in available solutions


= Background
== Android Architecture
- User layer (app-level)
- System layer
- Framework
- ART
- Binder
- Services

== App-level Virtualization
- Different types
- Standard way of managing permissions in sandbox applications (once for entire host app)

== Permission Model
Description and evolution


= VirtualXposed
Aim of the project

== VirtualApp
- How VirtualXposed uses VirtualApp and wraps its functionalities in a complete app
- High-level structure
- Relevant components and how it works (dynamic proxies to catch services behavior)
- Lack of permission management for virtual apps


= Related Work
Boxify? Different approach


= Implementation
== Early Tweaks
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
- Dynamic proxies
- Native interface
==== Examples
- `checkPermission`
- `requestPermissions`
- Camera permission checking
- Contacts content provider permissions


= Evaluation
- Test app
- Real world example: Telegram


= Results
== Lack of General Solution
=== Binder Calls
- System implementation once performing a binder call
- Manual hook implementations are required for many methods
=== Lack of Comprehensive Permission Mapping
Not possible to implement a naive automated solution by hooking every method and throwing `SecurityException`
=== Complex Hooks Implementation
Every hook for a specific method has to reimplement its Android counterpart logic, leading to difficulties in automating the process


= Conclusions
- Not really feasible to implement the original idea
- Future work: permission mapping for platform methods (still needed for recent Android versions)
