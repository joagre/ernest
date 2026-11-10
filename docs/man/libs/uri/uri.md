# Ernest module Uri

*Since 0.10.0.*

RFC 3986's URI reference read into its scheme, authority, path, query
and fragment, and percent-encoded text read as its octets.

Use it where a program reads a URL or a request's target: a client finds
the host and the port it dials, and a server the path it serves. A server
over `Http` reads a request's target with `Http.target`, which reads it
in its form by the method.

The library stands on every job's load path, so a program names it with
no option (report Appendix G).

**As written.** A component is answered as the text writes it, still
percent-encoded, in its own case and with its `.` and `..` segments. No
relative reference is resolved against a base, and no port is given the
scheme's default: both are the program's.

**Decoding.** A component is decoded after it is parted at its
delimiters, a path at `/` and each segment decoded with `decode`, so
that `%2F` is an octet inside a segment and no delimiter. The octets
need not be UTF-8; `String.fromUtf8` reads them as text where they are.

## Examples

A URL's host, port and path:

```ernest
match Uri.parse("https://example.com:8443/docs/index.html?lang=en") {
    Some(Uri.Reference(authority = Some(authority), =path)) ->
        #(authority.host, authority.port, path)
  | _ ->
        #("", None, "")
}
// => #("example.com", Some(8443), "/docs/index.html")
```

A path parted at `/` and each segment decoded:

```ernest
{
    let segments = String.split("/a%2Fb/caf%C3%A9", "/");
    List.map(segments, fn(segment) = Optional.andThen(Uri.decode(segment), String.fromUtf8))
}
// => [Some(""), Some("a/b"), Some("café")]
```

## See also

`Http` for a request's target, `Tcp` for the host and the port a client
dials, `String` for the text a segment's octets write.

## Uri.Reference

```ernest
type Reference =
    Reference(scheme : Optional(String),
              authority : Optional(Authority),
              path : String,
              query : Optional(String),
              fragment : Optional(String))
```

*Since 0.10.0.*

A URI reference's components, each as the text writes it: a URI, which
has a scheme, or a relative reference, which has none.

### Examples

```ernest
Optional.map(Uri.parse("mailto:desk@example.com"),
             fn(reference) = #(reference.scheme, reference.path))
// => Some(#(Some("mailto"), "desk@example.com"))
```

- `Reference`
  - `scheme : Optional(String)`: The scheme before the first `:`, `https`; `None` in a relative
reference.
  - `authority : Optional(Authority)`: The authority after `//`; `None` where the text writes no `//`.
  - `path : String`: The path, `""` where the text writes none.
  - `query : Optional(String)`: The query after `?`, without it; `None` where the text writes no `?`.
  - `fragment : Optional(String)`: The fragment after `#`, without it; `None` where the text writes no
`#`.

## Uri.Authority

```ernest
type Authority = Authority(userinfo : Optional(String), host : String, port : Optional(Int))
```

*Since 0.10.0.*

An authority's parts: the user information before `@`, the host, and the
port after `:`.

### Examples

```ernest
Uri.parseAuthority("[::1]:8443")
// => Some(Uri.Authority(userinfo = None, host = "::1", port = Some(8443)))
```

- `Authority`
  - `userinfo : Optional(String)`: The user information before `@`, without it; `None` where the text
writes no `@`.
  - `host : String`: A registered name, an IPv4 address or an IPv6 address, the address
without the brackets the text writes it in, as `Tcp.connect` takes a
host; it may be empty.
  - `port : Optional(Int)`: The number the port's digits write, unchecked against TCP's 65535;
`None` where the text writes no port or an empty one, `example.com:`.

## Uri.parse

```ernest
Uri.parse(text : String) : Optional(Reference)
```

*Since 0.10.0.*

The components of `text`, a URI reference, each as the text writes it;
`None` where `text` is no URI reference.

It answers `None` for a character outside those RFC 3986 writes a
reference in, a space, a `|`, a control character and one outside ASCII
among them; for a second `#`; for a `%` not followed by two hexadecimal
digits; and for a port that is not digits alone. The library does not
read a port of more than five digits, an IPvFuture address, `[v1.x]`, or
an IPv6 address with a zone, `[fe80::1%25eth0]`, and `parse` answers
`None` for each.

An empty authority, `http:///index.html`, is an authority whose host is
empty, and an empty query or fragment, `/index.html?`, is `Some("")`.

### Examples

```ernest
Optional.map(Uri.parse("/search?q=ernest#top"),
             fn(reference) = #(reference.path, reference.query, reference.fragment))
// => Some(#("/search", Some("q=ernest"), Some("top")))
```

```ernest
#(Uri.parse("/a b"), Uri.parse("/100%"), Uri.parse("//example.com:http"))
// => #(None, None, None)
```

## Uri.parseAuthority

```ernest
Uri.parseAuthority(text : String) : Optional(Authority)
```

*Since 0.10.0.*

The authority `text` writes alone, `host`, `host:port`, or either after
`userinfo@`, as a `CONNECT` request's target and a `Host` header write
one; `None` for another text, one with a path, a query or a fragment
among them.

The empty text is an authority whose host is empty, as an empty `Host`
header writes one.

### Examples

```ernest
Uri.parseAuthority("example.com:443")
// => Some(Uri.Authority(userinfo = None, host = "example.com", port = Some(443)))
```

```ernest
#(Uri.parseAuthority("example.com/"), Uri.parseAuthority("example.com:http"))
// => #(None, None)
```

## Uri.decode

```ernest
Uri.decode(text : String) : Optional(Bytes)
```

*Since 0.10.0.*

The octets `text` percent-encodes: each `%` and two hexadecimal digits,
in either case, the octet they write, and every other character its UTF-8
bytes; `None` for a `%` not followed by two hexadecimal digits.

The octets need not be UTF-8. `%2F` is the octet a `/` is, so a
component is parted at its delimiters before it is decoded.

### Examples

```ernest
#(Uri.decode("a%2fb"), Optional.andThen(Uri.decode("caf%C3%A9"), String.fromUtf8))
// => #(Some(<<97, 47, 98>>), Some("café"))
```

```ernest
#(Uri.decode("%FF"), Uri.decode("100%"), Uri.decode("%zz"))
// => #(Some(<<255>>), None, None)
```

---

Generated by ern 0.11.0-dev from src/libs/uri/uri.ern.
