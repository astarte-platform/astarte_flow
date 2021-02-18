# update_metadata

* type: producer_consumer
* input: any message
* output: any message

This is a producer and consumer block that modifies the `metadata` of incoming `Message`s.

# Properties

* `metadata` - The metadata configuration object. (required, object with string keys and string or
  `null` values)

## `metadata`

This object defines how this block will change the `metadata` of incoming messages.

All keys present in the object are either inserted or updated in the `Message` metadata, with the
only exception that if a key has a value of `null`, it will be removed from `metadata`. All other
metadata keys are not touched by this block.

# Output message

The only modified field in the message is `metadata`, according to the rules specified above.

# Examples

The following example uses `update_metadata` block to add/update the `"foo"` key in metadata to have
the `"bar"` value, and to remove the `"baz"` metadata key.

```
[...]
| update_metadata
    .metadata({
      foo: "bar",
      baz: null
    })
[...]
```
