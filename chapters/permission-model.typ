= Android Permission Model
The Android permission model is designed to protect user privacy and security,
preventing apps from freely accessing sensitive information about the user or the device.
It controls access to resources and features that extend beyond the app's sandbox,
such as:
- Hardware device capabilities (e.g., internet connection, location, microphone).
- User's private data (e.g., calendar, media content, SMS).
- System and device settings.
This system of permissions gives apps a mechanism to follow the least privilege principle,
and increase user awareness,
creating a barrier that requires---either explicit or implicit---user or system consent,
before sensitive information or powerful features can be accessed.

Every app must declare all required permissions in its `AndroidManifest.xml` file.
The manifest can be seen as a contract,
listing permissions the app requests and will probably use at some point.
If an app tries using additional permissions, that were not declared in the manifest,
it cannot request or use them at runtime.
By requiring these declarations, Android ensures transparency,
since users are presented and can review the requested permissions before installation.

== Protection Levels
Permissions are assigned a _protection level_ at the time they are defined.
It reflects how sensitive the property protected by a permission is,
and determines which steps an application needs to perform, in order to obtain it.

Protection levels categorize permissions as follows:
+ Normal permissions:
  they grant access to simple resources that pose a low risk to user privacy and other apps' security,
  such as setting alarms, checking the network state, or controlling the flashlight.
+ Dangerous permissions:
  they provide access to sensitive data or resources, such as device's location, camera, or contacts,
  which have a higher impact on user privacy.
+ Signature permissions:
  they are only granted to apps that are signed with the same certificate as the app defining the permission.
  These are typically used when two or more apps from the same developer need to share data or functionality.
  They can also be system permissions that are signed with the OS signature,
  meaning that only system and privileged apps can use them.

Prior to Android 6 (Marshmallow),
both normal and dangerous permissions were automatically granted at install-time,
where users had to either accept all requested permissions or cancel the installation.
Since Android 6, apps are required to request individual dangerous permissions before using them,
prompting users to approve each permission request.
This further divides permissions in two categories, based on their protection level:
+ Install-time permissions: they are granted once during installation, and cannot be revoked.
  They include both normal permissions, which are always granted automatically, and signature permissions,
  which depend on the requesting app's certificate.
+ Runtime permissions: they have a dangerous protection level and must be requested as the app runs,
  with explicit user approval through a permission dialog.

== Runtime Permissions
By involving an interaction with the user,
_runtime permissions_ are the most complex type in the Android permission model.
These permissions require that prompts be designed to be quick and simple, understand user intentions, and be accessible to the general user to understand them.
This has lead to many updates and changes over time,
aimed at simplifying the user experience or enhancing the security.

=== Permission Dialog
The permission dialog is the primary interface through which users interact with Android's runtime permissions,
and is presented every time apps request an unset permission.
To keep interactions simple, the dialog hides complex permission logic mechanisms by condensing it into just two or three buttons,
balancing user control with simplicity of understanding.
Most of the times, the buttons are:
- Allow: it's usually the top button and permanently grants the permission,
  marking it as a fixed setting that remains unless the user actively changes it.
- Don't allow: it's the button at the bottom of the dialog and rejects the permission request,
  restricting the app's access to the requested resource for the current session.

  In older Android versions, in order to permanently deny the permission,
  users needed to check an option to remember the choice.
  More recently, since Android 11, that checkbox is no longer provided and, instead,
  the choice is automatically made permanent by rejecting the same permission twice in a row.
- Only this time: for certain permissions that also involve a background access---like camera or location permissions---a third button may appear in the middle.
  This "Allow once" option grants access only for the current app session.
  For example, the camera permission applies to foreground access only,
  while a separate `BACKGROUND_CAMERA` permission can provide background usage.
  In such cases, selecting "Only this time" grants the permission temporarily,
  revoking it when the app is closed.

This approach simplifies complex permission management for users,
allowing Android to communicate security options without overwhelming users with technical details.

It is also not the only way for users to manage runtime permissions.
System settings provide a similar interface for setting permission statuses for each installed app.
Users are required to use settings to change permissions that had been already set,
since the dialog will not be prompted anymore.

