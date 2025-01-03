#import "/util/common.typ": *

= Securing the Virtual Apps <implementation>
== Preliminary Work
Before introducing the virtual permission model, some preliminary work had to be addressed.
VirtualXposed has been currently updated to support Android versions up to Android 12 in its official open-source repository,
with a release called "Initial support for Android 12".
Simultaneously, a developer working on a personal fork of VirtualXposed also independently updated it to Android 12.
Although both of these VirtualXposed versions had compatibility issues,
they were complementary in some areas.
A merge of these two took the best of both worlds,
applying fixes from one version to the other.
This created a starting point,
where VirtualXposed had a sufficient Android 12 support,
compared to older versions.
At that time, however,
the latest version was Android 14, so further work had to be done,
in order be able to compare the virtual environment with the native one on a current version.

=== Android 14 Support
In its initial form, VirtualXposed was incompatible with the latest version,
not even being able to install, because of multiple errors detected in the manifest.
This happened because the app was originally developed for older Android versions,
and updates had introduced mandatory changes.

Required changes in the app included:
- Explicit exported components: Android 12 and later versions require that components like activities or receivers explicitly declare their export status,
  when they have intent filters.
  #code(caption: [Activity that required an explicit export status.])[
    ```xml
    <activity android:name=".sys.ShareBridgeActivity"
        android:exported="true"
        android:label="@string/shared_to_vxp"
        android:taskAffinity="${applicationId}.share"
        <intent-filter>
            <action android:name="android.intent.action.SEND" />
            <category android:name="android.intent.category.DEFAULT" />
            <data android:mimeType="*/*" />
        </intent-filter>
    </activity>
    ```
  ]

- Service type declaration: starting with Android 14, foreground services must specify a service type.
  VirtualApp's daemon service had to be updated to include this requirement.
  #code(caption: [Updating the daemon service.])[
    ```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"
        android:minSdkVersion="34" />
    <application>
        <service android:name="com.lody.virtual.client.stub.DaemonService"
            android:process="@string/engine_process_name"
            android:foregroundServiceType="specialUse" />
        ...
    </application>
    ```
  ]

- Service notification: similarly, since Android 8,
  services running in the background are required to display a notification.
  The app was not doing it properly, so the feature was not working as expected.
  #code(caption: [The right way of creating the notification.])[
    ```java
    getSystemService(NotificationManager.class)
        .createNotificationChannel(new NotificationChannel(
            CHANNEL_ID,
            "Daemon service notification",
            NotificationManager.IMPORTANCE_DEFAULT
        ));
    Notification notification = new Notification.Builder(this, CHANNEL_ID)
        .setContentTitle("Daemon service")
        .setSmallIcon(android.R.drawable.ic_dialog_info)
        .build();
    ```
  ]

- Use additional permissions: additional permissions were introduced over various system updates,
  and were necessary to provide specific features to plugin apps and the container app itself.
  These permissions include `QUERY_ALL_PACKAGES` and `ACCESS_BACKGROUND_LOCATION`.

Once these fixes were applied, installation could proceed successfully,
but the app still manifested many issues.
Initially, it would crash on startup, and even after fixing those errors,
many exceptions still occurred,
especially when starting virtual apps.
Many adjustments had to be done in the virtualization framework, in order to fix all these issues.

Most of these problems were caused by changes in the Android API, especially in non-SDK interfaces (hidden APIs).
Android actually introduced them in the first place to allow Android's developers to make structural changes or improvements internally,
without impacting third-party apps.

When regular apps use libraries to bypass restrictions and access hidden methods,
they still need to rely on reflection to call these methods.
This exposes them to breaking changes in the API, as reflection uses strings to invoke methods,
which cannot be checked at compile-time, leading to potential runtime errors.
VirtualApp, which heavily relies on this mechanism, encountered frequent crashes,
introduced by breaking changes in the Android SDK codebase.

Most of the times, these crashes were caused by changes in the signature of methods,
such as new parameters being introduced, or their type changed.
Examples of typical fixes are the following:
- Field type change: the update to Android 14 changed the type of the private field
  `mActions` of `IntentFilter` from `java.lang.ArrayList` to `android.util.ArraySet`.
  This change required to introduce some code forking into existing functions.
  #code(caption: [Existing implementation of a method in the framework.])[
    ```java
    public static void protectIntentFilter(IntentFilter filter) {
        List<String> actions = mirror.android.content.IntentFilter.mActions
            .get(filter);
        ListIterator<String> iterator = actions.listIterator();
        while (iterator.hasNext()) {
            String action = iterator.next();
            if (SpecialComponentList.isActionInBlackList(action)) {
                iterator.remove();
                continue;
            }
            if (SYSTEM_BROADCAST_ACTION.contains(action)) {
                continue;
            }
            String newAction = SpecialComponentList.protectAction(action);
            if (newAction != null) {
                iterator.set(newAction);
            }
        }
    }
    ```
  ]
  #code(caption: [The new method implementation, adapted for changes.])[
    ```java
    public static void protectIntentFilter(IntentFilter filter) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ArraySet<String> actions = mirror.android.content.IntentFilter
                    .mActionsUpsideDownCake.get(filter);
            for (String action : actions) {
                if (SpecialComponentList.isActionInBlackList(action)) {
                    actions.remove(action);
                    continue;
                }
                if (SYSTEM_BROADCAST_ACTION.contains(action)) {
                    continue;
                }
                String newAction = SpecialComponentList.protectAction(action);
                if (newAction != null) {
                    actions.remove(action);
                    actions.add(newAction);
                }
            }
        } else {
           // Previous implementation...
        }
    }
    ```
  ]

- Internal class becomes independent: Android 14 moved the class `android.content.pm.PackageParser$SigningDetails`
  to a dedicated class `android.content.pm.SigningDetails`. \
  This caused the constructor `SigningInfo(SigningDetails details)` not to be found using reflection.
  A new mirror class (@signingdetails_mirror_class) and a dedicated constructor for `SigningInfo` (@signinginfo_constructor) had to be introduced,
  in order to create a `SigningInfo` object,
  using a `SigningDetails` parameter of the right type.

  As shown in @snippet_dedicated_class, this type of change requires some code forking,
  based on the current Android version.

  #code(caption: [Dedicated `SigningDetails` mirror class.])[
    ```java
    public class SigningDetails {
        public static Class<?> TYPE = RefClass
            .load(SigningDetails.class, "android.content.pm.SigningDetails");
        @MethodReflectParams({
            "[Landroid.content.pm.Signature;",
            "int",
            "[Landroid.content.pm.Signature;"
        })
        public static RefConstructor<SigningDetails> ctor;
    }
    ```
  ] <signingdetails_mirror_class>
  #code(caption: [The two `SigningInfo` constructors in its mirror class.])[
    ```java
    @MethodReflectParams("android.content.pm.PackageParser$SigningDetails")
    public static RefConstructor<android.content.pm.SigningInfo> ctor;
    // Android 14 moved SigningDetails to a dedicated class
    @MethodReflectParams("android.content.pm.SigningDetails")
    public static RefConstructor<android.content.pm.SigningInfo> ctorUpsideDownCake;
    ```
  ] <signinginfo_constructor>
  #code(caption: [Code snippet that includes the `SigningDetails` update.])[
    ```java
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        Signature[] signatures = mirror.android.content.pm.PackageParser
            .SigningDetails.signatures.get(signingDetails);
        Integer signatureSchemeVersion = mirror.android.content.pm.PackageParser
            .SigningDetails.signatureSchemeVersion.get(signingDetails);
        Signature[] pastSigningCertificates = mirror.android.content.pm.PackageParser
            .SigningDetails.pastSigningCertificates.get(signingDetails);
        // Create Android 14 version of SigningDetails
        signingDetails = mirror.android.content.pm.SigningDetails.ctor
            .newInstance(signatures, signatureSchemeVersion, pastSigningCertificates);
        // Use Android 14 constructor
        cache.signingInfo = mirror.android.content.pm.PackageParser
            .SigningInfo.ctorUpsideDownCake.newInstance(signingDetails);
    } else {
        cache.signingInfo = mirror.android.content.pm.PackageParser
            .SigningInfo.ctor.newInstance(signingDetails);
    }
    ```
  ] <snippet_dedicated_class>

- Parameter changes: methods changed their parameters in multiple occasions,
  adding or removing them, causing vague errors to be raised.
  These provided no explanation about the issue,
  requiring a manual analysis of the source code of every new Android version,
  to spot the difference in a method signature.

  An example of this issue, as shown in @parameter_add,
  is the introduction of the `deviceId` parameter in `android.app.ClientTransactionHandler.handleLaunchActivity`.
  #code(caption: [`handleLaunchActivity` method signature change.])[
    #set text(.99em)
    ```java
    public abstract Activity handleLaunchActivity(ActivityThread.ActivityClientRecord r,
            PendingTransactionActions pendingActions, Intent customIntent);
    // Android 14
    public abstract Activity handleLaunchActivity(ActivityThread.ActivityClientRecord r,
            PendingTransactionActions pendingActions, int deviceId, Intent customIntent);
    ```
  ] <parameter_add>

