= Background <background>
== Virtualization
=== Overview
Virtualization is a technique used to create abstractions of real environments or resources,
providing replicas that are more flexible, isolated, and scalable than their concrete counterparts.
By simulating the functionality of hardware, software, or other resources,
it allows multiple isolated environments to be created and run within a single system, often simultaneously.
This approach can be used to maximize resource efficiency or enhance security of a system,
as each virtual environment can be controlled and managed independently.

One of the earliest implementations were multiple-user operating systems for 1960s mainframes,
where each user was given a virtual environment running on the same physical device, sharing its resources.
This model was not only meant to let multiple operators access an individual mainframe concurrently,
but also to give them a private, independent space, that would simulate having a computer of their own.

The concept evolved with time and started being used for the creation of _virtual machines_ (VM),
that allow for the virtualization of the entire software,
leading to actual "computers within a computer".
VMs are managed by a hypervisor,
a software layer that coordinates and isolates them,
making it possible to run multiple operating systems on the same hardware.
This technology is frequently used to provide pre-configured machine images for reproducibility,
ensure consistent environments,
or create secure spaces that are kept isolated from the host system.

More recently, virtualization has extended its use-cases to OS-level environments,
which comes in the form of containers, created with tools such as Docker @docker and Podman @podman.
They are OS instances that share the host kernel and are widely used for creating multiple virtual servers on a same physical one,
often by creating them from scratch on the fly from a previously specified configuration.
Containers can be used for creating lightweight reproducible environments to run software tests,
compilation tasks,
or deploy modular and scalable software with pre-configured dependencies.
They are usually preferred to full VMs,
because they require a smaller overhead on system resources and simpler configuration.

=== Android Virtualization
As virtualization technology has evolved, efforts to adapt its principles to Android have emerged.
Recent works, like VPBox @vpbox, are exploring OS-level virtualization for Android,
by aiming to run isolated instances within containerized environments.
However, these methods typically require custom Android images or modifications to the system,
making them impractical for a general, end-user adoption.

Because of these limitations, app-level virtualization has become the most practical solution in the Android context.
Unlike OS-level virtualization, which demands kernel-level access and extensive configuration,
app-level virtualization handles the creation and management to a single application that operates entirely within the user-space layer,
the _container app_,
providing a convenient method for offering isolation without requiring specialized hardware or system alterations.
The creation and management of the virtual environments is handled entirely within a single application, the _container app_,
which can host one or more _plugin apps_, the virtualized apps.
This design enables features such as:

-	App cloning: running multiple instances of the same app simultaneously within isolated contexts.

-	Sandboxed environments: enabling apps to run within a more restricted and controlled environment for enhancing security and research.

-	Dynamic patches: applying hotfixes or updates to a virtualized environment without modifying the main system.

== Android Architecture
The Android architecture consists of many layered components that interact to provide essential features.
Each layer has specific responsibilities,
from user applications down to the low-level system components,
contributing to Android's performance, scalability, and security.

Virtualization frameworks have to interact with or replicate virtual versions of some components, in some occasions.
The following sections describe each layer's purpose,
in order to provide some basic understanding needed to deal with Android virtualization.

==== Application Layer
The Application layer consists of user-facing apps, that can be installed and managed by the user.
Each app runs in its own sandboxed process, ensuring security and privacy by isolating apps from one another.
The sandbox is guaranteed by these concepts:

+	UID model: a unique user ID (UID) is assigned to each app by the system, by creating a dedicated Unix user.
  This ensures that each application has its own private storage directories and files, which are kept isolated from other apps.

+	Process separation: each app runs as a separate OS process,
  which means the underlying Linux OS process isolation applies by default,
  where the OS ensures that memory and resources allocated to one process are not accessible by others unless explicitly allowed.

+	Permission model: Android enforces a fine-grained permission model that controls access to specific system resources and data.
  Permissions are granted based on the app UID and GID.

==== System Layer
The System layer includes essential system applications and services that manage core functionalities of the OS,
such as telephony, location and media.
These components are granted elevated permissions and provide services that user apps rely on but cannot directly access.

Examples of key system services include the Location Manager, Telephony Manager, Notification Manager.
Each service provides standardized APIs for apps to access sensitive resources,
often locking them with a permission.

System apps are regular apps that come pre-installed with the system image and can be granted system permissions @privileged_permissions.
They are installed under a read-only directory, to avoid deletion and modification.

