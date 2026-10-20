%% What the emitter makes a unit of (report §8.7, §11.1, Appendix H): a
%% module's definitions as their canonical forms, with what the module's
%% build adds that is no definition's, and the link of what the forms
%% reference outside the unit. ern_compile gives it for a build and the
%% shell's loads, ern_arrival for the definitions of one exchange, and the
%% shell for a compiled module it loads beside another unit of its name;
%% the emitter (ern_emitter:unit/1) reads nothing else.

-ifndef(ERN_UNIT_HRL).
-define(ERN_UNIT_HRL, true).

-record(unit, {namespace, name, definitions = [], foreign_functions = [], exported = [],
               binding_order = [], dependencies = [], reaches = #{}, link, standard = false,
               code = false, form_namespace, site_namespace, session_offset = false,
               lacked = []}).
%% namespace: the module's (report §4.2), [] for a unit of an exchange,
%% whose definitions are of any module's; name: the unit's, its Erlang
%% module (§11.1, §11.2);
%% definitions: the module's #definition{}s (ern_canonical.hrl), in the
%% order of their forms, by which its functions are named (§11.1), each
%% with its sourced form where the source is given
%% (ern_canonical:source()); a definition without one is made from its
%% form alone, its code without lines and its spawn sites without one; a
%% definition of an exchange's unit is named by its name as text, which
%% its sites and a fault's trace show (§8.7, §11.2);
%% foreign_functions: the module's #foreign_function{}s, in the order it
%% declares them, which have no form (Appendix H);
%% exported: the qualified names of the functions it exports (§11.1), its
%% module's exported ones, and every one an exchange's unit holds;
%% binding_order: the qualified names of its top-level bindings in the
%% order they are initialized (§8.5);
%% dependencies: the units of the modules it depends on, whose bindings are
%% initialized first ('$deps'/0);
%% reaches: each function's reach by its qualified name, and each lambda's
%% and local function's by {QualifiedName, Position} (§8.7, §11.1);
%% link: the #link{} of what its forms reference outside it;
%% standard: whether the module is the standard library's own;
%% code: whether the unit lists what it holds, '$code'/0, which the code
%% for reading, `--emit-erl` and the golden files, has not;
%% form_namespace: the namespace its forms and its '$code'/0 name what a
%% shell's session declares under (Appendix H, §11.2);
%% site_namespace: the namespace its spawn sites name its declarations
%% under, a reload's version's, `Counter$2` (§11.2);
%% session_offset: false, or, for an input of the shell's, the lines before
%% its first in its file, after which its definitions' lines are counted
%% (ern_compile), its sites naming what it declares by its own name (§11.2);
%% lacked: for a unit of an exchange, each function that faults naming
%% what the node lacks, {Function, Arity, Text}, to which the link takes a
%% reference beyond the spawned function's reach, a binding without its
%% value here or a foreign function whose module or function is not here,
%% which no process reaches (§8.7).

-record(foreign_function, {qualified_name, scheme, host_module, host_function, export = false,
                           source = none, printing = none}).
%% A foreign function the module declares (report §4.7, §8.4): scheme, its
%% scheme as a form writes it (Appendix H); host_module and host_function,
%% what its implementation names; export, whether the unit exports its
%% function (§11.1); source, where it is declared,
%% {Line, Column, none}, or none; printing, what prints a type in its
%% check's cause as its module writes it (§11.5), {Namespace, Shadows} as
%% text, where it is not the unit's, a declaration that arrived (§8.7).

-record(link, {functions = #{}, types = #{}, printing}).
%% The link of a unit (report §8.7, §11.1): where each reference its forms
%% make outside it is, as the build or the node knows it.
%% functions: a reference to a function, a binding or a foreign function,
%% `{hash, Hash}`, `{binding, QualifiedName, Hash}`, `{named,
%% QualifiedName}` or `{foreign, QualifiedName, Scheme}`, => #linked{};
%% types: a reference to a type => {QualifiedName, {Arity, Constructors}}
%% or {QualifiedName, foreign}, the type's name as it prints and its
%% constructors as its form writes them (ern_canonical:declared_type/4);
%% printing: the type state a type prints under from the module (§11.5,
%% ern_types:printing/1).

-record(linked, {unit, function, arity, kind = function, identity}).
%% A function, a binding or a foreign function of another unit: its unit
%% and its function there, named by its position (§11.1), a binding's its
%% getter, both undefined for a primitive of the prelude, which has none;
%% arity, how many arguments its function takes,
%% a requirement's members among them (§4.9); kind, function or value, a
%% binding read through its getter (§4.6); identity, its hash, `foreign`
%% for a foreign function, or undefined, by which a spawn on a peer names
%% it (§8.7).

-endif.