=== Build System Update
The removal of a required dependency from Maven repositories prompted the need to update the build system for the project.
Fortunately, since the missing dependency was open-source,
it was possible to compile it manually and embed it locally into the project.
However, this necessitated an update to the build toolchain,
which, in turn, required broader updates to several outdated project components:
- The Gradle build system was updated to support more recent Android plugin and wrapper versions.
  This also introduced an automatic method for selecting the JDK to use for compilation,
  which had previously needed to be set manually in the environment.
  The update significantly improved compilation speed and overall user experience,
  while also triggering the need for additional changes across the project.
- Dependencies were fixed by compiling the missing one and setting it for local use.
- The project was migrated to AndroidX libraries,
  replacing older support libraries.
  This operation required extensive refactoring across the large codebase
  and enabled the use of newer components and dependencies versions,
  which were previously tied to the old libraries.
- Java language support was updated,
  as the VirtualApp component was previously still using Java 7.
  The new setup now supports the latest Java features,
  including functional interfaces and switch expressions.

These updates were essential for improving the development environment,
making it more efficient to use and easier to manage overall.

=== Multi-User UID System
One of the main features of VirtualApp is the possibility to install multiple copies of a same application.
The framework's original implementation did not assign cloned apps a dedicated UID.
Instead, a same app would always have the same UID,
even when installed under a different virtual user to act as a clone.
While this design worked fine for VirtualApp itself,
since it did not actively use them,
it was a limit for implementing the virtual permission model.
Permissions in Android are managed by UID,
so without a unique one,
it would not have been as straightforward to manage permissions separately for individual instances of an app.

In order to address this, the UID system in VirtualApp was updated to align with Android multi-user support approach.
In a multi-user Android system,
each installed app is assigned a unique application-specific UID in the range 10000–19999 @app_uid.
This is then composed with the current user ID to generate a unique app-user combination.
The range of UIDs assigned per user is 100000 @per_user_range,
which means that the final result is calculated as:
$ italic("userId") times 100000 + italic("appId") $
For example, an app with UID 10005 would retain it for the default user (user 0).
Instead, for user 2, it would be 210005.
This is conveniently done in the hidden API method
`public static int getUid(int userId, int appId)` of the class `UserHandle`,
which VirtualApp provides as visible in its `VUserHandle` class.

The change was introduced in the `getOrCreateUid()` method of the `UidSystem` class,
as shown in @old_uid_system and @new_uid_system.

#code(caption: [Old VirtualApp UID creation method.])[
  ```java
  public int getOrCreateUid(VPackage pkg) {
      String sharedUserId = pkg.mSharedUserId;
      if (sharedUserId == null) {
          sharedUserId = pkg.packageName;
      }
      Integer uid = mSharedUserIdMap.get(sharedUserId);
      if (uid != null) {
          return uid;
      }
      int newUid = ++mFreeUid;
      mSharedUserIdMap.put(sharedUserId, newUid);
      save();
      return newUid;
  }
  ```
] <old_uid_system>
#code(caption: [New VirtualApp UID creation method for multi-user system.])[
  ```java
  public int getOrCreateUid(int userId, VPackage pkg) {
      String packageName = pkg.mSharedUserId;
      if (packageName == null) {
          packageName = pkg.packageName;
      }
      // Get existing application UID for package name
      Integer appId = mPackageUidMap.get(packageName);
      if (appId == null) {
          // Create new application UID
          appId = ++mFreeUid;
          mPackageUidMap.put(packageName, appId);
          save();
      }
      // Return actual UID for current user
      return VUserHandle.getUid(userId, appId);
  }
  ```
] <new_uid_system>


== Design Overview <design_overview>
The virtual model retains Android's permission model's key, high-level components outlined in @functional_components,
with some adjustments to adapt them to a simpler---smaller in scope---implementation in a virtual environment.
These are present because the system's implementation has to address many system-level access cases,
where apps might want to perform tasks that require them to be granted elevated permissions,
or elevated users might try to access protected resources,
needing a different treatment than normal ones.
VirtualApp, operating in the normal user space,
has not access to privileged resources in the first place,
thus it is not required to address these edge cases.

The main difference with the system's model is the _policy engine_ not being centralized.
Since its logic is simpler, it is distributed across different components.
Certain responsibilities are included in user interaction and the management core,
while other elements are directly embedded into the state model.

Additionally, it is worth noting that the _registry_ component is mostly publicly accessible using Android APIs,
making a full re-implementation unnecessary.
Instead, only few specific aspects of the registry are included inside the _state model_,
to address the limited specific needs required by the virtual model.

Finally, the virtual model introduces a new _redirection_ component,
which provides the necessary link between virtual apps' standard behavior---based on Android's permission model---and the virtual permission model.

Together, these considerations lead to the definition of five primary components in the virtual permission model,
as illustrated in @virtual_components_diagram:
+ State model.

+ State persistence.

+ Management core.

+ User interaction.

+ Redirection.

#figure(
  caption: [The components of the virtual model and their interactions.],
  image("/images/virtual-components.svg")
) <virtual_components_diagram>

== Components Analysis
This section explores the components of the virtual permission model,
starting with an overview of their design and then moving into a detailed examination of their implementation.

Each following subsection is dedicated to a specific component and is structured in two parts:
+ Design: describes the component's design,
  outlining its responsibilities and interactions with other components in the system.
  It also addresses special cases that the component must handle,
  with a focus on how the behavior differs from its equivalent in the Android system.

+ Implementation: explains how the design concepts are realized in practice,
  providing a detailed look at the classes that implement previously identified design requirements.
  It analyzes key methods and presents example code snippets.
  A class diagram of the component is always included,
  offering a detailed look at classes architecture and their interactions.

@virtual_classes_diagram presents a simplified view over all the classes providing an implementation to the design requirements.

#figure(
  caption: [Simplified architecture of the virtual permission model's classes.],
  image(width: 90%, "/images/virtual-classes.svg")
) <virtual_classes_diagram>

=== State Model Component
==== Design
It defines the data structures needed to store and manage permission-related information.
It supports three key aspects of permissions: install-time permissions, runtime permissions, and permission groups.
State is managed differently, based on their type.

Additionally, permissions are organized in a hierarchy to group them under multiple UIDs and users.

===== Install-time Permissions
They have a simple, binary state:
they either are granted or not.
These permissions are typically static,
reflecting whether they were approved at the time of installation,
but, they could also theoretically support updates.
This is aligned with Android's approach,
since information about install-time permissions is stored alongside runtime permissions in the `runtime-permissions.xml` file,
making status changes theoretically possible if needed.

Beyond the basic granted/not-granted status, no additional metadata is required for their management.

===== Runtime Permissions
They are more complex,
requiring the state model to store detailed information about their current status and history of changes.

The possible states for a runtime permission are:
- Unrequested (default): the permission has not been requested by the application.

- Granted: the permission has been permanently granted and will not be requested again,
  unless the user explicitly changes its status from the settings.
  Auto-revoking permissions are not addressed in the virtual model.

- Denied once: the user rejected the last permission request,
  or explicitly denied it---or its group---from the settings.
  The next permission request will still prompt a permission request dialog.

- Permanently denied: after being denied once,
  the permission request has been rejected again.
  Further requests will not prompt a permission request dialog,
  unless the user explicitly changes its status from the settings.

- Always ask (not granted): the permission has been granted once in a previous session,
  or it has been set as "Always ask" from the settings.

- Always ask (granted for current execution): the permission is granted for the current session,
  but will need to be requested again in the future.

Additional details for runtime permissions have to be addressed:
- The "Denied once" status has to be reset when permissions transition to a more permissive status,
  like "Always ask" or "Granted".

- The "Granted once" status, assigned when a permission that is set to "Always ask" is granted for the current session,
  has to be reset between different app executions and when transitioning between other states.

In the context of the virtual permission model,
runtime permissions are allowed to be overridden,
that is, they can be assigned a status diverging from their current group's status.
This provides more granularity on user's permission control,
but still partially aligning to Android's model.

===== Permission groups
They reference multiple runtime permission records and are used to reduce the dependency from Android register APIs.
Their possible state can be:
- Unrequested (default): none of the permissions in the group have been set.
  Permissions could have been denied once, though.

- Granted: a permission in the group has been granted,
  or the group has been granted from the settings.
  Further requests for the other permissions in the group will not prompt a dialog and automatically grant the permission.

- Denied: a permission has been permanently denied.
  Further requests for the other permissions in the group will not prompt a dialog and automatically deny access to the permission.

- Always ask: a permission in the group has been granted once,
  or the group status has been set to "Always ask" from the settings.

