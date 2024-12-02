#import "/util/common.typ": *

= Android Permission Model <permission_model>
The Android permission model is designed to protect user privacy and security,
preventing apps from freely accessing sensitive information about the user or the device.
It controls access to resources and features that extend beyond the app's sandbox,
such as:
- Hardware device capabilities (e.g., internet connection, location, microphone).

- User's private data (e.g., calendar, media content, SMS).

- System and device settings.

This system of permissions gives apps a mechanism to follow the least privilege principle and increase user awareness,
creating a barrier that requires---either explicit or implicit---user or system consent before sensitive information or powerful features can be accessed.

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
and determines which steps an application needs to perform to obtain it.

Protection levels categorize permissions as follows:
+ Normal permissions:
  they grant access to simple resources that pose a low risk to user privacy and other apps' security,
  such as setting alarms, checking the network state, or controlling the flashlight status.

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
This further divides permissions into two categories, based on their protection level:
+ Install-time permissions: they are granted once during installation, and cannot be revoked.
  They include both normal permissions, which are always granted automatically, and signature permissions,
  which depend on the requesting app's certificate.

+ Runtime permissions: they have a dangerous protection level and must be requested as the app runs,
  with explicit user approval through a permission dialog.

== Runtime Permissions
By involving an interaction with the user,
_runtime permissions_ are the most complex type in the Android permission model.
These permissions require that prompts be designed to be quick and simple,
understand user intentions, and be accessible to a general user to understand them.
This complexity has led to multiple updates and adjustments throughout different Android versions,
with changes made at various levels of the permission system to simplify the user experience and improve security.

=== Permission Dialog
The permission dialog is the primary interface through which users interact with Android's runtime permissions,
and is presented every time apps request an unset permission.
To keep interactions simple, the dialog hides complex permission logic mechanisms by condensing it into just two or three buttons,
balancing user control with simplicity of understanding.
Most of the times, the buttons are as shown in @dialog_image:
- Allow/While using the app: it's usually the top button and permanently grants the permission for foreground access,
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
System settings provide a similar interface for setting permission statuses for each installed app,
illustrated in @permission_settings.
Users are required to use settings to change permissions that had been already set,
since the dialog will not be prompted anymore.

#{
  set text(.95em)
  set image(height: 35%)
  grid(
    columns: (1fr, 1fr),
    inset: .8em,
    [
      #figure(
        caption: [Permission dialog to request the camera permission.],
        image("/images/camera-request.png")
      ) <dialog_image>
    ],
    [
      #figure(
        caption: [App permissions settings interface.],
        image("/images/permission-settings.png")
      ) <permission_settings>
    ],
  )
}

=== Permission Groups <permission_groups>
In order to avoid repetitive requests of similar permissions,
Android organizes them into _permission groups_,
based on the type of data or resource they protect.

When accepting a permission request,
Android saves the choice for the permission's group,
so that the next time a request for the same group is performed,
the user is not prompted the request dialog and the permission is automatically granted or rejected,
based on its group status.

For example, when granting an app the "Read contacts" permission, the entire "Contacts" permission group is granted.
This means that "Write contacts" (another permission in the "Contacts" group) is not granted yet,
but it will automatically be at the app's request, without user intervention.
The reverse is also true: if the user denies a permission,
every other permission in its group is immediately denied.

At a practical level,
the behavior of permission groups makes request dialogs more closely tied to the group itself rather than to individual permissions.
To reflect this, dialogs display the permission group's icon and description.

Starting from Android 11,
static information about platform permission groups is no longer provided.
Platform permissions are statically defined with an `UNDEFINED` group,
with the actual one being set by the system at runtime.
While it is still possible to determine which group a platform permission belongs to,
this information must now be queried dynamically using the method `getGroupOfPlatformPermission()`.
This change reflects a move towards more granular control over permissions and reduces reliance on predefined groupings.

=== Edge Cases
Since request dialogs hide some complexity of the underlying permission model,
certain permissions and state combinations arise some peculiarities:
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
  As a result, `shouldShowRequestPermissionRationale()` returns `false`,
  which might mislead the app into interpreting this as if the permission dialog was never shown in the first place.