=== Permission Groups <permission_groups>
In order to avoid repetitive requests of similar permissions,
Android organizes them into _permission groups_,
based on the type of data or resource they protect.

When accepting a permission request,
Android saves the choice for the permission's group,
so that the next time a permission from the same group is requested,
the user is not prompted the permission dialog and the permission is automatically assigned the group's status.

For example, when granting an app the "Read contacts" permission, the entire "Contacts" permission group is granted.
This means that "Write contacts" (another permission in the "Contacts" group) is not granted yet,
but it will automatically be at the app's request, without user intervention.
The reverse is also true: if the user denies a permission,
every other permission in its group is immediately denied.

At a practical level,
the behavior of permission groups makes permission dialogs more closely tied to the group itself rather than to individual permissions.
This happens because permission dialogs are promoted when permission groups are unset.
To reflect this, the dialog display the permission group's icon and description,

=== Edge Cases
Since the permission dialog hides some complexity of the underlying permission model,
certain permissions and states combinations arise some peculiarities:
- `shouldShowRequestPermissionRationale`: when users deny a permission,
  they might inadvertently block a feature without fully understanding its importance.
  Android provides developers with the `shouldShowRequestPermissionRationale()` method to address this,
  allowing the app to display a rationale for the permission if the user rejected a request for it.
  This method returns `true` only if the user has denied the permission once,
  but not permanently.
- Dismissing the dialog: users can dismiss the permission dialog by tapping outside it,
  which leaves the permission unset without explicitly indicating user intent.
  In this scenario,
  Android neither marks the permission as "denied once" nor permanently denied,
  meaning that dismissing the dialog repeatedly will not lead to a fixed denial.
  As a result, `shouldShowRequestPermissionRationale` returns `false`,
  which might mislead the app into interpreting this as if the permission dialog was never shown in the first place.
- Detecting fixed denials:
  the combination of `checkPermission`---method that determines whether a permission is granted---and `shouldShowRequestPermissionRationale` is the only way for third-party developers to infer permission statuses,
  because internal permission APIs are not accessible to normal apps.
  However, these methods alone are insufficient for deducing a permission's exact state,
  particularly for fixed denials:
  where a user has permanently denied the permission.
  This is a useful information,
  that an app may want to use to inform the user that it cannot request the permission anymore.
  In such cases, `checkPermission` returns `PERMISSION_DENIED`,
  while `shouldShowRequestPermissionRationale` returns `false`.
  Unfortunately, this combination can also occur if a user dismissed the dialog without explicitly denying the permission,
  leaving the app unable to differentiate between a permanent denial and a dialog dismiss.

  This is a very specific case,
  but it creates an issue that cannot be solved completely without an official support from the OS.
  Developers exploit creative solutions to tamper it,
  but are only able to partially address the issue.
- Location group: permissions belonging to the "Location" permission group present some specific dialog layouts,
  introduced on various versions:
  - Android 10 introduced the tristate permission dialog @tristate_location,
    where users are given the choice to grant location permissions for foreground access only,
    or for background access too.
  - Android 12 introduced the possibility for users to choose between granting coarse or fine location access.
    It presents a different dialog based on the current state and permissions that are being requested,
    allowing to request the coarse location and then upgrade to the more precise version,
    or request both at the same time and let the user decide.
- Background permissions: with the introduction of the tristate location permissions on Android 10,
  background permissions appeared for the first time.
  They are permissions linked to their foreground counterpart,
  and are currently available for camera, microphone, and location permissions.
  They can be requested only after obtaining access to the foreground permissions.
  When requested they do not prompt a permission dialog.
  Instead, they redirect to a system settings activity,
  where users need to manually allow the permission.

Analyzing these behaviors is essential for understanding how Android's permission model affects app interactions with permissions.
This analysis was also useful for developing a consistent behavior for the virtual permission model,
that is presented in later chapters.

// TODO: architecture
== Implementation
=== Components
==== `PermissionService`
==== `PermissionFlags`
==== `UidPermissionPolicy`
==== `UidPermissionPersistence`
==== `PermissionController` and `GrantPermissionsActivity`