===== Hierarchical Structure for Permissions
The state model organizes permissions into hierarchical collections that store permissions declared by a specific UID.
Unlike Android's implementation, a user-dedicated structure is not intended to be defined,
since user information is included in the UID itself.

==== Implementation
The component consists of a hierarchy of classes, inheriting from the abstract `Permission` base class,
and of a UID permissions container called `AppPermissions`.
The three permission types have a dedicated class each,
specializing the base implementation of `Permission`.

#figure(
  caption: [State model component class diagram.],
  image("/images/components/state-model.svg")
) <state_model_diagram>

===== `Permission`
This class serves as the abstract base for managing permissions in the state model.
It is meant to be extended by the concrete permission types,
providing a flexible interface for permission management.
This abstraction ensures safe and robust permission states handling, validation, and transitions,
while simplifying integration with the management core component.

This class also interacts with the state persistence,
providing utility methods for simplifying its tasks by hiding the complexity of the permission state logic.

The main features it provides are:
- `PermissionStatus` enum:
  defines the possible states a permission can assume:
  - `GRANTED`: the permission has been permanently granted.

  - `ALWAYS_ASK`: the permission is set to always prompt for user approval or it was granted for the current session.

  - `UNREQUESTED`: the permission has not yet been requested.

  - `DENIED`: the permission has been permanently denied,
    either by the user or via system settings.

- Constructors:
  they support various initialization scenarios:
  - Create permission instances with a name and status (as an enum or string).

  - Duplicate an existing permission.

  - Validate inputs,
    ensuring that the initial state complies with the specific permission type's constraints.

- Logic methods:
  they encapsulate the logic behind possible permission states and status transitions:
  - `boolean isGranted()`:
    check if the permission is currently granted,
    based on its status and other possible state parameters.

  - `boolean isValidStatus(Status status)`:
    designed to check whether a status can be assigned to the permission,
    considering its type and current state.

  - `ensureStatusValid()`:
    ensures the status is consistent,
    throwing an exception if invalid.

- Getter and setter methods:
  - `String getName()`:
    returns the name of the permission.

  - `Status getStatus()`:
    returns the current status of the permission.

  - `setStatus(String newStatus)`:
    allows setting the permission's status,
    ensuring that status transitions are valid.

- Helper methods:
  - `getReadableName()`:
    formats the permission name into a user-friendly representation,
    ideal for displaying it in the UI.

  - `statusToString()`:
    converts the current status to a string representation,
    useful for supporting the serialization process.

  - `setStatusFromString(String statusString)`:
    sets the permission's status based on a string input,
    ensuring that the value represents a valid status.
    It is used to support the parsing process.

===== `InstallPermission`
It extends the `Permission` base class to represent install-time permissions.
The only notable addition is its overridden `isValidStatus()` method,
which restricts valid states to `GRANTED` and `DENIED`.
This reflects the simple nature of install-time permissions' binary state,
as noted in the design.
No additional methods or functionality are needed,
as the base class already supports all the features required for install-time permissions.

===== `RuntimePermission`
The `RuntimePermission` class is a detailed specialization over the base class.
Since runtime permissions are inherently much more complex than install-time permissions,
the class introduces several specific concepts:
- Flags for complex state modeling: inspired by Android's implementation,
  runtime permissions model additional status modifiers with a set of flags,
  composed in the `flags` field to allow multiple combinations,
  which would need several dedicated enum values to be represented as the main status.
  The possible flags are:
  - `FLAG_DENIED_ONCE`: indicates that the permission has been rejected in the last user interaction.
    This flag helps determine whether the app should display a rationale when requesting the permission again.

  - `FLAG_GRANTED_ONCE`: indicates that the permission has been granted for the session,
    useful for handling cases where permissions are granted temporarily.

  - `FLAG_OVERRIDE`: indicates that the permission's behavior overrides its group's status,
    allowing for individual permission control.

- Permission group integration:
  runtime permissions are associated with a `PermissionGroup`.
  This can simplify state management,
  giving a direct access to the group's status,
  which is necessary to evaluate the actual runtime permission status.
  Additionally, it is useful for supporting cases where group information is more relevant,
  such as in permission dialogs which show the group's icon and description.

  To provide support for this concept the class includes:
  - A nullable `group` private field, accessible with its dedicated `getGroup()` method.

  - `boolean hasPermissionGroup()`: determines whether the runtime permission is associated with a group.

  - `int getGroupIconRes()`: returns the resource id of the permission's group icon,
    used by the user interaction component.

- Enhanced state management:
  - `boolean isValidStatus()`: implements the abstract method to validate the consistency between the permission's status and its group's status,
    managing edge cases such as temporary grants (`ALWAYS_ASK`) in conjunction with group overrides.

  - `boolean isGranted()`: overrides the default implementation,
    by accounting for additional cases that depend on group's status and temporary grants.

    #code(caption: [`isGranted` method implementation for runtime permissions.])[
      ```java
      @Override
      public boolean isGranted() {
          return switch (status) {
              case Status.GRANTED -> isOverridden() || group.isGranted();
              case Status.ALWAYS_ASK -> isGrantedOnce()
                  || ( hasPermissionGroup() && group.isGranted() );
              default -> false;
          };
      }
      ```
    ]

  - `shouldShowPermissionRationale()`, `isGrantedOnce()`, and `isOverridden()` return the current status of the relative flags,
    while `setDeniedOnce()`, `grantOnce()`, `override()`, and `followGroup()` allow for setting---or unsetting, in the case of `followGroup()`---a specific flag.

    #code(caption: [Method returning the current status of a flag.])[
      ```java
      public boolean shouldShowRequestPermissionRationale() {
          return (flags & FLAG_DENIED_ONCE) != 0;
      }
      ```
    ]

    #code(caption: [`grantOnce` method, updating the status and setting a flag.])[
      ```java
      public void grantOnce() {
          setStatus(Status.ALWAYS_ASK);
          flags |= FLAG_GRANTED_ONCE;
      }
      ```
    ]

  - `statusToString()` and `setStatusFromString()` extend the base class's functionality to handle serialization and parsing of flags,
    ensuring an exhaustive state representation.

- Utility methods:
  - `boolean needsRequestDialog()`:
    determines whether a permission dialog should be displayed for requesting the permission,
    based on its current complete state.

  - `boolean hasBackgroundPermission()`:
    checks if a runtime permission has an associated background permission,
    mainly used to determine how buttons should be displayed in the request dialog.

===== `PermissionGroup`
The `PermissionGroup` class provides a higher-level abstraction for managing sets of related runtime permissions.
It enables a hierarchical approach to permission management,
where permissions can inherit or override the group's status.

The class is mostly used in user interaction,
to retrieve informations like its display icon.
It is also used when granting or revoking a batch of permissions,
for example when denying a group from the settings.

The following are its main features:
-	Permission aggregation:
  it stores a set of associated runtime permissions in its `permissions` private field,
  providing a mapping from groups to individual permissions.
  It defines two simple methods to manage this set:
  +	`Set getPermissions()`:
    returns a shallow copy of the group's permissions.
    This avoids returning a direct reference to the internal set,
    but allows management for the individual permissions as they still reference the original ones.

  +	`addPermission(RuntimePermission permission)`:
    adds a runtime permission to the group,
    but only if it's not a background permission,
    because those require individual management.
    Including a background permission would cause the foreground one to automatically grant access to it,
    since they belong to the same group.

-	Group icon retrieval:
  the class provides a method to fetch the group's icon from Android's official resources,
  using `getGroupIconRes()` to get access to the internal names.
  Since permission group icons mostly follow a consistent naming pattern (`perm_group_$groupName`),
  their retrieval can be partially automated in the implementation of `getGroupIconRes(String group)`,
  as demonstrated in @group_icon_res.

  #code(caption: [`getGroupIconRes` method implementation, providing an algorithm to retrieve original permission groups icons.])[
    ```java
    public static int getGroupIconRes(final @Nullable String group) {
        final var resources = VirtualCore.get()
            .getContext()
            .getResources();
        final int defaultId = resources
            .getIdentifier("ic_perm_device_info", "drawable", "android");
        if (group == null) {
            return defaultId;
        }
        final var groupName = group
            .replaceAll("[a-z0-9.-]*", "")
            .toLowerCase();
        // Handle exceptions
        final var res = switch (groupName) {
            case "phone" -> "perm_group_phone_calls";
            case "notifications" -> "ic_notifications_alerted";
            default -> "perm_group_" + groupName;
        };
        final int id = resources.getIdentifier(res, "drawable", "android");
        if (id == 0) {
            // Use default permission icon if id not found
            return defaultId;
        }
        return id;
    }
    ```
  ] <group_icon_res>

===== `AppPermissions`
The `AppPermissions` class provides a container for managing and interacting with all permissions associated with a specific UID.

