= Introduction
Android virtualization is a tool for enhancing functionality, security, and flexibility of applications,
by installing and running them inside virtual environments.
It provides isolation from the rest of the system and is widely used for purposes such as app cloning,
running apps in sandboxed spaces,
and even applying hotfixes to the environment without requiring a full software updates @virtualpatch.

Among different methods of Android virtualization,
_app-level virtualization_ is one of the most popular due to its convenience.
It comes in the form of container apps that are able to host virtual applications (or _plugin_ apps) inside of them,
without the need of system or firmware modifications.
Although app-level virtualization allows multiple virtual apps to run inside a container with some degree of isolation,
it is not able to provide a completely separated environment for each plugin app.
The main limitation of this approach is the fact that plugin apps are not distinguishable from the container they run into,
from the Android system perspective.
This causes many standard Android security principles not to be applied for plugin apps,
like proper sandboxing support between virtualized apps or Android's permission model.

As explored in previous works @parallel_space_traveling @app_in_the_middle @android_plugin,
a security threat concerning app-level virtualization is the vulnerability of container apps to privilege escalation attacks.
In most available implementations, permissions that have been granted to the container are also automatically extended to plugin apps,
even when they are not declaring permissions in their own manifest file or not requesting a runtime permission.
This creates a potential security risk,
where virtual apps could inherit or exploit their container app's permissions without explicit user consent,
compromising the principle of least privilege and violating Android's permission model.

To address these security challenges,
this thesis provides an analysis of the Android permission model's structure and implementation in its current iteration,
by exploring parts of the Android Open Source Project (AOSP) code and the behavior of apps in recent Android versions.

It later proposes a custom permission management model for plugin apps within a virtual environment.
This model is implemented as an extension of an existing Android virtualization framework: VirtualApp @virtualapp.
It is done by building upon VirtualXposed @virtualxposed, a project aiming to bring the Xposed framework functionalities to apps through virtualization,
without the need of root access or any other system modifications.
VirtualXposed is based on VirtualApp at its core,
but comes as a complete application that works out of the box and includes a better support for recent versions of the OS.
The final result aims to provide virtual apps with an independent, manageable permission system, emulating Android's native behavior.

The following chapters cover the context, design, and evaluation of this work:
- @background provides the necessary background on virtualization,
  Android’s architecture,
  VirtualXposed (particularly the VirtualApp framework structure),
  and Android’s permission model.
- @related_work reviews related work in bringing Android sandboxing principles to app-level virtualization.
- @implementation presents the design and implementation of the custom permission model for virtual apps,
  addressing challenges with permission isolation within VirtualXposed.
- @evaluation presents the evaluation of the model in the implemented cases,
  using both test cases and real-world applications.
- @discussion discusses the challenges of realizing a universal solution,
  due to how app-level virtualization operates.
- @conclusions sums up the results of the work and suggests a direction for future research by investigating on permission mapping across the latest Android platforms.
