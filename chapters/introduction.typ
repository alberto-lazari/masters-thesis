= Introduction
Android virtualization is a tool for enhancing functionality, security, and flexibility of applications,
by installing and running them inside virtual environments.
It provides isolation from the rest of the system and is widely used for purposes such as app cloning,
running apps in sandboxed spaces,
and even applying hotfixes to the environment without requiring a full software updates @virtualpatch.

App-level virtualization is one of the most popular methods of Android virtualization,
due to its convenience,
and comes in the form of container apps that are able to host virtual applications (or _plugin_ apps) inside of them,
without the need of system or firmware modifications.
Although app-level virtualization allows multiple virtual apps to run inside a container with some degree of isolation,
it is not able to provide a completely separated environment for each plugin app.
The main limitation of this approach is the fact that plugin apps are not distinguishable from the container they run into,
from the Android system perspective,
with the consequence of many standard Android security principles not applying for plugin apps,
like proper sandboxing support between virtualized apps or Android's permission model.

One of the security threats within app-level virtualization explored in previous works @parallel_space_traveling is the vulnerability of container apps to privilege escalation attacks.
In most available implementations, permissions that have been granted to the container are also automatically granted to plugin apps,
even when they should not, such as when not declaring permissions in their own manifest file or when not requesting a runtime permission.
This creates a potential security risk,
where virtual apps could inherit or exploit their container app's permissions without explicit user consent,
compromising the principle of least privilege and violating Android's permission model.

In an attempt to address these security concerns,
this thesis analyzes the Android permission model's structure and implementation in its current iteration,
by exploring parts of the Android Open Source Project (AOSP) code and the behavior of apps in recent Android versions.
Later, it proposes a custom permission management model for plugin apps within a virtual environment.
This model is then implemented as an extension of an existing Android virtualization framework, VirtualApp @virtualapp.
It is done by building upon VirtualXposed @virtualxposed, a project aiming to bring the Xposed framework functionalities to apps through virtualization,
without the need of rooting or altering the system in any way.
VirtualXposed is based on VirtualApp at its core,
but comes as a complete application that works out of the box and includes a better support for recent versions of the OS.
The final result aims to provide virtual apps with an independent, manageable permission system, emulating Android's native behavior.
