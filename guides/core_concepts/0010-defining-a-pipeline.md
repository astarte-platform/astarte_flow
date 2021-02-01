# Defining a Pipeline

Astarte Flow has its own DSL for pipeline definition.

# Pipe Operator

The core construct behind Astarte Flow pipelines is the pipe operator `|` which connects two
blocks.

In the following example messages flowing out from block1 (the source) will be processed from
block2 and they will be processes from block3 (the sink):

```
    block1 | block2 | block3
```

New lines are allowed (and suggested) for readabilty reasons.

# With Operator

Most of the times blocks are not usable alone without any kind of configuration.

Astarte Flow DSL defines a `.` operator that can be read as "with". Several `.` can be chained
together.

Syntax for `.` operator is `block.property1(value1).property2(value2)`.

The following example can be read as: "Pipe messages from `astarte_devices_source` block with
`realm` `"test"` to `filter` block with script `"return message.value > 0"`.

```
astarte_devices_source
  .realm("test")
| filter
  .script("return message.value > 0")
```

# Literals

In Astarte Flow DSL literals are meant to be used with `.` operator.

## Integers

Base 10 integers are allowed, such as `-1`, `0` and `89`.

## Booleans

`true` and `false` boolean values are allowed.

## Strings

Strings are marked with `""`, such as `"a string"`.
In some situations it might be convenient using multi-line strings such as:

```
"""
A
"multi-line"
string
"""
```

Multi-line strings are convenient for Lua scripting.

## Objects

JSON like objects are allowed, however there is a major difference: `""` around keys are not
required (and should not be used).

```
{
  a: 1,
  b: 2,
  c: 3
}
```

## JSONPath

[JSONPath](https://goessner.net/articles/JsonPath/) expressions such as `${ $.config.something }` play
a special role in Astarte Flow DSL, since they allow queries to any configuration object.

Following example uses a JSON Path expressions instead of harcoding the realm name.

```
astarte_devices_source
    .realm(${$.config.realm})
```

# Pipeline Example

```
astarte_devices_source
    .realm(${$.config.realm})
| filter
    .script("""
            return string.find(message.key, "org.astarte%-platform.genericsensors.Values") ~= nil;
            """)
| lua_map
    .script("""
            tokens = string_utils.split(message.key, "/");
            sensor_id = tokens[4];
            new_device_id = uuid.get_v5_base64("b25aa4c6-a55b-4231-a080-a5af629d05a3", sensor_id);
            new_message = {};
            new_message.key = config.realm .. "/" .. new_device_id .. "/org.astarte-platform.ComputedValues/value";
            new_message.data = (message.data - 32) / 1.8;
            return new_message;
            """)
    .config(${config})
| virtual_device_pool
    .pairing_url("https://example.com/pairing/v1")
    .realms([{realm: ${$.config.realm}, jwt: ${$.config.pairing_jwt}}])
    .interfaces(${$.config.interfaces})
```