==== Java API Framework
This layer provides a set of APIs that enables third-party applications to
handle UI elements, manage application lifecycles, and control interactions between applications and system services.
It is implemented as an extensive codebase of Java and Kotlin classes,
which is described in the official documentation as the same framework used by system apps @framework_api,
thus providing the entire feature-set of the Android OS.
Starting with Android 9, however,
the framework introduced a separation between SDK and non-SDK interfaces through the hidden APIs list @hidden_apis.
This created a gap between the capabilities of system applications and those available to third-party applications,
restricting access to certain internal features.

==== Binder Mechanism
The Binder mechanism is Android’s core inter-process communication (IPC) system,
used allow components running in different processes to communicate with each other.
Acting as a bridge between the application layer and system services,
it provides a way for apps to request and access services and resources managed by the system.
It is used to ensure security in the system is maintained,
by enforcing permissions and sandbox policies,
or allowing them to be enforced by the services themselves.

While not an actual layer of the Android architecture,
it is a crucial structural component.
Its role is especially relevant in app-level virtualization and in the implementation of Android's permission model.

==== Native Libraries and HAL
Many components are implemented at a lower level using native C and C++ code and require native libraries providing basic system interaction,
such as Libc, WebKit, and Media Framework.
The hardware abstraction layer (HAL) is one of these components and defines standard interfaces for hardware components,
allowing Android to interact with device hardware without requiring device-specific code at higher levels.

==== Android Runtime
Starting from Android 5,
Android runtime (ART) is the execution environment for Android apps,
each running its own instance of the runtime within its process.
It compiles and executes the app's code in the Dalvik Executable format,
a reduced bytecode format designed for minimal memory footprint on Android devices.
It is able to leverage both Ahead-Of-Time (AOT) and Just-In-Time (JIT) compilation techniques,
improving the balance between performance and memory usage.
It also provides some runtime libraries to support most of the functionality of JVM-based languages,
like the Java and Kotlin languages and Java 8 features.

==== Linux Kernel
At the foundation of the Android OS,
a custom Linux kernel manages fundamental system tasks like memory management, process scheduling and control, and device I/O.
It is configured with custom Security-Enhanced Linux (SELinux) policies,
to enforce mandatory access control (MAC) over all processes @selinux.

== VirtualXposed
// TODO: images?
=== Project Overview
The original Xposed framework is a powerful tool designed for rooted Android devices
that allows users to modify and customize system behavior at a deep level.
It was developed for older Android versions and works by injecting code directly into the Android runtime,
allowing users to change how both system and user applications behave,
without altering their APK files.
The framework hooks into the Android runtime (ART, or Dalvik in older versions),
intercepting specific method calls from apps and system services.
This hooking process allows modifications (called modules) to replace or extend the behavior of the original functions.
For example, a module could hook into the method responsible for determining app permissions,
allowing users to override permission checks or alter granted permissions dynamically.
Similarly, Xposed modules can also alter UI elements, bypass in-app restrictions, block ads, or change app functionality based on user preferences.

In the last years, Android's increasing security measures and restrictions on low-level access (more specifically SafetyNet)
have made it more challenging to keep Xposed's full functionality on newer Android versions.
Currently, Xposed has been discontinued and replaced by newer implementations,
such as LSPosed @lsposed and EdXposed @edxposed.
Additionally, root access has been progressively limited and discouraged in the Android OS over the course of time.

VirtualXposed aim is to bring this functionality to unrooted devices by creating a virtualized environment,
recreating the Xposed experience within a sandboxed space.
It uses VirtualApp at its core to install and run apps in a virtual environment,
injecting hooks at the application level.
VirtualXposed is thus limited to modifying the virtual app behavior rather than system-wide functions.

Over recent version updates,
Android has introduced various security and architectural changes,
which lead to many Xposed functionalities becoming partially broken or incompatible.
Despite these limitations,
VirtualXposed remains a valid project, providing a mature VirtualApp wrapper.
This is particularly significant since VirtualApp has been closed-sourced by its author,
meaning it is only actively maintained in its business version.
However, within the scope of VirtualXposed,
the framework has been maintained (to a certain degree) for compatibility with recent Android versions.
This currently allows VirtualXposed to provide a functional, pre-configured application that comes with a fully integrated UI and launcher,
removing the need for specific manual setup.

=== VirtualApp Architecture
// TODO: diagram?
By looking at the structure of VirtualXposed's project,
the code is divided in three Gradle projects:
- `:app` is the UI part of the application,
  declaring activities and core components that interact with the virtualization framework.
- `:launcher` is a fork of a AOSP-like launcher, adapted to be included in the application.
- `:lib` is the actual VirtualApp framework, back-end of the application.

