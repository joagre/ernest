%% A module of a build (report §11.1): its namespace, its file, the path
%% from the source root, its declarations and the namespaces it depends on.
%% Report §4.2: once parsed, its declarations are those its names resolved
%% in, beside the namespace each qualifier its source writes resolved to,
%% which its `.erc` records, the shortest form of its own namespace, which
%% the checker holds a name of it written qualified to, and the error of
%% each name written longer than its shortest form (ern_resolve).
-record(build_module, {namespace, file, relative, declarations, dependencies = [],
                       resolved = [], shortest, too_long = []}).

%% A named package as a job's load path holds it (report §11.9): its name,
%% `epx`, which is its namespace's path, its build and its `src`, absolute,
%% the directories it puts on the load path, those of its build and its
%% `ebin` that are there, and the manifest that names it, which a refusal
%% names.
-record(named_package, {name, build, src, roots = [], manifest}).

%% A job's load path (report §11.1, §11.2, §11.9): its directories in
%% order, `roots`, which the host's code path and a node's start take
%% whole, and the named packages, `named`, in the manifest's order, each of
%% whose namespaces is found under its build alone, which provides no other.
%% ern_build makes and reads it (load_path/1, looked_in/3); no other module
%% looks inside it.
-record(load_path, {roots = [], named = []}).

%% The entry point a program is run from (report §8.1): the unit, the
%% function of it that holds the entry point, named by its number (report
%% §11.1), and the site its process is spawned at.
-record(entry_point, {erlang_module, function, site}).

%% What the runner loaded before the shell started (report §11.2): the load
%% path, the source root a module's source is found under, the interfaces
%% of the loaded modules each with its source's hash, the namespaces of
%% those found under the file's own root, the program's, and not a
%% library's, the #entry_point{} to spawn beside the prompt or none, the
%% startup file of the configuration directory `--config-dir` names, or
%% none, and the listed peer `--attach` names, or none.
-record(loaded, {load_path = #load_path{}, source_root = ".", interfaces = [], program = [],
                 entry = none, config_startup = none, attach = none}).

%% A doc example as `ern test` runs it (report §11.2, ern_examples): its
%% case, `{'Case', Name, Run}`, as a test's is, its run answering `'Passed'`,
%% `{'Failed', Text}` or, for one that only compiles, `'Compiled'`; the
%% units its program initializes, the top first (§8.5); and what writes a
%% trace of its fault with its frames named as its case is (Appendix E.21).
-record(example, {test_case, initialized = [], frames}).