Here's a concise summary of its functionality:
- Permission storage:
  the class maintains a map in its `permissions` private field,
  where each permission is keyed by its name for quick lookups and efficient management.

- Access and filtering:
  - `Map getAll()`:
    returns a direct reference to all stored permissions.

  - `Map getAll(Class type)`:
    returns a filtered map of all permissions of a specific type.
    For example, it can be used to retrieve a complete map of all runtime permissions with `getAll(RuntimePermission.class)`.

  #code(caption: [`getAll(type)` method implementation, filtering permissions by type.])[
    ```java
    public <T extends Permission> Map<String, T> getAll(final Class<T> type) {
        return permissions.entrySet()
            .stream()
            .filter(entry -> type.isInstance(entry.getValue()))
            .collect(Collectors.toMap(Map.Entry::getKey, entry -> (T) entry.getValue()));
    }
    ```
  ]

  - `Permission getPermission(String permissionName)`:
    returns a specific permission by name.

- Permission updates:
  - `updatePermission(Permission newPermission)`:
    replaces a permission in the map with a new instance if a matching permission,
    identified by name and type,
    already exists.
    This approach ensures the permission is fully updated with the new instance,
    while maintaining consistency by only modifying declared permissions.

=== State Persistence Component
==== Design
The _state persistence_ component is responsible for managing the interaction with the permission file that stores the state model.
It has two main responsibilities:
+ Concurrent access management:
  handling concurrent file access,
  since virtual apps operate in separate processes and may attempt to read or write the file simultaneously.

+ File parsing:
  reading and writing the permission state to and from the file,
  ensuring the state model reflects the latest data.

To achieve this, the component ensures thread and process-safe operations,
using locking mechanisms to prevent conflicts or data corruption.
It abstracts these complexities,
providing a simple interface for other components to access and modify the permission state as needed.

These mechanisms are necessary because virtual apps run in separate processes,
thus stronger synchronization means like file system locks are necessary to avoid inconsistencies.

==== Implementation
The component's implementation reflects its design responsibilities by realizing the following classes:
+ Concurrent access management:
  this aspect is divided between two classes:
  - `FileLocker`:
    provides low-level functionality for acquiring and releasing shared or exclusive locks on files,
    ensuring safe operations when multiple processes or threads interact with the same file.
  - `LockedOperation`:
    abstracts `FileLocker`'s mechanisms into a higher-level framework,
    defining a lifecycle for file interactions.

+ File parsing:
  the `PermissionFileParser` class realizes the serialization and parsing of permission data between the state model and the persistence file.

The `PermissionCache` class is the primary interface for interactions with the state persistence,
sitting between the state model and persistence components.
It manages the in-memory representation of permissions while ensuring synchronization with stored data,
providing efficient access for querying or updating the model.

The four classes, illustrated in @state_persistence_diagram,
are presented in detail in the following subsections.

#figure(
  caption: [State persistence component class diagram.],
  image("/images/components/state-persistence.svg")
) <state_persistence_diagram>

===== Concurrent Access Management
The two classes implementing concurrent access to the permission file are layered,
to address the task from different abstraction levels.

Following is a description of the practical solutions used by the classes to ensure atomic file operations:
- `FileLocker`:
  the class supports two different types of locking mechanisms:
  + Shared locks: these allow concurrent read operations by multiple threads or processes.

  + Exclusive locks: these prevent any other access (read or write) to the file while the lock is held,
    ensuring safe write operations.

  It provides a generic interface to perform locked operations on a file,
  while holding one of the two possible locks.
  These operations are passed to one of the two public methods defined in the class:
  `performWithSharedLockOn(File file, Function operation)` and  `performWithExclusiveLockOn(File file, Function operation)`.

  #code(caption: [`performWithSharedLockOn` implementation.])[
    ```java
    public <T> T performWithSharedLockOn(final File file,
            final Function<FileChannel, T> operation) {

        FileChannel channel = null;
        try {
            channel = new FileInputStream(file).getChannel();
            acquireSharedLockFor(channel);
            return operation.apply(channel);
        } catch (FileNotFoundException e) {
            VLog.e(TAG, "Cannot open file %s: file not found", file.toString());
            e.printStackTrace();
        } catch (IOException | OverlappingFileLockException e) {
            VLog.e(TAG, "Cannot acquire shared lock on file %s", file.toString());
            e.printStackTrace();
        } finally {
            releaseSharedLock();
            if (channel != null) {
                try {
                    channel.close();
                } catch (IOException ignored) {
                }
            }
        }
        return null;
    }
    ```
  ] <perform_shared_lock>

  Internally, the private methods in `FileLocker` handle the specific steps required to safely manage file locks.
  These encapsulate the low-level logic to support the functionality provided by the public methods.
  Here is a breakdown of the general sequence of events, like the one seen in @perform_shared_lock:
  + A lock is acquired for the file channel,
    using either `acquireSharedLockFor(FileChannel channel)` or `acquireExclusiveLockFor(FileChannel channel)`.

  + Once the lock is acquired,
    the method executes the provided operation.
    This ensures that file operations happen safely,
    without interference from other threads or processes.

  + To avoid resource contention or deadlocks,
    the private methods explicitly release the acquired lock as soon as the operation is completed.
    This is handled in a `finally` block to guarantee the lock is released even if the operation throws an exception.

  + All the steps above are wrapped inside robust error handling blocks,
    to manage cases where lock acquisition fails,
    such as when the file is inaccessible or already locked.

- `LockedOperation`:
  it abstracts the locking mechanisms provided by `FileLocker` into a higher-level framework.
  Its implementation focuses on managing the workflow of loading and saving the state.
  Here is how it achieves this through its methods:
  - `init(Runnable onFileCreate)`:
    ensures the file exists and sets up the necessary preconditions for locked operations.
    If the file is missing,
    it invokes the provided `onFileCreate` callback to initialize an empty state.
    This method must be called manually during the system's initialization phase to set up the file for subsequent operations.

    #code(caption: [`init` method implementation.])[
      ```java
    public final synchronized void init(final Runnable onFileCreate) {
        if (file.exists() && file.isFile()) {
            // Load the file contents for the first time
            locker.performWithSharedLockOn(file, channel -> {
                ensureLoaded(channel);
                return null;
            });
        } else {
            // Open the file for writing to create it
            locker.performWithExclusiveLockOn(file, channel -> {
                // Initialize data
                onFileCreate.run();
                // Persist data initialized in `onFileCreate`
                persist(channel);
                return null;
            });
        }
    }
      ```
    ]

  - `read(Supplier operation)`:
    acquires a shared lock via `FileLocker`,
    enabling safe read access to the file without blocking other readers,
    then executes the given operation within the lock's scope,
    ensuring consistent state retrieval.

    #code(caption: [`read` method implementation.])[
      ```java
      public final <T> T read(final Supplier<T> operation) {
          return locker.performWithSharedLockOn(file, channel -> {
              ensureLoaded(channel);
              return operation.get();
          });
      }
      ```
    ] <locked_read>

  - `update(Supplier operation)`:
    uses an exclusive lock to guarantee write safety.
    It applies the provided operation while ensuring no other process or thread can read or write to the file during the update.

  - `load()` and `save()`:
    they handle the detailed file interactions during read and update operations.
    These methods are implemented by subclasses and tailored to their specific state persistence needs.

  - `ensureLoaded()`:
    verifies whether the file's last modification timestamp has changed since the previous read,
    before loading the state.
    If the timestamp---stored in `fileLastRead`---indicates that the file has been updated externally,
    it invokes `load()` to refresh the in-memory state.
    Otherwise, no action is taken, avoiding unnecessary file accesses.

    #code(caption: [`ensureLoaded` implementation.])[
      ```java
      private synchronized void ensureLoaded(final FileChannel channel) {
          if (file.lastModified() > fileLastRead) {
              fileLastRead = System.currentTimeMillis();
              load(channel);
          }
      }
      ```
    ]

  - `persist()`:
    ensures the in-memory state is saved back to the file system by invoking `save()`.
    Once the operation completes successfully,
    it updates `fileLastRead`,
    to ensure that subsequent checks correctly reflect the file's current state.

    #code(caption: [`persist` implementation.])[
      ```java
      private synchronized void persist(final FileChannel channel) {
          save(channel);
          fileLastRead = System.currentTimeMillis();
      }
      ```
    ] <locked_read>

===== File Parsing
The `PermissionFileParser` is responsible for reading and writing permission data to and from an XML-based structure,
using streams that reference the permission file.
These are obtained by using `LockedOperation`,
delegating the complex task of physical access to other classes in the component.
This allows the class to focus purely on processing the data,
without having to handle files directly.

The parser relies on standard XML parsing and transformation libraries to handle structured permission data efficiently
The high-level methods, `read()` and `write()`,
handle the setup for parsing and serialization tasks,
but delegate most of the actual work to dedicated helper methods.

