= Conclusion <conclusion>
The virtual permission model presented in this thesis serves as a proof of concept for a generic and scalable permission management solution.
By drawing inspiration from Android's native permission system,
this model tries to address the limitations of traditional app-level virtualization frameworks' permission controls.
The virtual permission model's design and implementation have been evaluated through both controlled and real-world testing,
proving its potential to enforce permissions in a virtual environment.

One of the main aspects of the model is its integration with Android's mechanisms for checking and requesting permissions.
The virtual permission model replicates and extends these core mechanisms,
ensuring that permissions are managed correctly within the virtual environment.
However, the evaluation phase revealed critical challenges when the model interacts with Android's system components,
such as content providers and networking operations.
These limitations highlight the inherent complexity of Android's framework and the difficulties of accurately replicating it in a virtual space.

While the current approach has proven effective for many basic use cases,
it is clear that app-level virtualization reaches its limits when handling more complex, system-level interactions.
This happens because system services---which typically handle permission checks internally for their operations---are difficult to intercept through app-level virtualization,
due to their separation in the Android architecture.
While the manual hook approach proved to be effective for specific scenarios,
it lacks scalability.
Additionally, methods such as automated permission analysis remain unfeasible without an up-to-date and comprehensive permission mapping.

An alternative solution that could be explored is to explore the approach proposed in @services_reimplementation,
by trying to reinstantiate system services within the virtual framework.
The limitations and complexity of this approach still remain to be verified,
and it is essential to determine whether they truly are as significant as it appears.
If these challenges can be overcome with further implementation,
this approach would enable direct interception of system-level operations,
providing a potential way to overcome many of the limitations of the current virtual model.

Looking ahead, OS-level virtualization presents a promising alternative for overcoming many of the constraints of app-level virtualization.
It could provide more control over permission checks and allow for a universal approach to enforcing permissions in system-wide operations.
Android's inclusion of the kPVM hypervisor presents a particularly interesting starting point in this context.
While the Android Virtualization Framework is not yet ready for practical use---due to the Microdroid OS not being fit for this specific context---it could offer a valuable foundation for secure OS-level virtualization in the future.
Exploring this area could pave the way for more comprehensive and scalable solutions for permission management,
ultimately making the virtual permission model more effective and flexible to the evolving landscape of Android applications.
