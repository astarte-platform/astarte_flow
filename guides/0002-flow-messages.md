# Astarte Flow Messages

Astarte Flow main focus is messages processing.

## Message Structure

* `:key`: a unicode string that identifies the stream the message belongs to.
* `:metadata`: additional message metadata as a map with string key and string value.
* `:type`: message [data type](#data-and-types) (e.g. integer, real, boolean, etc...).
* `:subtype`: a string that represents the subtype, that is a mimetype for binaries.
* `:timestamp`: timestamp in microseconds from [Epoch](https://en.wikipedia.org/wiki/Unix_time) UTC.
* `:data`: the message payload.

## Data and Types

Messages are a convenient envelope around values, which are strongly typed.

There are 6 different base types, which are the smallest building block:

* `integer`: unlimited integer numbers such as `-1`, `0` and `282174488599599500573849980909`
* `real`: double precision floating point numbers. NaNs and other special values are not allowed
* `boolean`: either `true` or `false`.
* `datetime`: timestamps with microsecond precision.
* `binary`: any sequence of bytes, such as `"Hello"`, `<<0x00, 0x01, 0xFF>>` and `<<>>`
* `string`: any unicode string, such as `"Hello"` and `"文字列"`

Each of the previous base types has an array counterpart, such as integer array (e.g. `[1, 2, 3]`)
or string array (e.g. `["hello", "world]`).
However array of arrays are not allowed, therefore `[[1, 2], [3, 4]]` is invalid. Heterogeneous
arrays are not supported as well, hence `[1, "hello", true]` is invalid.

Map type, with any number of keys, is supported. Keys can be any arbitrary string, while
any base type or array type is supported as values (hence nested maps are not allowed, e.g.
`{"a": {"b": true}}` is invalid). Astarte Flow typing system disallow any kind of recursive type.

The following is a valid map:
```
{
  "one": 1,
  "sky is blue": true,
  "green": "緑",
  "coords": [1.1, 1.2, 1.3]}
}
```

## Key

Each message has a key, the key identifies the stream which the message belongs to.
Keys can be any non empty string, Astarte Flow will take care of consistent sharding on keys.

## Timestamp

Each message has a timestamp with microsecond precision, timestamps are generally related to the event
that generated the message. For instance when the message represents a sensor measurement,
timestamp will be likely the measurement timestamp (since
[UTC Epoch](https://en.wikipedia.org/wiki/Unix_time)).

## Subtype

Messages have a special metadata which is subtype, that is useful when type is binary.
Subtype should be used to keep track of the binary mimetype (such as `"application/json"`).

## Metadata

Metadata is an optional map, which stores user defined metadata. Both key and values must be strings.

## JSON Encoding

The preferred wire-level encoding of messages is JSON, which is used for exchanging messages with
containers.

Message JSON encoding relies on `schema` key which tells the decoder how the message is serialized,
future versions might use different schemas.

The following is an example of a JSON encoded message, which carries binary data.

```json
{
  "schema": "astarte_flow/message/v0.1",
  "data": "AAECAA==",
  "key": "binaries_stream",
  "metadata": {},
  "timestamp": 1551884045074,
  "timestamp_us": 181,
  "type": "binary",
  "subtype": "application/octet-stream"
}
```

The following message encodes a map, having a binary and a real value:

```json
{
  "schema": "astarte_flow/message/v0.1",
  "data": {
    "a": -1,
    "b": "Q2lhbwo="
  },
  "key": "maps_stream",
  "metadata": {
    "hello": "world"
  },
  "timestamp": 1551884045074,
  "timestamp_us": 181,
  "type": {
    "a": "real",
    "b": "binary"
  },
  "subtype": {
    "b": "text/plain"
  }
}
```
