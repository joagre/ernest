%% A module of a build (report §11.1): its namespace, its file, the path
%% from the source root, its declarations and the namespaces it depends on.
-record(build_module, {namespace, file, relative, declarations, dependencies = []}).

%% The entry point a program is run from (report §8.1): the unit, the
%% function of it that holds the entry point, named by its number (report
%% §11.1), and the site its process is spawned at.
-record(entry_point, {erlang_module, function, site}).

%% What the runner loaded before the shell started (report §11.2): the load
%% path, the source root a module's source is found under, the interfaces
%% of the loaded modules each with its source's hash, the namespaces of
%% those found under the file's own root, the program's, and not a
%% library's, the #entry_point{} to spawn beside the prompt or none, and the
%% startup file of the configuration directory `--config-dir` names, or
%% none.
-record(loaded, {load_path = [], source_root = ".", interfaces = [], program = [],
                 entry = none, config_startup = none}).

%% A doc example as `ern test` runs it (report §11.2, ern_examples): its
%% case, `{'Case', Name, Run}`, as a test's is, its run answering `'Passed'`,
%% `{'Failed', Text}` or, for one that only compiles, `'Compiled'`; the
%% units its program initializes, the top first (§8.5); and what writes a
%% trace of its fault with its frames named as its case is (Appendix E.21).
-record(example, {test_case, initialized = [], frames}).