- Detecting fixed denials:
  the combination of `checkPermission()`---method that determines whether a permission is granted---and `shouldShowRequestPermissionRationale()` is the only way for third-party developers to infer permission statuses,
  because internal permission APIs are not accessible to normal apps.
  However, these methods alone are insufficient for deducing a permission's exact state,
  particularly for fixed denials:
  where a user has permanently denied the permission.
  This is a useful information,
  that an app might want to use to inform the user that it cannot request the permission anymore.
  In such cases, `checkPermission()` returns `PERMISSION_DENIED`,
  while `shouldShowRequestPermissionRationale()` returns `false`.
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
    As shown in @new_location_dialog,
    it presents a different dialog based on the current state and permissions that are being requested,
    allowing to request the coarse location and then upgrade to the more precise version,
    or request both at the same time and let the user decide.

- Background permissions: with the introduction of the tristate location permissions on Android 10,
  background permissions appeared for the first time.
  They are permissions linked to their foreground counterpart,
  and are currently available for camera, microphone, and location permissions.
  They can be requested only after obtaining access to the foreground permissions.
  When requested they do not prompt a permission dialog.
  Instead, they redirect to a system settings activity (@backround_location_setting),
  where users need to manually allow the permission.

Analyzing these behaviors is essential for understanding how Android's permission model affects app interactions with permissions.
This analysis was also useful for developing a consistent behavior for the virtual permission model,
that is presented in later chapters.

#{
  set text(.95em)
  set image(height: 35%)
  grid(
    columns: (1fr, 1fr),
    inset: .8em,
    [
      #figure(
        caption: [The new location permissions request dialog.],
        image("/images/cool-location-request.png")
      ) <new_location_dialog>
    ],
    [
      #figure(
        caption: [Allowing location access in the background from settings.],
        image("/images/background-location.png")
      ) <backround_location_setting>
    ],
  )
}

== Implementation
As discussed in previous sections,
the Android permission model is inherently complex---not only due to the intricate edge cases it has to address---but also because it needs to provide robust,
system-level security features to protect sensitive resources.
Additionally, with many updates and refinements over time,
the model's implementation has grown into a large, continually evolving architecture,
spread between multiple components and deep layers.

The following analysis is focused on understanding the model architecture at a higher level,
by identifying the main components that have an active role in the logic behind permission checking,
how runtime permissions are requested,
and storing and managing the status of permissions.
This architecture is taken as an inspiration for the virtual permission model,
described in later chapters.


=== Main Classes <main_classes>
Until Android 6, permission handling was managed directly by the `PackageManager` service.
Since permissions were only granted at install-time,
a single, centralized manager was sufficient.
With the introduction of runtime permissions, however,
permission management became more complex,
requiring it to be split between multiple dedicated components.

The following subsections describe the main classes involved in the current Android permission system,
as shown in @system_classes_diagram.
Each class is analyzed with respect to its responsibilities and interactions with other components,
providing a comprehensive---although simplified---view of how the system operates.

#figure(
  caption: [Simplified architecture of the permission model's classes.],
  image(width: 88%, "/images/system-classes.svg")
) <system_classes_diagram>

==== `PermissionManager`
It is the main service interface for permission management.
As a central access point,
it provides high-level methods for managing permissions and is the entry point for applications and other services needing permission information or status updates.
While normal apps cannot directly access most of its APIs,
all permission-related operations are handled by this service at some point in the call stack,
sometimes called to provide control over the permission state to publicly accessible methods in `Context` or `Activity`,
such as `checkSelfPermission()` and `requestPermissions()`.

`PermissionManager` was created to support the more complex needs of runtime permissions,
shifting permission handling from the `PackageManager` service.
As all Android services, it is implemented in a separate `PermissionManagerService` class,
which allows modular implementations by relying on a specialized `PermissionManagerServiceInterface` interface,
stored in the `mPermissionManagerServiceImpl` private field.

