= Evaluation <evaluation>
The evaluation of the virtual permission model was performed using two distinct methods:
a custom _TestApp_ and _Telegram_, a widely used real-world application.
This dual approach ensured a comprehensive evaluation of the model,
testing its functionality in both controlled and practical contexts.
Additionally, this evaluation highlighted the inherent challenges and limitations of achieving a generalized solution,
capable of addressing every possible edge case in permission management.

== TestApp
The _TestApp_ was specifically designed to create a controlled environment for testing key aspects of the permission model.
Its activities included layouts that supported the testing of specific permission-related operations.
This approach allowed for an in-depth verification of system's features correct integration with virtual app's interactions,
in the context of a controlled and manageable environment,

Additionally, the app provided valuable insights into Android's permission model,
when installed and run outside the virtualization framework.
This dual use offered a unique perspective on how the model operates in both contexts.

Comparisons of the same operations performed within and outside the virtual environment were critical for ensuring consistent behavior.
Differences in the app's behavior identified during these tests allowed for the systematic identification and resolution of errors,
ensuring that app functionality remained unchanged across environments.

The following subsections describe _TestApp_'s activities and the implemented operations.

=== PermissionRequestActivity
The `PermissionRequestActivity` is designed to validate the core permission mechanisms in the virtual environment,
focusing on two critical operations: `checkPermission()` and `requestPermissions()`.
The activity provides an interactive interface that allows users to test and visualize the permission states of individual permissions,
allowing for a direct comparison between the virtual environment and the native Android system.

The operations are implemented in a user-friendly way,
providing easy interaction and immediate visual feedback:
+ Permission check: it allows users to retrieve the current permission status of a predefined permissions list.
  Each permission is associated with a label displaying its current status,
  such as “Granted”, “Denied”, or “Should show rationale”.
  A button next to each permission triggers the `checkPermission()` method,
  which updates the displayed status.
  By checking permissions both inside and outside the virtual environment,
  it is possible to verify whether the system is consistent in managing permission statuses across different contexts.

+ Permission request: it tests the app's ability to request permissions and ensures that the correct permission dialogs are displayed.
  Each permission in the list has a button that triggers the `requestPermissions()` method for that specific permission.
  Additionally, a “Request all permissions” button allows for testing multiple permission requests simultaneously.
  This functionality is essential for verifying that the app can handle bulk permission requests correctly
  and that the system responds properly to multiple requests at once,
  displaying the appropriate dialogs for each permission.

=== ContactsActivity
The `ContactsActivity` is designed to test the permission control mechanisms applied to content providers,
specifically the _Contacts_ content provider.
This activity verifies the app's ability to read, modify, and manage contacts data,
which is tightly controlled by permissions in Android.
Each operation in this activity is crucial for ensuring that the permission model properly manages and enforces permissions for every possible content provider operation.

The operations are as follows:
- Read contact: `readContact()` reads the contacts content provider, using its `query()` method.
  On a successful attempt it displays the name, phone number, and email address of the first contact.
  It is the only operation requiring just the `READ_CONTACTS` permission.
- Add contact: `addContact()` inserts a new contact into the content provider, using its `insert()` method.
  It is the only operation requiring just the `WRITE_CONTACTS` permission.
- Delete contact: `deleteContact()` deletes the first contact by querying the contacts provider and calling `delete()` on the corresponding entry.
- Update contact: `updateContactName()` modifies the name of the first contact by querying the contacts provider and calling `update()` on the corresponding entry,
  passing the new name.
- Update batch contact information: `updateContact()` modifies the name, phone number, and email address of the first contact
  by querying the contacts provider and calling `applyBatch()` on the corresponding entry.
  This applies multiple operations at the same time,
  which needs to be checked individually by the model to enforce read or write permissions accordingly.

All operations include exception handling to catch and log any `SecurityException` errors.
This ensures permission errors cause an explicit feedback,
facilitating the identification of inconsistencies.

=== InternetActivity
The `InternetActivity` tests the app's behavior when attempting to perform a network operation,
specifically fetching data from a web page.
The expected behavior in a standard Android environment is that the network request will fail and raise an exception if the app lacks the necessary Internet permission.

However, when testing this activity in the virtual environment,
the request always succeeds, even though the Internet permission has not been granted.
This highlights a significant issue:
redirection of core methods is not enough to ensure that the permission model functions as expected across all use cases.
In this instance, the test reveals that additional considerations are needed to enforce permission restrictions at the level of system operations,
such as networking, which are outside the scope of simple permission checks and requests.

This behavior demonstrates that permission redirection alone is not able to fully address the needs of a virtual permission management model,
especially when the system interacts with core functionalities,
such as networking, that bypass the traditional permission model.

== Real-World Example
To complement the controlled testing with the custom _TestApp_,
the real-world application _Telegram_ was selected for evaluating the virtual permission model's performance in practical scenarios,
mainly for two reasons:
+ Complexity: it is a feature-rich application that extensively uses permissions,
  including access to the camera, microphone, location, and many other.
  This makes it a robust test case for evaluating the virtual permission model's ability to handle real-world apps behavior.
+ Compatibility: among the complex applications tested in VirtualXposed,
  Telegram emerged as one of the few capable of running successfully.
  Many other apps had limited compatibility, experienced crashes, or were unable to launch at all.

The evaluation of Telegram in the virtual environment produced the following positive results:
- Permission checks and requests: direct permission checks and all permission requests requests behaved as expected.
  The system returned accurate messages for permission states,
  as if the app were running in a standard Android environment,
  with error messages correctly displayed when permissions were denied in the virtual model.
- Content provider permissions: the model successfully enforced permissions for content providers.
  For example, operations involving contacts (e.g., reading or writing) were verified to work correctly with appropriate permission checks.
- Camera permission: the native camera patch,
  described in @redirection, was verified as working.
  Attempts by Telegram to access the camera without proper permissions resulted in a black screen,
  demonstrating that the patch effectively blocked access by intercepting native calls and enforcing permission checks.

Despite these successes, a critical flaw was identified:
if Telegram or any other app ignored a `PERMISSION_DENIED` response and attempted to acquire a restricted resource anyway,
the resource was granted without raising an exception.
This issue reveals a limitation in the model's enforcement mechanism:
while the redirection component effectively manages straightforward, direct requests for permissions,
it struggles with cases where permission checks are handled within other operations or bypassed internally by the app.

Manual solutions,
like the camera and content provider patches,
address some of these gaps but do not provide complete coverage.
A more comprehensive, universal system is needed to enforce permissions reliably,
even for indirect or bypassed requests---something this model does not currently provide.
