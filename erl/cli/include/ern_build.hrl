%% A module of a build (report §11.1): its namespace, its file, the path
%% from the source root, its declarations and the namespaces it depends on.
-record(build_module, {namespace, file, relative, declarations, dependencies = []}).
