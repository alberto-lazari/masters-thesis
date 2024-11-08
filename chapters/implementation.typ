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