==== `PermissionManagerServiceImpl`
This is the underlying class implementing the detailed permissions logic exposed in `PermissionManagerService`.
It has direct access to the current internal state of all permissions in its `mState` field.
The state is modeled with multiple hierarchical classes:
- `PermissionState`: stores the current grant status and flags associated with a specific permission.
  It also provides methods to perform direct operations on the permission,
  such as `grant()`, `revoke()`, and `updateFlags()`.

- `UidPermissionState`: groups the state of permissions associated with a specific UID,
  and provides methods to interact with it,
  such as `getGrantedPermissions()` and `revokePermission()`.

- `UserPermissionState`: organizes the `UidPermissionState` instances for all applications installed under a specific user.

- `DevicePermissionState`: tracks the `UserPermissionState` associated with each user on the system.

The `DevicePermissionState` owned by `PermissionManagerServiceImpl` is initialized during boot via the `restorePermissionState()` method,
loading stored permission data.

This class also owns an internal connection with user and package managers,
to handle permissions in multi-user environments,
and retrieve information about installed packages and their declared permissions.

Additionally, its `mRegistry` field manages an internal storage of information about all known permissions in the system and their related settings.

==== `RuntimePermissionsPersistenceImpl`
It is the latest implementation responsible for managing runtime permission data persistence.
It is part of the `PermissionController` Android Pony EXpress (APEX) module that focuses exclusively on permission management,
and is responsible for reading and writing the state of a user's permissions in its `runtime-permissions.xml` file.

While legacy code is still present across the framework,
where permissions were handled by internal components using hidden APIs,
this newer approach moves the functionality into a specialized module that can be upgraded independently from the system @permission_controller.
`RuntimePermissionsPersistenceImpl` specifically takes care of the actual parsing and serialization of the XML files that store permissions data for each user.

The permissions files group every permission requested by apps installed by a user,
specifying the grant status and additional flags.
They not only group runtime permissions, as the file name implies, but also install-time ones.
@permission_xml provides an example where the Internet and NFC permissions are stored,
which are normal permissions.

#code(caption: [Example of a permission XML file.])[
  #set text(size: .9em)
  ```xml
  <!-- /data/misc_de/$userId/apexdata/com.android.permission/runtime-permissions.xml -->
  <?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
  <runtime-permissions version="10" >
    <package name="com.example.testapp" >
      <permission name="android.permission.ACCESS_FINE_LOCATION" granted="false" flags="300" />
      <permission name="android.permission.BODY_SENSORS" granted="false" flags="301" />
      <permission name="android.permission.INTERNET" granted="true" flags="0" />
      <permission name="android.permission.ACCESS_COARSE_LOCATION" granted="true" flags="80301" />
      <permission name="android.permission.CALL_PHONE" granted="false" flags="300" />
      <permission name="android.permission.WRITE_CONTACTS" granted="false" flags="300" />
      <permission name="android.permission.NFC" granted="true" flags="0" />
      <permission name="android.permission.CAMERA" granted="true" flags="301" />
      <permission name="android.permission.RECORD_AUDIO" granted="false" flags="300" />
      <permission name="android.permission.READ_CONTACTS" granted="true" flags="301" />
    </package>
    <!-- Other packages... -->
  </runtime-permissions>
  ```
] <permission_xml>

`RuntimePermissionsPersistenceImpl` exposes its features in two public methods:
+ `RuntimePermissionsState readForUser(UserHandle user)`.

+ `void writeForUser(RuntimePermisionsState runtimePermissions, UserHandle user)`.

==== `Settings`
The class dedicated to store system dynamic settings also acts as a link between the `PermissionController` module and system framework APIs.
It does so by storing a reference of the `RuntimePermissionsPersistence` and wrapping it in an internal `RuntimePermissionPersistence`
(note the missing 's').
This internal persistence manager defines APIs to interact with the actual `PermissionController` persistence,
most notably the `readStateForUserSync()` and `writeStateForUserAsync()`.
These are exposed in the `Settings` class in the methods:
- `readLPw()`: reads the entire settings for each user,
  including their permissions state.
  It is called once by `PackageManagerService` in its constructor,
  meaning that the file seems to be read once during the services initialization phase.
  Once the permissions state is loaded into memory it is managed there and, eventually,
  it will be written back to file as updates occur.

