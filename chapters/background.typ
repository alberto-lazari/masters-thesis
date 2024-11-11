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
- Description and evolution
- Standard way of managing permissions in sandbox applications (once for entire host app)