Here follows a description of the defined operations:
- XML parsing (`read()`):
  the method initializes the XML structure by reading from an input stream,
  identifying `<app>` elements for each UID,
  and invoking the `fillPermissions()` helper to populate the in-memory representation with permission objects for different types (install, runtime, and groups).
  This design ensures a modular handling of XML parsing logic.

- XML Serialization (`write()`):
  this method creates an XML document by iterating over UIDs and their permissions,
  appending them as `<app>` elements.
  It uses the `addPermissions()` helper method to create and structure XML nodes for each permission type.
  The serialized output is then transformed and written to an output stream.

@permission_file provides an example of a permissions file,
showing its XML structure and the type of data it contains.

#code(caption: [Permissions file contents.])[
  #set text(.95em)
  ```xml
  <!-- /data/user/0/io.va.exposed64/virtual/data/app/system/permissions.xml -->
  <?xml version="1.0" encoding="UTF-8" ?>
  <permissions>
      <app uid="10003" >
          <install-permissions>
              <permission name="android.permission.INTERNET" status="GRANTED" />
          </install-permissions>
          <runtime-permissions>
              <permission name="android.permission.READ_CONTACTS"
                  group="android.permission-group.CONTACTS"
                  status="UNREQUESTED|deniedOnce|override" />
              <permission name="android.permission.CALL_PHONE"
                  group="android.permission-group.PHONE"
                  status="ALWAYS_ASK|grantedOnce" />
              <permission name="android.permission.WRITE_CONTACTS"
                  group="android.permission-group.CONTACTS"
                  status="GRANTED" />
              <permission name="android.permission.CAMERA"
                  group="android.permission-group.CAMERA"
                  status="GRANTED" />
              <permission name="android.permission.RECORD_AUDIO"
                  group="android.permission-group.MICROPHONE"
                  status="UNREQUESTED" />
          </runtime-permissions>
          <permission-groups>
              <permission name="android.permission-group.CONTACTS" status="GRANTED" />
              <permission name="android.permission-group.PHONE" status="ALWAYS_ASK" />
              <permission name="android.permission-group.MICROPHONE" status="UNREQUESTED" />
              <permission name="android.permission-group.CAMERA" status="GRANTED" />
          </permission-groups>
      </app>
      <!-- Other apps... -->
  </permissions>
  ```
] <permission_file>

===== `PermissionCache`
The class extends `LockedOperation`,
inheriting its locking mechanisms for safe file access,
and integrates the `PermissionFileParser` to handle XML parsing and serialization.

It stores the entire permission cache of the virtual model in its `cache` private field,
which is a mapping of `AppPermissions` objects for each UID installed in the virtual system.

Following is a breakdown of the class methods:
- `init()`:
  if the permission file does not exist,
  it will create an empty permissions cache.
  It ensures that the cache is ready before any operations are performed on it.

- `read()`:
  provides a way to safely retrieve permissions for either a specific UID or the entire permission cache,
  delegating safe file access management to `LockedOperation`'s `read()` method.
  The method ensures that the current process has permission to access the given UID's permissions, using `requirePermissionToManage(int uid)`,
  or `requirePermissionToManageAll()` if the process is trying to access the entire permission cache.

  #code(caption: [Implementation of the method for accessing a specific UID's permissions.])[
    #set text(.95em)
    ```java
    public final <T> T read(final int uid, final Function<AppPermissions, T> operation) {
        requirePermissionToManage(uid);
        return read(() -> {
            final var permissions = cache.get(uid);
            return operation.apply(permissions != null
                    ? permissions : new AppPermissions());
        });
    }
    ```
  ]
  #code(caption: [Implementation of the method for accessing the entire permission cache.])[
    #set text(.95em)
    ```java
    public final <T> T read(final Function<Map<Integer, AppPermissions>, T> operation) {
        requirePermissionToManageAll();
        return read(() -> {
            return operation.apply(cache);
        });
    }
    ```
  ]

- `update()`:
  allows modifications to the permissions of either a specific UID or the entire cache.
  Similarly to the `read()` method,
  it ensures that the calling process is allowed to modify the data.
  It acquires an exclusive lock to ensure safe write operations by using `LockedOperation`'s `update()` method,
  preventing other processes from accessing or modifying the data during updates.

- `requirePermissionToManage(int uid)` and `requirePermissionToManageAll()`:
  they enforce security restrictions based on the calling UID.
  - `requirePermissionToManage()` ensures that normal app processes can only access or modify permissions for their own UID.

    #code(caption: [Implementation of the restriction on other users' permissions.])[
      #set text(.95em)
      ```java
      private void requirePermissionToManage(final int uid) {
          final int callingUid = VBinder.getCallingUid();
          if (CORE.isVAppProcess() && callingUid != uid) {
              throw new SecurityException(String.format(
                          "User %d is trying to access user %d permissions",
                          callingUid, uid));
          }
      }
      ```
    ]

  - `requirePermissionToManageAll()` restricts access to all permission data for processes that belong to virtual apps,
    ensuring that only the virtualization framework's process can perform such operations.

    #code(caption: [Implementation of the restriction on all users' permissions.])[
      #set text(.95em)
      ```java
      private void requirePermissionToManageAll() {
          // Trigger only if current process is from a virtual app and it has been started
          if (CORE.isVAppProcess() && CORE.isStartup()) {
              throw new SecurityException(String.format(
                          "User %d is trying to access all users permissions",
                          VBinder.getCallingUid()));
          }
      }
      ```
    ]

- `load()` and `save()`:
  they implement the abstract method defined in `LockedOperation` by parsing and serializing the permission cache,
  using the `PermissionFileParser` instance present in the class.
  `LockedOperation` internal implementation of other methods will use these to keep the permissions cache synchronized with the persistence layer.

  #code(caption: [`load` method implementation, using the parser.])[
    #set text(.95em)
    ```java
    @Override
    protected void load(final FileChannel channel) {
        try {
            VLog.i(TAG, "Loading permission cache from file");
            cache = parser.read(Channels.newInputStream(channel));
        } catch (Exception e) {
            VLog.e(TAG, "Could not read permissions file");
            e.printStackTrace();
        }
    }
    ```
  ]


=== Management Core Component
==== Design
The _management core_ provides essential operations for handling permission states.
It is the interface replacing operations defined in Android's management component,
emulating their implementation and adapting it to the virtual environment.
Additionally, it includes a small compatibility layer within the virtualization framework's native library.
This layer provides native code with access to the permission management core's features implemented in the main framework,
allowing patches applied to system methods to redirect native-level permission checks to the virtual model.

Since its interactions with virtual apps are designed to mimic the system's original model,
the interface maintains a certain degree of similarity with the original component,
to simplify the redirection process.

The main responsibilities of this components are:
- Querying the current state of permissions.

- Performing operations such as granting, revoking, and supporting UI-related actions.

- Managing and maintaining the overall permission state model.

- Handling exceptions or special cases for specific permissions.

==== Implementation
The component is implemented as a single service in the virtualization framework,
inspired by Android's `PermissionManager`.
Like all other services in VirtualApp,
`VPermissionManager` is implemented following the singleton pattern,
allowing it to be easily accessed and referenced across the codebase,
similar to what the Android service mechanism itself provide.

Additionally, the component includes a native compatibility layer,
which acts as a wrapper around the Java service.
This layer simplifies access to `VPermissionManager` from JNI,
allowing native code to conveniently interact with permissions,
without needing to handle Java service calls directly.

Below is a breakdown of the component architecture,
illustrated in @management_core_diagram.

#figure(
  caption: [Management core component class diagram.],
  image(width: 65%, "/images/components/management-core.svg")
) <management_core_diagram>

===== Singleton Implementation
The singleton pattern is implemented in the class with:
- `INSTANCE`: the instance object, stored as a private, static, and final field,
  ensuring that the class is actually instantiated once.
  Because it is static it is also automatically instantiated by the Java runtime.

- Private constructor: prevents instantiation of the class from outside.

- `get()`: static method to get the singleton instance.

===== System Configuration Methods
These methods are responsible for setting up and managing system configurations related to permissions:
- `systemReady()`: initializes the permission system when the virtual app starts by loading the permission state and revoking permissions' "granted once" status.

  #code(caption: [`systemReady` method, initializing `permissionCache`'s state.])[
    #set text(size: .9em)
    ```java
    public synchronized void systemReady() {
        // Initialize the permission cache
        permissionCache.init();

        // Reset granted once status from all runtime permissions
        permissionCache.update(permissions -> {
            // Iterate on all virtual apps' permissions
            permissions.values().forEach(appPermissions -> {
                appPermissions.getAll(RuntimePermission.class).forEach((name, permission) -> {
                    if (permission.isGrantedOnce()) {
                        // Reset status to revert granted once
                        permission.setStatus(Status.ALWAYS_ASK);
                    }
                });
            });
        });
    }
    ```
  ]

