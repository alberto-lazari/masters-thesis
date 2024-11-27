= Discussion <discussion>
@evaluation highlights significant challenges in implementing a robust and scalable virtual permission model.
These primarily arise from the limitations of IPC calls to system services in app-level virtualization, the absence of a comprehensive permission mapping for Android, and the complexities of manual hook implementations.

== Services IPC Calls
A critical limitation comes from the nature of Android's architecture,
where many permission-sensitive operations are delegated to system services via Binder IPC calls.
Once virtual apps cross the virtualization boundary via IPC,
the execution logic is handled entirely by the Android system service.
This prevents the virtualization framework from intercepting or redirecting further API calls,
because the execution flow now moved to a separate, elevated process.

System services typically perform internal permission checks at this stage,
making the virtualization framework unable to control the result,
unless specific hooks are implemented for these operations beforehand.

// TODO: diagram?

== Potential Solutions
While various solutions could address these challenges,
each has significant limitations.

=== Manual Hooks
One possible solution is to manually create hooks for specific methods that interact with sensitive resources.
This requires replicating the permission enforcement logic of Android system services within the virtualization framework.

This method was explored by realizing the patches described in @redirection,
where manual hooks were developed for the camera and content provider operations.
These successfully enforced permissions in those specific cases and served as a proof of concept for this approach,
evaluating the effectiveness and complexity of this approach.

The evaluation however, revealed that the solution is not scalable.
Each method hook requires a deep knowledge of specific Android framework sections,
and often leads to reimplementing significant portions of their logic.
Considering the large number of methods and resources that require permission checks,
this manual approach quickly becomes unmanageable for a large-scale implementation.

=== Reinstantiating System Services <services_reimplementation>
A different approach involves replicating full copies of Android system services directly within the virtualization framework.
By redirecting all system services requests to these replicated services,
the virtual permission model could have full control over permission checks.
Since the services would exist entirely within the virtualization framework,
dynamic proxies could be configured to intercept all their permission management-related calls.

However, this approach would demand substantial memory and computational resources to replicate and manage the system services.
Furthermore, it would not be a simple plug-and-play approach,
likely requiring extensive modifications to adapt system services to be instantiated in the virtualization framework.
These adaptations would need to address compatibility issues,
as system services are designed to operate as part of Android's core infrastructure,
and also permission-related issues,
since they make extensive use of system-related permissions and resources,
which are not available to the container app.

=== Automated Permission Analysis
Another solution could involve intercepting every method call that could require a permission later on in the call stack,
and preemptively throwing a `SecurityException` for operations requiring permissions not granted by the virtual model.

While theoretically comprehensive,
this approach faces several practical challenges:
- Overly restrictive behavior:
  preemptively blocking methods risks preventing a large number legitimate operations,
  leading to frequent unexpected application crashes and a poor user experience.
- Overpermissioning:
  users may respond to frequent crashes by granting all permissions to virtual apps,
  defeating the purpose of fine-grained permission management that the model tries to address in the first place.
- Lack of a permission mapping:
  no current, comprehensive mapping exists that associates Android API methods with their required permissions.
  Efforts to create such mappings in the past,
  while useful, remain incomplete or outdated,
  making an automated solution not achievable.
- Evolving Android APIs:
  Android's API surface is vast and continuously expanding and changing.
  This complicates efforts to automate a solution,
  even if an updated and exhaustive permission mapping existed,
  because maintaining it would require continuous and periodic efforts,
  that are resource-intensive and not sustainable over time.

The two most notable Android permission mappings were provided by _aexplorer_ @aexplorer and _PScout_ @pscout.
Unfortunately, both projects have significant limitations and are outdated for modern Android versions:
+ aexplorer:
  it uses static analysis to identify permissions required by various Android APIs.
  However, as a static analysis tool, it may not address every dynamic execution path,
  making its mapping incomplete.
  The project's published results address versions up to Android 7.
+ PScout:
  it implements a dynamic analysis approach to track permission requirements at runtime,
  offering a more precise approach than aexplorer.
  However, the project has not been updated for over six years, and as a result,
  it is no longer valid for analyzing the permissions of current Android versions.
  Its published results, instead, are limited to Android 4.2 (Jelly Bean),
  which means that it does not even account for critical updates like runtime permissions introduced in Android 6.

Both tools lack coverage of key modern Android components,
such as _APEX modules_---introduced in Android 10---and the _androidx libraries_,
thus, neither tool is sufficient for providing a comprehensive permission mapping for modern Android APIs.
