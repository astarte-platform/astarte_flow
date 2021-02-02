# json_path_map

**This block API will likely change in future versions.**

* type: producer_consumer
* accepted input: binary messages (in JSON format, with "application/json" subtype)
* output: message with the structure described by the template

Transforms the incoming JSON message using the configured JSON template which makes use of
JSONPath to extract data from the incoming message.

# Properties

* `template`: JSONPath template. (required, string)

## `template`

output message template. It must be a valid JSON that makes use of JSONPath.

# Output message

If the template rendering succeeds, `json_path_map` produces a message as described by `template`.

# Examples

Extracts data from JSON using JSONPath expressions, and it populates a map having keys `a`, `b`,
`c`:

```
[...]
| json_path_template
  .template("""
    {
      "data": {
        "a": "{{$.data.data[0].values[?(@.name == \"a\")].value}}",
        "b": "{{$.data.data[0].values[?(@.name == \"b\")].value}}",
        "c": "{{$.data.data[0].values[?(@.name == \"c\")].value}}"
      },
      "type": {
        "a": "real",
        "b": "real",
        "c": "real"
      }
    }
[...]
```
