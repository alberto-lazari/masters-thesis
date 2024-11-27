#v(1cm)

= Abstract
Android app-level virtualization is a technique that allows Android apps to run within isolated environments,
provided by a regular application.
Existing implementations lack a dedicated virtual permission management,
causing virtual apps to inherit all of host app's permissions,
which compromises granular control and security when multiple apps are installed into a single host.

This thesis examines the complex and evolving Android permission model---which has undergone extensive updates throughout the OS's development---and presents a custom model
that emulates Android's native permission management behavior and enables permission checking and management for virtual apps.
It does so by extending an established virtualization framework with hooks on system services calls,
in order to enforce permissions on virtual apps using this custom virtual permission model.
Additionally, examples of permission checking implementation for specific services are provided,
evaluating the results using both a test and a real-world application.

Finally, this work addresses the challenges involved in creating an automated, generic solution,
capable of managing permission checks for all methods an app may invoke.
It examines and motivates the underlying issues and explores a potential future direction that could be employed as a step towards a more universal solution.
