#v(1cm)

= Abstract
Android app-level virtualization allows apps to run in isolated environments within a host app.
However, existing solutions lack dedicated virtual permission management,
posing significant security concerns.
When a host app requests a permission,
it is shared across all virtual apps in it,
bypassing individual checks and granting unintended access to sensitive resources,
especially when multiple virtual apps share the host.

This work presents a custom permission management model,
integrated into an existing virtualization framework.
It redirects permission operations to enforce fine-grained controls for virtual apps,
treating them as distinct entities.
Evaluation proves its effectiveness in enforcing permissions for basic use cases and specific features.

The thesis also addresses challenges in scaling the solution for more complex interactions,
highlighting limitations of Android's app-level virtualization architecture.
Potential approaches are explored,
emphasizing the need for further refinement.
