%% A definition as the `.erc` records it beside its canonical form (report
%% §8.7, §11.1, Appendix H), which ern_canonical makes and reads.

-ifndef(ERN_CANONICAL_HRL).
-define(ERN_CANONICAL_HRL, true).

-record(definition, {qualified_name, kind, hash, form, group = none, sourced = none,
                     name = none, printing = none}).
%% kind: function, binding or type; hash: the definition's hash, the 32
%% bytes of its SHA-256; form: its canonical form, a reference to a member
%% of its own group by position; group: none, or {GroupHash, Position}
%% where it is a member of a mutually recursive group, whose forms in
%% source order its hash is taken of; sourced: the form with the source
%% woven in, which the hash leaves out (ern_canonical:stripped/1), each
%% node's line and column and, in the build, the name of each local the
%% source binds, `{Line, Column, Name}`, the names left out, `none`, in the
%% `.erc` and a code frame (report §11.1, §8.7), or none where nothing
%% gives the source; name: the name the definition's code shows, its spawn
%% sites and a fault's trace, as a list of its segments as text, where it
%% is not its qualified name: a declaration of a shell's session, `f`, an
%% input's expression, `input 3`, a reload's version's, `Counter$2.worker`
%% (§6.9, §11.2), or none; printing: what prints a type in a cause as its
%% module writes it (§11.5), {Namespace, Shadows}, the namespace its forms
%% write the module's types under and the prelude names its types shadow,
%% each a list of names as text, in the `.erc` and a code frame (§8.7), or
%% none where the unit's own printing holds, as in the build

-record(recorded, {definitions = [], foreign = [], binding_order = []}).
%% What a unit's compiled form records beside its code (report §11.1, §8.7,
%% §11.2), which the code table keeps for a unit no file holds and an
%% exchange and the shell's load of a compiled form read: its definitions,
%% each with its source's lines, its name and its printing; its foreign
%% declarations, in the order declared, each a #foreign_function{}
%% (ern_unit.hrl), as an exchange's frames carry one too (ern_exchange):
%% its scheme as a form writes it (Appendix H), which no form holds, its
%% source, where it is written, {Line, Column, none}, its printing, the
%% module's, and the host's module and function atoms, but in a unit an
%% exchange made, which records every declaration its reach and its code
%% frames carried, text for one the node holds no atom of, the call linked
%% to a fault (§8.7); and its top-level bindings' qualified names in the
%% order §8.5 evaluates them

-endif.