- `writePermissionStateForUserLPr()`: writes the permissions state of a specific user.
  It is called by the `PackageManagerService` method `writePermissionSettings()`,
  which, in turn, is called from `PermissionManagerServiceImpl` via its `onPermissionUpdated()` callback whenever a permission is modified.

==== `PermissionController`
This is the module dedicated to managing permissions-related UI interactions and system logic.
It is the main component addressing user-centric tasks,
regarding the granting process and permission policies in general.
Its main responsibilities are:
- Managing permission requests: this is done mainly in the `GrantPermissionsActivity`,
  which is the one creating the dialogs presented to users when applications request runtime permissions.
  Its purpose is to bridge the interaction between apps and the permission model,
  handling user inputs and interact with the model accordingly.

- Permission granting and group logic: it handles the granting logic,
  especially for runtime permissions within groups.
  When handling a permission request,
  it checks whether a permission in the same group is already granted.
  If not, it manages the change in the permission state.

- Group revoking: a specific case to manage for permission groups is the possibility for them to be revoked.
  When revoking a permission,
  the module has to extend the operation to all other permissions in the group.
  It is also possible to revoke a group directly from the settings.
  The grant status of all permissions inside of it has to be updated and managed correctly.

- Auto-revoke mechanism: it also implements the auto-revoke of permissions,
  for apps that were not being used for an extended period of time.


=== Functional Components <functional_components>
The architecture described in @main_classes, even while being a simplification,
contains several details that may be complex to keep in mind.
It may be useful to categorize the individual classes into higher-level logical components,
based on the different functional roles that can be found in the model.

@system_components_diagram shows the components described in the following subsections.

#figure(
  caption: [The functional components and their interactions.],
  image("/images/system-components.svg")
) <system_components_diagram>

==== Management Core
It provides a centralized control for querying and modifying the state of permissions.
It serves as the primary interface for all permission-related operations
and acts as the entry point for other system services and applications to interact with the permission model.
Typical operations it should implement are:
- Checking permission status for specific permissions, UIDs, or users.
- Granting or revoking permissions and manage their flags.
- Retrieving metadata about permissions or permission groups.

It is implemented in:
- `PermissionManager`.
- `PermissionManagerService`.
- `PermissionManagerServiceImpl`.

==== State Model
It defines the in-memory representation of permission data.
It provides the foundation for managing and manipulating permission states.
The data structures in this component reflect the hierarchy and relationships within the permission system,
and should:
- Track individual permissions, including their grant status and flags.
- Manage the state of permissions associated with specific UIDs.
- Aggregate UID-level states for each user in the system.
- Support multi-user environments by handling permission data for each user.

It is implemented in:
- `PermissionState`.
- `RuntimePermissionState`.
- `UidPermissionState`.
- `UserPermissionState`.
- `DevicePermissionState`.

==== State Persistence
It maintains a persistent record of permission states across system reboots by:
- Storing permission states in user-specific files.
- Loading permission data during system initialization.
- Writing updates to the storage layer whenever permissions are updated.

It is implemented in:
- `RuntimePermissionsPersistence`.
- `RuntimePermissionsPersistenceImpl`.
- `RuntimePermissionPersistenceImpl`.
- The `runtime-permissions.xml` file.

==== Policy Engine
It is the decision-making layer, enforcing rules and constraints on permission operations,
and ensuring that all actions are aligned with system policies and security requirements.

It needs to implement the logic closer to user interactions,
such as group-based constraints for granting and revoking permissions.

It is implemented in the `PermissionController`,
more specifically in its service.

==== User Interaction Layer
This layer fills the gap between the permission system and the user.
It handles user-facing operations,
ensuring that the system is able to communicate permission requirements and decisions clearly.

Its main use-case is presenting permission request dialogs to users,
following a group-based permission logic, and managing their input.

It is implemented in the `GrantPermissionsActivity` of the `PermissionController` module.

==== Registry
It maintains a catalog of all known permissions and their attributes,
providing metadata about each permission and supporting querying operations needed by other components.

This component is not explored in detail,
since the virtual permission model is able to re-use Android's implementation,
so a deep understanding is not needed.
