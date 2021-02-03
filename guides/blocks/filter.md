# filter

* type: producer_consumer
* input: any kind of message
* output: same message type as input

This is a producer and consumer block that filters messages that get rejected by the filter script.

This block supports [Lua 5.2](https://www.lua.org/manual/5.2/) scripts (
[luerl scripting engine](https://github.com/rvirding/luerl) is used under the hood). The incoming
message will be provided to the script as `message`.

# Properties

* `script`: The Lua script used to filter incoming messages. (required, string)

## `script`

The Lua script that will determine if the message has to be discarded or allowed through.
The script must return boolean value.
When the returned value is `true`, the input massage passes through the filter to the next
block in the pipeline.
On the other hand, when the returning value is `false`, the message is dropped.
If the return value is invalid or if an error occurs, the message is also dropped.

An example script would be
```lua
"""
return message.data > 0;
"""
```
If the message data is greater than zero, the returned value will be `true` allowing the message
to preceed onward.

See also [luerl documentation](https://github.com/rvirding/luerl/wiki).

# Examples

The following example uses `filter` to drop any message that does not contain `test`
as message key

```
[...]
| filter
    .script("""
            return string.find(message.key, "test") ~= nil;
            """)
[...]
```
