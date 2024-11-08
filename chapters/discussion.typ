= Discussion <discussion>
== Finding a General Solution
=== Binder Calls
- System implementation once performing a binder call
- Manual hook implementations are required for many methods
=== Lack of Comprehensive Permission Mapping
Not possible to implement a naive automated solution by hooking every method and throwing `SecurityException`
=== Complex Hooks Implementation
Every hook for a specific method has to reimplement its Android counterpart logic, leading to difficulties in automating the process
