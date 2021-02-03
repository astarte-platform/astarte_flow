# lua_map

* type: producer_consumer
* accepted input: any kind of message
* output: transformed input message

This is a producer and consumer block that takes an incoming message and it transforms it using the
given Lua script.

This block supports [Lua 5.2](https://www.lua.org/manual/5.2/) scripts (
[luerl scripting engine](https://github.com/rvirding/luerl) is used under the hood). The incoming
message will be provided to the script as `message`.

This block name is not related to the map abstract data type and it should be not confused with it,
instead it is related to the function (our script) application to a sequence of items (the
messages).

# Properties

* `script`: Lua script. (required, string)
* `config`: Lua script configuration object. (optional, object)

## `script`

A Lua [Lua 5.2](https://www.lua.org/manual/5.2/) script. The most simple script is
`"return message;"` which returns an unmodified message.

See also [luerl documentation](https://github.com/rvirding/luerl/wiki).

## `config`

Any object. Config parameter is meant as a method to provide parameters to the Lua script, without
hard-coding them. It can be accessed using `config`.

# Output message

An input message transformation which depends on the script implementation.
Missing message attributes are taken from the input message, therefore some fields are kept
unchanged.

# Examples

The following example uses `lua_map` block for Fahrenheit to Celsius degrees conversion. A key
prefix is provided through `config` object and prepended to the string `"/celsius"`.
All other existing message attributes are taken as-is from the input message.

```
[...]
| lua_map
  .script("""
    new_message = {};
    new_message.key = config.prefix .. "/celsius";
    new_message.data = (message.data - 32) / 1.8;
    return new_message;
  """)
  .config(${config})
[...]
```
