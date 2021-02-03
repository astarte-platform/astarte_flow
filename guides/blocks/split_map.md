# split_map

**This block API will likely change in future versions, see also
[GH issue #108](https://github.com/astarte-platform/astarte_flow/issues/108).**

* type: producer_consumer
* accepted input: a map message having `n` keys
* output: `n` messages with different message keys

This block breaks a map message into several messages, one for each map item.

# Properties

* `key_action`: Input map and output message key handling policy. (optional, string, default:
   `"replace"`)
* `delimiter`: Key delimiter string. (optional, string, default: `""`)
* `fallback_action`: Unsplittable messages policy. (optional, string, default: `"pass_through"`)
* `fallback_key`: Message key used when `"replace_key"` `"fallback_action"` is used. (optional, string)

## `key_action`

Output message key building policy, it can be either one of the following:
* `"none"`: output message key is input message key (no changes)
* `"replace"`: output message key is replaced with keys used in input message map.
* `"append"`: input message map key is appended to the input message key
* `"prepend"`: input message map key is prepended to the input message key

Let's assume the input message looks like the following:
```
{
  key: "inputkey"
  data: {
    one: 1,
    truthy: true,
    hello: "world"
  }
}
```

When using `"none"` the following 3 messages will be produced:
* `{ key: "inputkey", data: 1, type: integer }`
* `{ key: "inputkey", data: true, type: boolean }`
* `{ key: "inputkey", data: "world", type: string }`

When using `"replace"` the following 3 messages will be produced:
* `{ key: "one", data: 1, type: integer }`
* `{ key: "truthy", data: true, type: boolean }`
* `{ key: "hello", data: "world", type: string }`

When using `"append"` the following 3 messages will be produced:
* `{ key: "inputkeyone", data: 1, type: integer }`
* `{ key: "inputkeytruthy", data: true, type: boolean }`
* `{ key: "inputkeyhello", data: "world", type: string }`

When using `"prepend"` the following 3 messages will be produced:
* `{ key: "oneinputkey", data: 1, type: integer }`
* `{ key: "truthyinputkey", data: true, type: boolean }`
* `{ key: "helloinputkey", data: "world", type: string }`

## `delimiter`

String delimiter that is used when `key_action` is set to `"append"` or `"prepend"`, which is used
to separate the input message key and the appended/prepended map key.

## `fallback_action`

Fallback action is used when input message has no map type.

The following fallback actions are available:
* `"discard"`: input message is always discarded when it cannot be splitted
* `"replace_key"`: input message is kept but key is replaced with specified replace key
* `"pass_through": input message is passed through without any change

## `fallback_key`

`fallback_key` is used when `"replace_key"` `"fallback_action"` is used.

# Output message

For each message having a map with `n` keys, `n` messages are produced.

# Examples

The following example uses `map_split` to split messages having type map into messages that make
use of base or array types, the output message key is built by appending the key of each map item
to the input message key.

```
[...]
| map_split
  .key_action("append")
  .delimiter("/")
[...]
```
