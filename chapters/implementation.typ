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
  `android.content.IntentFilter.mActions` from `java.lang.ArrayList` to `android.util.ArraySet`.
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
#raw(lang: "java", "public static int getUid(int userId, int appId)") of the class `android.os.UserHandle`,
which VirtualApp provides as visible in its `VUserHandle` class.

The change was introduced in the #raw(lang: "java", "int getOrCreateUid()") method of `com.lody.virtual.server.am.UidSystem`,
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

== Virtual Permission Model
=== Logical Components
- Inspired by Android real model, but simplified
- Install-time permissions: why they need to be managed

=== Runtime Permissions
- Android implementation details
- My implementation
- Permission dialog
- Host permissions management

== Implementation
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
