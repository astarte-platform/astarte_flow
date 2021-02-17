# modbus_tcp_source

* type: producer
* output: integer, float or boolean messages

This is a producer block that generates messages by polling a Modbus device over TCP. 

It works by specifying a `host` (optionally with a `port`), a `slave_id` and a list of `targets` to
be polled. Data read from registers is converted to well defined formats before generating a Flow
Message.

*Note*: currently `polling_interval_ms` _must_ be the same for all targets. This limitation will be
removed in a future release.

# Properties

* `host`: The IP adress of the Modbus device. (required, string)
* `slave_id`: The Modbus slave id of the target. (required, integer)
* `targets`: The array of targets to be polled. (required, array of objects)
* `port`: The TCP port of the target Modbus device, defaults to 502. (optional, integer)

## `host`

A string representing an IP address to reach the Modbus device (e.g. `"192.168.1.2"`).

## `port`

The TCP port for the Modbus connection, defaults to `502` (the standard Modbus TCP port).

## `slave_id`

The slave id of the target Modbus device. This should be an integer between `1` and `247`.

## `targets`

An array of objects representing the targets. Each of these objects should have these keys:

* `name`: The name of the target. This will be used as `key` in the generated messages. (required,
  string)
* `base_address`: The Modbus address of the target. One or more registers starting from this address
  will be read when polling this target, depending on the `format`. (required, integer)
* `format`: The format of the data. Must be one of these strings: `"int16"`, `"uint16"`,
  `"float32be"`, `"float32le"`, `"boolean"`. The format will also determine how many registers are
  read for this target. (required, string)
* `modbus_type`: The modbus type of the target register. Must be one of these strings: `"coil"`,
  `"discrete_input"`, `"input_register"`, `"holding_register"`. (required, string)
* `polling_interval_ms`: The interval between to consecutive polling requests, expressed in
  milliseconds. *Caveat*: right now all targets must have the same polling interval, this limitation
  will be removed in a future release. (required, integer)
* `static_metadata`: A `string -> string` object of metadata that will be added as metadata to all
  messages produced for this target.

# Output message

If the polling succeeds, for each target `modbus_tcp_source` produces a message containing these
fields:

* `key`: contains the `name` of the target
* `data`: contains the data converted with the chosen format
* `type`: depends on the chosen format
* `metadata`: contains the `static_metadata` of the target, if present
* `timestamp` contains the timestamp (in microseconds) the response was received.

# Examples

The following example uses `modbus_tcp_source` to poll every 30 seconds a Modbus device at IP
`192.168.1.42` at port `2000`, with a slave id value of `3`. The only target is a voltage value
stored as float with a little endian format in the holding registers `42` and `43`.

```
modbus_tcp_source
    .host("192.168.1.42")
    .port(2000)
    .slave_id(3)
    .targets([
      {
        base_address: 42,
        name: "sensor-V_RMS",
        format: "float32le",
        static_metadata: {
          units: "V"
        }
        polling_interval_ms: 30000,
        modbus_type: "holding_register"
      }
    ])
| [...]
```