- `initPermissionsForUid(int uid, VPackage pkg)`: initializes permissions when a new app is installed,
  creating permissions associations based on provided package informations.

- `removePermissionsForUid(int uid)`: removes permissions associated with an app when it is uninstalled.

===== General-Purpose Permission Management
These methods provide access to permission data and manage permission states:
- `AppPermissions getAppPermissions(int uid)`: returns permissions information for a specific UID.

  #code(caption: [`getAppPermissions` method, reading `permissionCache`'s state.])[
    ```java
    public AppPermissions getAppPermissions(final int uid) {
        return permissionCache.read(uid, Function.identity());
    }
    ```
  ]

- `Permission getPermission(String permissionName, int uid)`: returns a specific permission or permission group by name for a given UID.

- `updatePermission(String permissionName, int uid, Function operation)`: allows updating a permission's status with the generic `operation` callback.
  It gives the callback access to the permission in its current state and automatically persists any changes.

===== Specific Permission Logic Methods
These methods implement the core logic exposed to the redirection and user interaction components,
for handling specific permission checks and operations:
- `int checkPermission(String permission, int uid)`: mirrors Android's permission checking mechanism,
  returning `PERMISSION_GRANTED` or `PERMISSION_DENIED`.

- `boolean shouldShowRequestPermissionRationale(String permission, int uid)`: also mirrors its Android API counterpart,
  determining whether a rationale should be displayed for explaining a specific permission request.

- `allowPermission(String permissionName, int uid)`: implements the "Allow" button behavior in the permission dialog.
  It grants the requested permission or permission group.

- `allowPermissionOnce(String permissionName, int uid)`: it is related to a situation where the user chooses to grant a permission temporarily,
  typically associated with the "Allow once" button in the UI.
  It grants the permission for the current session only,
  meaning that it is only effective until the app is closed or the session ends.

- `doNotAllowPermission(String permissionName, int uid)`: reflects the user's choice not to allow a permission or permission group,
  which corresponds to the "Don't Allow" button in the dialog.
  It handles the logic of denying the permission, or marking it as "denied once".
  It also handles the denial of permissions within groups,
  ensuring that when a permission group is denied, the individual permissions in it are properly denied as well.

  #code(caption: [`doNotAllowPermission` method, showing a usage of `updatePermission`.])[
    #set text(size: .95em)
    ```java
    public void doNotAllowPermission(final String permissionName, final int uid) {
      updatePermission(permissionName, uid, permission -> {
        if (permission instanceof InstallPermission) {
          // Simply deny install permissions
          permission.setStatus(Status.DENIED);
        } else if (permission instanceof PermissionGroup permissionGroup) {
          // Set as unrequested, the individual runtime permissions will reflect the fact
          // that the group has been denied.
          // This allows to permissions to display the dialog, which is lines up with Android
          permissionGroup.setStatus(Status.UNREQUESTED);
          permissionGroup.getPermissions().stream()
          .filter(runtimePermission -> !runtimePermission.isOverridden())
          .forEach(runtimePermission -> {
            // Set all (non-overridden) runtime permissions in the group as denied once
            runtimePermission.setDeniedOnce();
          });
        } else if (permission instanceof RuntimePermission runtimePermission) {
          // Check if permission had been denied once
          if (runtimePermission.shouldShowRequestPermissionRationale()) {
            // RuntimePermission's setStatus will automatically set the group status
            runtimePermission.setStatus(Status.DENIED);
          } else {
            runtimePermission.setDeniedOnce();
          }
        }
      });
    }
    ```
  ]

===== Native Compatibility Layer
It provides the following utility functions in the `permission.h` header:
- `initializeCachedReferences()`: sets up static references to Java classes and methods for permission checks.
  This function is called in the framework native library initialization process.

- `bool permissionGranted(JNIEnv*, const char*)`: verifies if the calling process has the required permission.

- `int enforcePermission(JNIEnv*, const char*)`: enforces a permission check,
  returning `android::OK` if granted,
  or logging an error and returning `android::PERMISSION_DENIED` if denied.

#code(caption: [Native `enforcePermission` function implementation.])[
  ```cpp
  int enforcePermission(JNIEnv* env, const char* permission) {
    if (permissionGranted(env, permission)) {
      return android::OK;
    }
    jint pid = env->CallStaticIntMethod(binderClass, getCallingPidMethod);
    jint uid = env->CallStaticIntMethod(binderClass, getCallingUidMethod);
    // Similar to the message in CameraService.cpp
    log_err("Permission Denial: %s pid=%d, uid=%d", permission, pid, uid);
    return android::PERMISSION_DENIED;
  }
  ```
] <native_enforce_permission>

=== User Interaction Component
==== Design
This component defines how the user interacts with the permission model.
It needs to closely mirror the experience provided by Android to leverage users' familiarity with the system.
While aesthetic details can differ,
the observable behavior---such as transitions between permission states---must align exactly with Android's implementation to maintain consistency and predictability.

The main use case of this component is to display and manage UI elements,
particularly the permission dialogs that appear when a plugin app requests permissions.
It is also responsible for handling permission requests and providing the container application with settings activities to let users manage their permission preferences.

Additionally, this component addresses a crucial consideration:
when granting virtual permissions,
it checks whether the container app itself holds the corresponding permission on the actual system.
Granting a virtual permission without this verification would be both meaningless and inconsistent,
as the container app would not be able to grant the virtual apps access to the associated functionality.

==== Implementation
The component is implemented in two distinct ways,
reflecting the separation between the virtualization framework and the container app.
Each approach addresses different aspects of user interaction with the permission system:
- In the virtualization framework, user interaction is handled through dialogs that are displayed when permission requests occur.

- In the container app, user interaction focuses on managing permission preferences.

Because these interactions are distinct and implemented in physically separate parts of the codebase,
the following sections describe each approach in separately.

===== Permission Requests
As shown in @user_interaction_request_diagram,
there are two activities managing permission requests:

#figure(
  caption: [Permission requests activities class diagram.],
  image("/images/components/user-interaction-request.svg")
) <user_interaction_request_diagram>

+ `GrantPermissionsActivity` is the entry point for handling permission requests,
  coming from the redirection component.
  It mirrors the `GrantPermissionsActivity` in Android's `PermissionController` component,
  adapting it for the virtualization framework.

  Its core methods are:
  - `onCreate(Bundle savedInstanceState)`:
    initializes the activity by parsing permission request data from the intent and invokes `grantNextPermission()` to begin processing requests.

  - `grantNextPermission()`: processes the current permission request based on its status and displays the appropriate dialog (group or individual permission).
    It also checks whether the host has the required permission.
    If not, it launches the `GrantHostPermissionActivity` to alert the user and request it.

  - `grantPermission()`: perform the actual decision of either showing the dialog or directly returning a result,
    based on whether the permission is already granted or denied.

    #code(caption: [`grantPermission` method.])[
      #set text(.9em)
      ```java
      private void grantPermission(final String permissionName) {
          final var permission = permissionManager.getPermission(permissionName, uid,
                  RuntimePermission.class);
          final var group = permission.getPermissionGroup();
          if (!permission.needsRequestDialog()) {
              switch (permission.getStatus()) {
                  case Status.ALWAYS_ASK, Status.UNREQUESTED -> {
                      if (group != null && group.isGranted()) {
                          permissionManager.allowPermission(permissionName, uid);
                      }
                  }
              };
              setGrantResult(permission.isGranted()
                  ? PERMISSION_GRANTED
                  : PERMISSION_DENIED);
              return;
          }
          if (permission.isOverridden()) {
              // If not linked to group, show request dialog for the individual permission
              showPermissionRequestDialog(permission);
              return;
          }
          if (group != null && group.isGranted()) {
              // Group is already granted, grant permission too
              permissionManager.allowPermission(permissionName, uid);
              return;
          }
          // Show dialog for the permission group
          showGroupRequestDialog(permission);
      }
      ```
    ]

  - `onActivityResult(int requestCode, int resultCode, Intent data)`: handles results from host permission requests.
    If denied, it skips further requests for the same group, otherwise, it proceeds with the request for the virtual app.

  Some methods are dedicated to the dialog handling:
  - `showPermissionRequestDialog(RuntimePermission permission)`: displays a dialog for a permission not assigned to a group or that is overridden,
    thus it has to be managed individually.

  - `showGroupRequestDialog(RuntimePermission permission)`: displays a dialog for `permission`'s permission group.

  - `Dialog createRequestDialog(RuntimePermission permission, String message)`: creates a dialog showing the right options for `permission`.
    The dialog may not always be perfectly matching to the system's verison,
    due to higher complexity for specific permissions,
    such as location, media access, or background permissions.

    #code(caption: [`createRequestDialog` method, creating and customizing the dialog.])[
      #set text(.9em)
      ```java
      private Dialog createRequestDialog(RuntimePermission permission, String message) {
          final var permissionName = permission.getName();
          final var dialog = new Dialog(this);

          // ...

          icon.setImageResource(permission.getGroupIconRes());
          messageView.setText(Html.fromHtml(message));
          allowButton.setOnClickListener(view -> {
              permissionManager.allowPermission(permissionName, uid);
              dismissWith(PERMISSION_GRANTED, dialog);
          });
          onlyOnceButton.setOnClickListener(view -> {
              permissionManager.allowPermissionOnce(permissionName, uid);
              dismissWith(PERMISSION_GRANTED, dialog);
          });
          doNotAllowButton.setOnClickListener(view -> {
              permissionManager.doNotAllowPermission(permissionName, uid);
              if (group != null) {
                  // Don't keep requesting permissions for the same group
                  groupsToSkip.add(group.getName());
              }
              dismissWith(PERMISSION_DENIED, dialog);
          });
          dialog.setOnCancelListener(view -> {
              setResultAndFinish(RESULT_CANCELED);
          });
          if (!hasBackgroundPermission) {
              onlyOnceButton.setVisibility(TextView.GONE);
          }

          // ...

          return dialog;
      }
      ```
    ]

  - `setGrantResult(int grantResult)`: updates the `grantResults` array and advances the request loop.

  - `setResultAndFinish(int resultCode)`: finalizes the activity with the results.

