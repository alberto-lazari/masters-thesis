= Evaluation <evaluation>
== Test App
=== Permission Check
Activity to test that `checkPermission` is correctly hooked.
Used to test correctness of permission model.

=== Permission Requests
Same activity that allows for permission requests.
Used to test permission dialog integration and host permissions alerts.

=== Contacts Operations (content providers)
Activity that provides operations on contacts content provider.
Used for testing permissions control applied on content providers (specifically contacts).

== Real World Example
- Telegram used as a real application.
- Various permissions tested, specifically used to test the blocking of camera permission.
