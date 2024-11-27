#v(1cm)

= Abstract
Android app-level virtualization allows Android apps to run in isolated environments within a host app.
However, existing virtualization solutions lack a dedicated virtual permission management system,
which creates a significant security concern.
When the host app requests a permission,
it is granted for all virtual apps running within it,
even if those virtual apps do not require or should not have access to that permission.
This happens because the host app is the one requesting permissions,
and virtual apps inherit them,
without undergoing their own individual permission checks in the virtual environment.
As a result, they may gain unintended access to sensitive resources,
particularly when multiple virtual apps share the same host.

The implementation builds upon an existing virtualization framework,
redirecting permission-related operations to this custom model,
enabling fine-grained permission management for virtual apps.
The evaluation proves that this approach successfully enforces permissions for basic use cases and specific features,
treating virtual apps individually.

However, the thesis also identifies and motivates significant challenges when scaling this solution to handle more complex interactions.
These challenges are due to limitations inherent to app-level virtualization in Android's architecture.
Potential solutions are explored, with an emphasis on their limitations and the need for further refinement.
