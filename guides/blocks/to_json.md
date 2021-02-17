# to_json

* type: producer_consumer
* input: any message
* output: binary messages

This is a producer and consumer block that takes `data` from incoming message
and produces a message having a JSON serialized payload.

# Properties

* `pretty`: serialize the output to pretty format that is easier to read for humans. (optional, boolean)
* `template`: a JSONTemplate template. (optional, object)

## `pretty`

Specifies if the JSON binary should be pretty formatted.

## `template`

Given `{key: "key", data: 42}` as input message, the following template renders to
`{"thekey": "key", "thevalue": 42}`:

```
.template(
  {
    thekey: "{{ message.key }}",
    thevalue: "{{{ message.data }}}"
  }
)
```

# Output message

* `key`: contains the same `key` specified in the input message.
* `data`: the incoming data formatted as a JSON binary
* `type`: is always `binary`
* `subtype`: is always `application/json`
* `timestamp`: the same `timestamp` specified in the input message.

# Examples

The following example uses `to_json` block to format incoming messages to human readable JSON binary
before letting them through.

```
[...]
| to_json
  .pretty(true)
[...]
```
