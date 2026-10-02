%% A module of a build (report §11.1): its namespace, its file, the path
%% from the source root, its declarations and the namespaces it depends on.
-record(build_module, {namespace, file, relative, declarations, dependencies = []}).

%% The entry point a program is run from (report §8.1): the Erlang module,
%% the Ernest function of it, and the site its process is spawned at.
-record(entry_point, {erlang_module, function, site}).