This section explores the high-level architecture of the `:lib` project,
highlighting the purpose of components that are relevant for the following chapters.

==== Virtual Services
VirtualApp relies on services that emulate the behavior of Android original ones,
providing the same functionalities to plugin apps,
hence they are called _virtual services_.
They are usually identified in the framework by the original service name, prefixed with "V".
Acting as an intermediary layer, these services process requests from virtual apps,
either handling them directly within the virtual environment or forwarding them to the OS when necessary.

One of the key services is the `VPackageManagerService`,
which acts similarly to Android's `PackageManager` and maintains and manages the list of installed plugin apps and their resources.
This service makes sure that when a virtual app requests package information,
it gets responses adapted for the virtual environment,
while still providing access to features from the real `PackageManager` service.

==== Custom App Process and Activity Handling
To manage virtualized applications, the framework makes use of multiple processes.

An engine process, that operates as a daemon service, is kept running in the background.
It hosts server components of the framework,
which include the core virtual services and managers that handle fundamental tasks for handling plugin apps.

Additionally, the framework defines a set of 50 fixed processes, named sequentially from `:p0` to `:p49` in its manifest file.
Each of these is used to host stub activities, dialogs, and content providers,
with their lifecycles managed by the `VActivityManagerService`.
Virtual apps use these as a bridge between their virtual components and actual ones that the Android OS can see and manage.

By using this method, VirtualApp can ensure that each virtual app's components behave as if they were integrated directly into the OS,
while still providing some fundamental level of isolation.
The use of different processes, specifically, provides the inherent separation that comes with the OS' natural process isolation.

==== Dynamic Proxies
VirtualApp also uses Java's dynamic proxies to intercept system service calls made by plugin apps,
which makes it possible to modify or simulate responses as needed.
These proxies are created by defining a class that implements Java's `InvocationHandler` interface,
which allows it to wrap an object and intercept all method calls to it by implementing the `invoke` method.
This approach lets VirtualApp intercept system service calls,
forward them with modified parameters,
or return custom responses to virtual apps.

Android apps typically communicate with system services through the Binder,
with proxies automatically generated from Android Interface Definition Language (AIDL) interfaces.
In the Android Framework, for example,
the `ActivityManager` service provides its functionalities by redirecting method calls to the `IActivityManager` interface,
which is actually implemented in the `ActivityManagerService`.
To ensure that plugin apps can work within the virtual environment,
VirtualApp injects its dynamic proxies into plugin apps processes,
replacing system implementations with the framework versions.
This approach ensures that even apps that are only installed in the virtual environment can interact with Android's system services,
with the flexibility to control their behavior or manage permissions through VirtualApp's own services.

==== Virtual Environment
Since plugin applications in VirtualApp share the same UID as the container app,
from the point of view of the system,
they face challenges that have to be addressed, in the context of a virtual environment.
Typically, Android assigns a unique UID to each application,
restricting access to its private data folder, ensuring isolation between apps.
However, in VirtualApp's case,
all plugin apps use the same UID as the container app,
meaning they would have access to the same data folder.
To address this issue,
VirtualApp performs a redirection at a file system level and manages virtual UIDs.

For file system-related operations,
it uses native hooks to intercept system calls to low-level functions, such as `open()` and `fcntl()`,
and modifies file paths to redirect them to isolated storage locations, managed by `VEnvironment`.
Each plugin app is assigned a unique private folder inside the container's data folder,
ensuring they do not conflict or access each other's data.

The framework also includes a virtual UID system, handled in `UidSystem`.
Upon installation, VirtualApp assigns a unique virtual UID to the app's package,
much like the Android OS itself.
As explained in later chapters though, this UID is shared between a same app's clones.

These mechanisms must be considered by virtual services,
and this is typically handled inside virtual proxies implementations.
For instance, when an app calls `getCallingUid()`,
the proxy replaces the container's UID with the plugin app's virtual UID.
Similarly, when forwarding requests to the system,
the proxy ensures that the container's UID is properly used.

==== Mirror Classes
Supporting virtualization requires an extensive use of hidden APIs,
which have been restricted to normal apps by Android's SDK policies, starting with Android 9.
The limitations are bypassed by using a library that is able to disable the block and allow these APIs to be called via reflection.
To avoid extensive use of reflection---which requires much boilerplate code---VirtualApp provides a set of mirror classes that replicate Android platform classes,
exposing hidden APIs and fields accessible for the framework's functionality.
