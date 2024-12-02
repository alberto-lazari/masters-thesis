= Introduction
As one of the most widely used mobile operating systems,
Android is built around robust security principles.
Fine-grained permission management is one of the fundamental ones,
controlling access to sensitive resources like contacts, camera, and location data,
it ensures that apps can only access what they explicitly request and receive user approval for.
This permission model has evolved significantly over the years to address the growing complexity of mobile ecosystems
and to meet the increasing demand for secure app interactions.
However, this principle of precise, user-mediated permission enforcement breaks down in the context of app-level virtualization frameworks.

Android _app-level virtualization_ is a technique that enables multiple apps to run within a single host app,
each in its isolated virtual environment.
While this approach can be used to enhance security through isolation,
it fundamentally alters the way permissions are handled.
In most app-level virtual environments,
virtual apps do not independently request permissions.
Instead, they inherit the permissions granted to the host app.
This creates a critical vulnerability:
a virtual app can access sensitive resources it does not need or should not have,
simply because the host app has been granted those permissions.

This behavior undermines Android's permission model,
particularly in scenarios where multiple virtual apps share the same host.
The lack of fine-grained permission management in such environments not only compromises user privacy,
but also exposes the limitations of app-level virtualization in following Android's security principles.
It is also a critical security threat,
enabling virtual apps to perform privilege escalation attacks.

The main goal of this thesis is to address this issue,
by proposing and implementing a custom virtual permission model for Android app-level virtualization.
This model aims to replicate and extend the native Android permission system,
to ensure that virtual apps are subject to proper permission checks and that permissions are managed for individual apps.
To realize this, the work focuses on extending an existing app-level virtualization framework,
by integrating the custom model in a virtual permission management system that intercepts permission-related operations from virtual apps,
ensuring fine-grained access control.

Before designing this custom permission model,
Android's native permission model implementation is analyzed by exploring parts of the Android Open Source Project (AOSP) code and the behavior of apps in recent Android versions.
This step ensures that the virtual system closely resembles the system's original permission model,
enabling smooth interaction and compatibility between the two.
By understanding how Android's permission system operates,
the virtual framework can easily replace the it in the virtual environment,
safely managing permissions for virtual apps in a consistent way.

This work also details the virtual permission model's implementation and evaluates it through both controlled tests and a real-world application
to prove its ability to enforce appropriate permission management in the virtual framework.
Additionally, the challenges and limitations of scaling this model to handle more complex system-level interactions are discussed,
particularly their relations to the constraints of app-level virtualization and Android's architecture.

Finally, potential future directions are explored,
including research into OS-level virtualization as a promising solution to address the limitations of app-level approaches.
Additionally, alternative solutions to overcome the limitations of the current virtual permission model are discussed,
aiming to enhance its scalability and effectiveness in more complex scenarios.