+ `GrantHostPermissionActivity` manages host-level permission requests when the virtualization framework identifies that the host lacks necessary permissions.

  Key methods include:
  - `onCreate(Bundle savedInstanceState)`:
    initializes the activity by retrieving permission details from the intent and displays an alert dialog explaining the request.

  - `onRequestPermissionsResult()`: handles the result of the user's decision.
    If the permission is granted, it automatically requests all permissions in the group to prevent any future warning.
    If it seems denied permanently, it presents another dialog linking to the app settings.

  - `setResultAndFinish(int resultCode)`: finishes the activity with the result.

  Deprecated permissions, identified through `DEPRECATED_PERMISSIONS`,
  are skipped automatically without user interaction, based on the current Android API level.
  This ensures obsolete requests do not disrupt the workflow.

#{
  set text(.9em)
  grid(
    columns: (1fr, 1fr, 1fr),
    inset: .8em,
    figure(
      caption: [Missing host permission alert.],
      image("/images/components/host-permission-alert.png")
    ),
    figure(
      caption: [Host permission dialog, notice VirtualXposed's name],
      image("/images/components/host-permission-request.png")
    ),
    figure(
      caption: [Virtual permission dialog.],
      image("/images/components/virtual-permission-request.png")
    ),
  )
}

===== Permission Preferences
Permission preferences are also managed by two different activities,
represented in @user_interaction_settings_diagram:

#figure(
  caption: [Permission preferences activities class diagram.],
  image("/images/components/user-interaction-settings.svg")
) <user_interaction_settings_diagram>

+ `PermissionsActivity` is the entry point for managing app permissions via a settings-like interface.
  It includes an inner `PermissionsFragment` that displays and manages the UI components for permission preferences.

  After setting being set as the main content of the activity,
  `PermissionsFragment` calls its `onCreatePreferences()` method.
  This method loads the top-level preferences from the layout and initializes the fragment's context and UI elements.
  The layout consists of:
  - A switch to toggle alerts for denied host permissions.
    This switch is tied to a key stored in shared preferences and is dynamically updated based on the current settings.

  - A list of all installed virtual apps preferences,
    redirecting to their specific `PermissionManageActivity`.

  The applications list is then created with `loadApps()`.
  This list is used to dynamically create the list of `AppPreference` objects for each app with `createAppPreference()`,
  associating it with the relevant app-specific data and click behavior.

  #code(caption: [`createAppPreference` method, creating a button to launch the relative `PermissionManageActivity`.])[
    ```java
    private Preference createAppPreference(final AppManageInfo app) {
        final CharSequence appName = app.getName();
        final AppPreference appPreference = new AppPreference(ctx, app);
        final int uid = VPackageManager.get().getPackageUid(app.pkgName, app.userId);

        appPreference.setKey("app_permission_preference_" + appName);
        appPreference.setTitle(appName);
        // The actual icon will be set dynamically
        appPreference.setIcon(DEFAULT_APP_ICON);
        appPreference.setLayoutResource(R.layout.item_app_permission);
        appPreference.setOnPreferenceClickListener(preference -> {
            final Intent intent = new Intent(ctx, PermissionManageActivity.class);
            intent.putExtra(EXTRA_APP_NAME, appName);
            intent.putExtra(EXTRA_APP_UID, uid);
            intent.putExtra(EXTRA_PERMISSIONS_TYPE, PermissionGroup.class);
            startActivity(intent);
            return true;
        });

        return appPreference;
    }
    ```
  ]

+ `PermissionManageActivity` is designed to provide detailed control over app permissions,
  allowing users to manage permissions for a specific app.
  The activity is initialized with intent extras that pass the app name, UID, and permission type.
  Based on `type`, the activity shows different layouts,
  to reflect the differences between the states that install-time permissions, runtime permissions, and permission groups can assume.
  Initially, `PermissionsActivity` starts the activity with type "group",
  which shows a preference in its layout that allows the overriding of runtime permissions.
  This is done in this same activity, by passing `RuntimePermission` as type.
  It could also support install-time permissions out of the box,
  but this deviates from Android's model design.

  Just like `PermissionsActivity`, the activity replaces its content with a `PermissionsFragment` in its `onCreate()` method.
  The fragment categorizes permissions into four groups, based on permissions' state and type:
  - Allowed: granted to the app.

  - Ask: runtime permission or permission group needing a request.

  - Denied: permanently denied.

  - Follow group: runtime permission that is set to follow its group's status.

  In its `onCreatePreferences()` method,
  the fragment creates a `PermissionPreference` for each permission of the specific type with `createPermissionPreference()`.

  `PermissionPreference` includes methods to modify permissions' status:
  - `showContextMenu()`: when clicked, the preference shows a context menu with options to update the permission's status.

  - `handleMenuChoice(int choice)`: uses `permissionManager` to perform the permission update in the model.
    Then it calls `updateCategories()`, to move the preference accordingly in the UI.

  #code(caption: [`handleMenuChoice` updating the permission state and refreshing the UI.])[
    ```java
    private void handleMenuChoice(final int choice) {
        if (choice == R.id.action_group) {
            permissionManager.updatePermission(RuntimePermission.class,
                permission.getName(), uid,
                newPermission -> {
                    final var group = newPermission.getPermissionGroup();
                    newPermission.followGroup();
                    newPermission.setStatus(group.getStatus());
                });
            updateCategories();
            return;
        }

        if (permission instanceof RuntimePermission runtimePermission) {
            runtimePermission.override();
        }
        if (choice == R.id.action_allow) {
            permissionManager.allowPermission(permission.getName(), uid);
        } else if (choice == R.id.action_ask) {
            permissionManager.updatePermission(permission.getName(), uid,
                newPermission -> {
                    newPermission.setStatus(ALWAYS_ASK);
                });
        } else if (choice == R.id.action_do_not_allow) {
            permissionManager.doNotAllowPermission(permission.getName(), uid);
        }
        updateCategories();
    }
    ```
  ]

#{
  set image(height: 50%)
  set text(.9em)
  grid(
    columns: (1fr, 1fr),
    inset: .8em,
    figure(
      caption: [Apps list in permissions activity.],
      image("/images/components/permissions-activity.png")
    ),
    figure(
      caption: [_TestApp_ permission manage activity.],
      image("/images/components/permission-manage.png")
    ),
  )
}

=== Redirection Component <redirection>
==== Design
The redirection component is necessary to allow communication between virtual apps and the virtual permission model.
Virtual apps may either directly invoke Android's permission management APIs or execute operations that inherently trigger permission checks within their code.
This component addresses both scenarios,
by implementing dynamic proxies and native method patches to create hooks.
These hooks intercept permission-related calls and redirect them to the virtual permission management core,
creating the illusion that permission requests are being processed directly by the system,
when in reality, they are being managed by the virtual model,
inside the virtualization framework.

Before redirecting any request to the virtual model,
this component first checks the container app's permissions to ensure that the virtual app's request can be properly granted.
This step ensures that the virtual model is only used when appropriate,
maintaining the integrity of the permission system and preventing the redirection of requests when the container app itself lacks the necessary permissions.

==== Implementation
The main focus is on redirecting core methods of the Android API, particularly:
- `checkPermission`: as "the only public entry point for permissions checking" @checkPermission,
  it is a fundamental element of the system.
  By redirecting this method, all permission checks made directly from virtual apps will target the virtual permission model.

- `requestPermissions`: handles permission requests, sending them to the `PermissionController` using an Intent.
  By hooking into the `startActivity` method, it is possible to redirect permission requests to the virtual model.

