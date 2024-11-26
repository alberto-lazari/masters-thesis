= Related Work <related_work>
Android virtualization has developed significantly over time.
In the beginning, app-level virtualization tools were widely used because of their lightweight and flexible nature.
However, these systems often struggled to properly replicate Android's sandboxing,
which led to many privacy and security problems.
Research at the time focused on addressing these issues,
but the design of app-level solutions made achieving full security a challenging task.

To overcome these limitations,
the field shifted towards OS-level virtualization,
which provides stronger isolation and better control.
Recent advancements,
such as Google’s introduction of pKVM and the Android Virtualization Framework in Android 13,
highlight this trend.
These developments allow for secure virtual machines with improved integration into the Android ecosystem.

While significant progress has been made,
Android virtualization remains an area with opportunities for further innovation.
The following sections provide an overview on key contributions and advancements in virtualization security,
highlighting both app-level and OS-level approaches and their impact on the ecosystem.

== App-Level Virtualization Security Concerns
App-level virtualization,
while providing a lightweight and flexible approach,
introduces several significant security challenges due to the lack of robust isolation between virtualized applications and the host system.
These concerns have been extensively analyzed in prior research works @parallel_space_traveling @app_in_the_middle,
with the primary issues being outlined in the following subsections.

=== Same UID Across Apps
A fundamental issue with app-level virtualization is that plugin applications are executed as separate processes within the container application,
inheriting the host's UID.
This causes Android to treat them as the same app,
leading to a lack of differentiation between the host and the virtualized apps.

Since the UID is a key element used by the system to enforce security policies and isolate apps,
this shared UID introduces several vulnerabilities.
A significant risk is that plugin apps gain access to the internal storage of the entire container app,
potentially allowing them to read sensitive data from other plugin apps,
or even inject malicious code by tampering with the internal files of these apps.

This issue is not addressed in this thesis,
as the VirtualApp framework already includes mechanisms to mitigate these risks.
However, the consistency and effectiveness of these mechanisms should be verified.

=== Privilege Escalation
Another major security concern comes from the shared UID,
which gives plugin apps access to all the permissions requested by the host application.
This creates opportunities for several types of attacks.

For instance,
a plugin app can gain access to resources not explicitly declared in its manifest,
but for which the container app has access,
since the system only enforces restrictions on the container app.
Furthermore, a plugin app could exploit the fact that the container app has been granted a dangerous permission for another virtual app,
automatically extending that permission to all other virtualized apps, including potentially malicious ones.

This unintended privilege escalation can lead to serious security breaches,
allowing apps to perform actions beyond their intended scope,
often without users noticing any anomalous behavior.

This issue is the main focus of this work.

== Boxify
Introduced in 2015 as one of the first attempts at app-level virtualization for Android,
Boxify @boxify aimed to provide full-fledged app sandboxing on stock Android devices.
Its core concept was based on app virtualization and process-based privilege separation,
which isolates untrusted apps within a controlled environment without requiring modifications to the underlying Android firmware or root access.

The primary contribution of Boxify is its ability to enforce security policies at the application layer,
creating a unique approach for sandboxed apps to communicate with the Android framework.
It used Android's isolated processes,
which are granted zero permissions by default.
The container app needed to explicitly grant them to plugin apps,
allowing for complete control over which resources the apps could access,
making it possible to implement a fine-grained permission control system.

Despite its promising concept,
Boxify was never released for public use,
and its implementation details are somewhat limited in the paper:
replicating the system would be challenging due to the lack of practical explanations.
However, the concept remains influential in discussions around Android app security and sandboxing techniques.

== OS-Level Virtualization
OS-level virtualization frameworks provide a stronger alternative to app-level virtualization by offering enhanced isolation and security guarantees.
Key projects in this domain include:
- VPDroid @vpdroid and Cells @cells: these are older, pioneering solutions focused on virtualization for Android systems,
  focused on isolated execution environments to ensure app separation and control over resource access.
  They laid the ground for many of the concepts used in modern Android virtualization.
- VPBox @vpbox: a recent solution to address some core challenges observed in app-level virtualization,
  particularly around stealth and transparency.
  The framework is capable of customizing device attributes and simulating multiple virtual devices on a single hardware system,
  all while maintaining native performance.

=== Android Virtualization Framework (AVF)
Introduced with Android 13 @avf,
it provides official OS-level support for virtualization,
marking a significant step towards secure, isolated execution environments.

This framework is designed for specific devices and allows small payloads to run in a virtualized secure environment.
It is backed by a private Kernel-based Virtual Machine (pKVM),
a hypervisor built on top of Linux's KVM,
and relies on a minimalistic environment known as Microdroid,
a stripped-down OS that lacks any graphical support.
This makes it unsuitable for general-purpose use cases,
since it is not intended to run full applications or entire operating systems.
Instead, Microdroid is optimized for running small, isolated workloads that require secure environments,
such as certain system tasks or trusted applications.

Overall, AVF is a more specialized tool compared to broader frameworks that allow full app virtualization or the execution of entire guest operating systems.
