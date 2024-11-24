#import "/util/common.typ": *

= Securing the Virtual Apps <implementation>
== Preliminary Work
Before actually introducing the virtual permission model, some preliminary work had to be addressed.
VirtualXposed has been currently updated to support Android versions up to Android 12, on its official open-source repository,
with a release called "Initial support for Android 12".
At the same time, a developer working on a personal fork of VirtualXposed also independently updated it to Android 12.
Both of these VirtualXposed versions had compatibility issues, but were complementary in some areas.
A merge of these two took the best of both worlds, applying fixes to one version that were developed in the other.
This created a starting point, where VirtualXposed had a decent Android 12 support, compared to older versions.
At the time of that work, however, the latest version was Android 14, so further work had to be done,
in order be able to compare the virtual environment with the native one on a current version.

=== Android 14 Support
In its initial form, VirtualXposed was incompatible with the latest version,
not even being able to install, because of many errors in the manifest.
This was because the app was originally developed for older Android versions,
and updates had introduced mandatory changes.
Required changes in the app included:
- Explicit exported components: Android 12 and later versions require that components like activities or receivers explicitly declare their export status,
  when they have intent filters.
  #code(caption: [Activity that required an explicit export status.])[
    ```xml
    <activity 
        android:name=".sys.ShareBridgeActivity"
        android:exported="true"
        android:label="@string/shared_to_vxp"
        android:taskAffinity="${applicationId}.share"
        android:theme="@style/Theme.AppCompat.Light.Dialog" >
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
    <uses-permission 
        android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"
        android:minSdkVersion="34" />
    <application>
        <service 
            android:name="com.lody.virtual.client.stub.DaemonService"
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

  #code(caption: [The two `SigningInfo` constructors in its mirror class.])[
    ```java
    @MethodReflectParams("android.content.pm.PackageParser$SigningDetails")
    public static RefConstructor<android.content.pm.SigningInfo> ctor;
    // Android 14 moved SigningDetails to a dedicated class
    @MethodReflectParams("android.content.pm.SigningDetails")
    public static RefConstructor<android.content.pm.SigningInfo> ctorUpsideDownCake;
    ```
  ] <signinginfo_constructor>
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

// TODO: build system update
=== Build System Update
- Compilation fixes
- Support for latest Java language features
- Gradle upgrade, to support more recent versions of libraries
- Switch to androidx APIs
- Library disappeared from maven repositories embedded in the project

=== Multi-User UID System
One of the main features of VirtualApp is the possibility to install multiple copies of a same application.
The framework's original implementation did not assign cloned apps a dedicated UID.
Instead, a same app would always have the same UID,
even when installed under a different virtual user.
While this design worked fine for VirtualApp itself,
since it did not actively use them,
it was a limit for implementing the virtual permission model.
Permissions in Android are managed by UID,
so without unique UIDs, an app's permissions would be managed the same across all users,
preventing to handle permission based on the current virtual user.

In order to address this, the UID system in VirtualApp was updated to reflect Android multi-user support approach.
When multi-user is enabled in the Android system,
each installed app is assigned an application-specific UID in the range 10000-19999 @app_uid,
which is then composed with the current user ID to form its actual UID.
The range of UIDs assigned per user is 100000 @per_user_range,
which means that the final UID is composed as
$"userId" times 100000 + "appId"$.
For example, the app with UID 10005 would have the same UID for the default user (user 0),
but instead, user 2 would see it with UID 210005.
This is conveniently done in the hidden API method
#raw(lang: "java", "public static int getUid(int userId, int appId)") of the class `UserHandle`,
which VirtualApp provides as visible in its `VUserHandle` class.

The change was introduced in the `getOrCreateUid()` method of `UidSystem`,
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

== Design
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
Some responsibilities are included in user interaction and the management core,
while certain elements are directly embedded into the state model.

It is also worth noting that the _registry_ component is mostly publicly accessible using Android APIs,
making a full re-implementation is unnecessary.
Instead, only few specific aspects of the registry are included inside the _state model_,
to address the limited specific needs required by the virtual model.

The following subsections detail the design requirements for each component of the virtual permission model,
illustrated in @virtual_components_diagram.

#figure(
  caption: [The components of the virtual model and their interactions.],
  image("/images/virtual-components.svg")
) <virtual_components_diagram>

=== Management Core Component
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

==== Attaching Model to Permission Management
- Use method proxies
- Patch methods?
- Some checking at native code

=== State Model Component
It defines the data structures needed to store and manage permission-related information.
It supports three key aspects of permissions: install-time permissions, runtime permissions, and permission groups.
State is managed differently, based on their type.

Additionally, permissions are organized in a hierarchy to group them under multiple UIDs and users.

==== Install-time permissions
They have a simple, binary state:
they either are granted or not.
These permissions are typically static,
reflecting whether they were approved at the time of installation,
but, they could also theoretically support updates.
This is aligned with Android's approach,
since information about install-time permissions is stored alongside runtime permissions in the `runtime-permissions.xml` file,
making status changes theoretically possible if needed.

Beyond the basic granted/not-granted status, no additional metadata is required for their management.

==== Runtime Permissions
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

- Always ask (not granted): the permission has been granted once in another session,
  or it has been set as _always ask_ from the settings.

- Always ask (granted for current execution): the permission is granted for the current session,
  but will need to be requested again in the future.

Additional details for runtime permissions have to be addressed:
- The _denied once_ status has to be reset when permissions transition to a more permissive status,
  like _always ask_ or _granted_.

- The _granted once_ status, assigned when a permission that is set to _always ask_ is granted for the current session,
  has to be reset between different app executions and when transitioning between other states.

==== Permission groups
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
  or the group status has been set to _always ask_ from the settings.

==== Hierarchical Structure for Permissions
The state model organizes permissions into hierarchical collections:
- UID permissions: set of permissions declared by a specific virtual instance of an application.

- Permissions per user: set of UID permissions for apps installed for a virtual user.

=== State Persistence Component
The persistence component is responsible for managing the interaction with the permission file that stores the state model.
It has two main responsibilities:
+ File parsing: reading and writing the permission state to and from the file,
  ensuring the state model reflects the latest data.
+ Concurrent access management: handling concurrent file access,
  since virtual apps operate in separate processes and may attempt to read or write the file simultaneously.

To achieve this, the component ensures thread and process-safe operations,
using locking mechanisms to prevent conflicts or data corruption.
It abstracts these complexities,
providing a simple interface for other components to access and modify the permission state as needed.

=== User Interaction Component
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

=== Redirection Component
The _redirection_ component is necessary to allow communication between virtual apps and the virtual permission model.
Virtual apps may either directly invoke Android's permission management APIs or execute operations that inherently trigger permission checks within their code.
This component addresses both scenarios,
by implementing dynamic proxies and native method patches to create hooks.
These hooks intercept permission-related calls and redirect them to the virtual permission _management core_,
creating the illusion that permission requests are being processed directly by the system,
when in reality, they are being managed by the virtual model,
inside the virtualization framework.

Before redirecting any request to the virtual model,
this component first checks the container app's permissions to ensure that the virtual app's request can be properly granted.
This step ensures that the virtual model is only used when appropriate,
maintaining the integrity of the permission system and preventing the redirection of requests when the container app itself lacks the necessary permissions.


== Implementation
- Host permissions
- Icons

#figure(
  caption: [Simplified architecture of the virtual permission model's classes.],
  image("/images/virtual-classes.svg")
) <virtual_classes_diagram>

=== Architecture
- Model
- `VPermissionManager`
- Dialog
- Settings activities
=== Implementation Peculiarities
- Override individual runtime permissions (with respect to its group)
- Install-time permissions could be revoked (no settings for that though)
- Dialog is not always a perfect replica (location, background permissions, ...)
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
