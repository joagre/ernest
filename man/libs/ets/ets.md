# Ernest module Ets

*Since 0.1.0.*

Tables that live in the runtime, outside any one process.

A table maps keys to values, as a `Map` does, but it is not a value: it
is changed in place, and every process that holds it sees the change.
Use a table where several processes read and write the same state. For
state that one process holds, a `Map` in that process is the usual
choice, and the simpler one.

A program that uses the library puts it on its load path, both when it
is compiled and when it is run: `--load-path` with the directory of the
compiled library, `lib/ernest/build/libs/ets` under the prefix Ernest is
installed in. Under `/usr/local`, where Ernest is installed by default:

```sh
ern build --load-path /usr/local/lib/ernest/build/libs/ets main.ern
ern run --load-path /usr/local/lib/ernest/build/libs/ets main.erc
```

**A table's life.** A table belongs to the process that made it. It ends
when that process ends, or when any process that holds it calls
`close`. Every operation on a table that has ended faults: `size` with the
cause `the table has ended`, and the others with the host's, `foreign
function ets:lookup/2 raised error:badarg` and the like, which means the
same.

**Sharing.** A table is not copied when it is sent in a message or
captured by a spawned function: the other process reads and writes the
same table. Nothing orders the writes of two processes but the order in
which they run. A `get` followed by a `put` is two operations: another
process may write between them, and one of the two updates is then lost.
State changed by reading and writing it belongs in one process, as a `Map`
in its loop. A table stays on the node that made it.

**Keys.** The key type needs equality, which the `=` in `Table(k=, v)`
says, and two keys are one key where `==` holds for them.

## Examples

A value put at a key and read back:

```ernest
{
    let table = Ets.new();
    Ets.put(table, "a", 1);
    Ets.get(table, "a")
}
// => Some(1)
```

An entry removed, and the table as it is afterwards:

```ernest
{
    let table = Ets.new();
    Ets.put(table, 1, "one");
    Ets.remove(table, 1);
    #(Ets.contains(table, 1), Ets.size(table))
}
// => #(false, 0)
```

## See also

`Map` for a map that is a value, held by one process.

## Ets.Table

```ernest
foreign type Table(k=, v)
```

A table from keys of type `k` to values of type `v`. The `=` in `k=`
says that the key type needs equality.

### Examples

```ernest
{
    let table : Ets.Table(String, Int) = Ets.new();
    Ets.size(table)
}
// => 0
```

## Ets.new

```ernest
Ets.new() : Table(k=, v) with m+
```

A fresh empty table, owned by the calling process. It lives until that
process ends or the table is closed. The types of its keys and values
are those of its first use, or of an annotation.

## Ets.put

```ernest
Ets.put(table : Table(k=!, v!), key : k=!, value : v!) : Unit with m+
```

Puts the value at that key, replacing any entry the key had. The table
is changed in place, for every process that holds it.

### Errors

Faults on a table that has ended. The cause names the host's function:
`foreign function ets:insert/2 raised error:badarg`.

## Ets.get

```ernest
Ets.get(table : Table(k=!, v!), key : k=!) : Optional(v!) with m+
```

The value at that key, or `None` where the table has no entry for it.

### Errors

Faults on a table that has ended. The cause names the host's function:
`foreign function ets:lookup/2 raised error:badarg`.

## Ets.contains

```ernest
Ets.contains(table : Table(k=!, v!), key : k=!) : Bool with m+
```

`true` when the table has an entry with that key.

### Errors

Faults on a table that has ended. The cause names the host's function:
`foreign function ets:lookup/2 raised error:badarg`.

## Ets.remove

```ernest
Ets.remove(table : Table(k=!, v!), key : k=!) : Unit with m+
```

Removes the entry at that key. Removing a key the table does not hold
does nothing.

### Errors

Faults on a table that has ended. The cause names the host's function:
`foreign function ets:delete/2 raised error:badarg`.

## Ets.size

```ernest
Ets.size(table : Table(k=!, v!)) : Int with m+
```

The number of entries.

### Errors

Faults on a table that has ended, with the cause `the table has ended`.

## Ets.clear

```ernest
Ets.clear(table : Table(k=!, v!)) : Unit with m+
```

Removes every entry. The table itself stays, empty, and is used as
before.

### Errors

Faults on a table that has ended. The cause names the host's function:
`foreign function ets:delete_all_objects/1 raised error:badarg`.

### Examples

```ernest
{
    let table = Ets.new();
    Ets.put(table, "k", "v");
    Ets.clear(table);
    Ets.toList(table)
}
// => []
```

## Ets.close

```ernest
Ets.close(table : Table(k=!, v!)) : Unit with m+
```

Ends the table and frees what it held. Every operation on it afterwards
faults, in every process that holds it, a second `close` among them.

### Errors

Faults on a table that has ended. The cause names the host's function:
`foreign function ets:delete/1 raised error:badarg`.

### Examples

A table closed once its work is done; an operation on it after this faults:

```ernest
{
    let table = Ets.new();
    Ets.put(table, "k", "v");
    Ets.close(table)
}
```

## Ets.toList

```ernest
Ets.toList(table : Table(k=!, v!)) : List(#(k=!, v!)) with m+
```

The entries as pairs, in unspecified order. The list is a copy: a later
write to the table does not change it.

### Errors

Faults on a table that has ended. The cause names the host's function:
`foreign function ets:tab2list/1 raised error:badarg`.

---

Generated by ern 0.3.1 from ets.ern.