Both `checkePermission` and `requestPermission` are managed by the `ActivityManagerService`,
allowing the use of dynamic proxies to handle their redirection.
The framework already defines proxies for these methods,
so the implementation mostly consists in integrating virtual permission logic into the existing system.

In addition to redirecting core methods,
specific features are addressed to extend the support to practical use cases:
- Permission checks are applied before executing actions on content providers,
  with all operations patched to enforce the required read and write permissions.

- A native patch is implemented on the `native_setup` method of the `Camera` class to verify virtual permissions before granting access.
  This extension ensures that components relying on native code can also be subject to the virtual permission model.

#figure(
  caption: [Redirection component class diagram.],
  image(width: 73%, "/images/components/redirection.svg")
) <redirection_diagram>

===== Method Proxies
Methods supporting dynamic proxy hooking are redirected by defining inner classes inheriting from `MethodProxy` in the `MethodProxies` class.
These proxies are eventually injected into the `ActivityManagerStub`,
replacing plugin apps' calls to their system counterparts with custom implementations of the `call()` method.

The implemented proxies are the following:
- `CheckPermission`: it first validates host-level permission and then checks the corresponding virtual permission,
  delegating model access and logic to the management core.

  #code(caption: [`checkPermission` method proxy implementation.])[
    #set text(.9em)
    ```java
    @Override
    public Object call(Object who, Method method, Object... args) throws Throwable {
        final String permission = (String) args[ARG_PERMISSION];
        final int vuid = getVUid();
        if (vuid != getBaseVUid()) {
            // android.os.UserHandle.getAppId(uid) returned the base app id,
            // although here it's important to preserve userIds.
            // Restore the VUid for the correct userId, otherwise it would return a
            // SecurityException for accessing the baseVUid permissions
            args[ARG_UID] = vuid;
        }
        final int uid = (int) args[ARG_UID];

        // Check host permission first
        args[ARG_UID] = getRealUid();
        final int hostStatus = (int) method.invoke(who, args);
        if (hostStatus == PackageManager.PERMISSION_DENIED) {
            VLog.e(TAG, "Checking permission '%s' for uid=%d: permission is denied for host",
                    permission, uid);
            return PackageManager.PERMISSION_DENIED;
        }

        final int status = VPermissionManager.get().checkPermission(permission, uid);
        VLog.d(TAG, "Checking permission '%s' for uid=%d: permission %s", permission, uid,
                status == PackageManager.PERMISSION_GRANTED
                    ? "GRANTED"
                    : "DENIED");
        return status;
    }
    ```
  ]

- `StartActivity`: it identifies actions matching ACTION_REQUEST_PERMISSION and redirects permission requests to the user interaction component.
  It ensures that all permission requests from virtual apps are intercepted,
  whether started via API calls or intents.

  #code(caption: [Code redirecting the permission request to `GrantPermissionsActivity`.])[
    #set text(.9em)
    ```java
    private void handlePermissionRequest(final Intent intent, final IBinder token) {
        final Context appContext = VActivityManager.get().getActivityRecord(token).activity;
        final ApplicationInfo applicationInfo = appContext.getApplicationInfo();
        final int stringId = applicationInfo.labelRes;
        final String appName = stringId == 0
            ? applicationInfo.nonLocalizedLabel.toString()
            : appContext.getString(stringId);

        intent.putExtra(GrantPermissionsActivity.EXTRA_APP_NAME, appName);
        intent.putExtra(GrantPermissionsActivity.EXTRA_APP_UID, getVUid());
        intent.setComponent(new ComponentName(getHostContext(),
                    GrantPermissionsActivity.class));
    }
    ```
  ]

- `GetContentProvider`: it adds a generalized check on read and write permissions for getting a content provider by using the `checkContentProviderPermission` method,
  which mirrors the equivalent in the Android API.

  #code(caption: [Permission checking flow for general content provider retrieval.])[
    #set text(.85em)
    ```java
    private String checkContentProviderPermission(ProviderInfo cpi, int callingPid, int callingUid) {
        final VPermissionManager permissionManager = VPermissionManager.get();
        if (cpi.readPermission == null && cpi.writePermission == null) {
            return null;
        }
        if (permissionManager.checkPermission(cpi.readPermission, callingUid)
                == PackageManager.PERMISSION_GRANTED) {
            return null;
        }
        if (permissionManager.checkPermission(cpi.writePermission, callingUid)
                == PackageManager.PERMISSION_GRANTED) {
            return null;
        }
        return "Permission Denial: opening provider " + cpi.name
                + " from (pid=" + callingPid + ", uid=" + callingUid + ")"
                + " requires " + cpi.readPermission + " or " + cpi.writePermission;
    }

    @Override
    public Object call(Object who, Method method, Object... args) throws Throwable {
        String name = (String) args[ARG_NAME];
        int userId = VUserHandle.myUserId();
        ProviderInfo info = VPackageManager.get().resolveContentProvider(name, 0, userId);
        if (info == null) {
            final ProviderInfo cpi = getPM().resolveContentProvider(name, PackageManager.GET_META_DATA);
            final int pid = VBinder.getCallingPid();
            final int uid = VBinder.getCallingUid();
            final String msg = checkContentProviderPermission(cpi, pid, uid);
            if (msg != null) {
                throw new SecurityException(msg);
            }
        }
        // ...
    }
    ```
  ]

===== Content Providers Permission Enforcement
To maintain precise control over content provider access,
individual content providers methods are patched.
All operations are redirected to enforce permissions before execution,
as detailed in @content_provider_ops.

To achieve this,
an `enforcePermissions()` method is invoked before performing any operation,
from the `ProviderHook` dynamic proxy.
Depending on whether the operation involves reading or writing restricted data,
the method delegates checks to either `enforceReadPermission()` or `enforceWritePermission()`.
Both methods closely mirror their Android system counterparts,
generating similar error messages when access is denied.

This approach allows the system to enforce permissions consistently across all interactions with content providers,
ensuring that virtual apps cannot bypass restrictions in any way.

#code(caption: [`enforcePermissions` implementation, for checking content providers.])[
  #set text(.85em)
  ```java
  private int enforcePermissions(final String method, final Object[] args, final int start)
          throws OperationApplicationException {

      if (args != null && args.length > start && args[0] != null && args[start] != null
              && args[0] instanceof android.content.AttributionSource accessAttributionSource
              && args[start] instanceof Uri uri) {
          return switch (method) {
              case "query", "canonicalize", "uncanonicalize", "refresh" ->
                  enforceReadPermission(accessAttributionSource, uri);
              case "insert", "bulkInsert", "delete", "update" ->
                  enforceWritePermission(accessAttributionSource, uri);
              case "applyBatch" -> {
                  final var operations = (ArrayList<ContentProviderOperation>) args[start + 1];
                  for (final var operation : operations) {
                      if (operation.isReadOperation()) {
                          if (enforceReadPermission(accessAttributionSource, uri)
                                  != PackageManager.PERMISSION_GRANTED) {
                              throw new OperationApplicationException("App op not allowed", 0);
                          }
                      }
                      if (operation.isWriteOperation()) {
                          if (enforceWritePermission(accessAttributionSource, uri)
                                  != PackageManager.PERMISSION_GRANTED) {
                              throw new OperationApplicationException("App op not allowed", 0);
                          }
                      }
                  }
                  yield PackageManager.PERMISSION_GRANTED;
              }
              default -> PackageManager.PERMISSION_GRANTED;
          };
      }
      return PackageManager.PERMISSION_GRANTED;
  }
  ```
] <content_provider_ops>

===== Camera Patch
To enforce permissions in native-level camera operations,
a patch is applied to the `native_setup()` method of the `Camera` class.
This ensures that permission checks are performed before any camera access is granted,
integrating seamlessly with the virtual permission model.

The patch utilizes the native management core compatibility layer,
specifically the `enforcePermission()` function,
to validate the Camera permission.
Instead of returning the camera ID,
the patched method returns an error code:
`android::OK` on success or a failure code if the permission check fails.
This behavior aligns with standard error-handling conventions in native Android systems.

@native_patch showcases the implementation of the method patch.
#code(caption: [`native_setup` native method patch.])[
  #set text(.85em)
  ```cpp
  static jint new_native_cameraNativeSetupFunc_T5(JNIEnv *env, jobject thiz, jobject cameraThis,
                                                  jint cameraId, jstring packageName,
                                                  jboolean overrideToPortrait,
                                                  jboolean forceSlowJpegMode) {

      int rc = enforcePermission(env, "android.permission.CAMERA");
      if (rc != android::OK) {
        return rc;
      }
      jstring host = env->NewStringUTF(patchEnv.host_packageName);
      return patchEnv.orig_native_cameraNativeSetupFunc.t5(env, thiz, cameraThis, cameraId, host,
                                                           overrideToPortrait, forceSlowJpegMode);
  }
  ```
] <native_patch>
