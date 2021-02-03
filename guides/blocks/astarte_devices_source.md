# astarte_devices_source

* type: producer
* output: any type of message

Producer block that generates messages by consuming events coming from Astarte devices. This block
must be combined with Astarte [AMQP
Triggers](https://docs.astarte-platform.org/1.0/060-triggers.html#amqp-0-9-1-actions) which allow
Device events to be routed to an AMQP exchange, while the block takes care of consuming those events
and transforming them to Flow [messages](0002-flow-messages.html).

*Note: currently only `incoming_data` triggers on scalar interfaces (i.e. no arrays) are supported*

# Properties

* `realm`: the Realm which is generating the events (required, string)
* `amqp_exchange`: the exchange where the events are being published (required, string)
* `amqp_routing_key`: a custom routing key used to bind the consumer queue to the exchange
  (optional, string)
* `target_devices`: a list of Device IDs. If present, only events coming from these devices will
  generate a message (optional, array of strings)

## `realm`

The Realm that is generating the events. This is also used to enforce the exchange name format (see
below)

## `amqp_exchange`

The exchange where the events are being published. This must match the exchange that was used while
setting up the AMQP trigger, as this block will bind a queue to that exchange (possibly using the
configured `amqp_routing_key`).

This exchange name must follow the same restrictions that are present in Astarte triggers, namely it
must match this regular expression

```
^astarte_events_$realm_[a-zA-Z0-9_\.\:]+$
```

where `$realm` must be substituted with the provided `realm`.

## `amqp_routing_key`

A custom routing key used to bind the queue to the `amqp_exchange`. This must match the
`amqp_routing_key` used in the AMQP trigger, and can be omitted (which is the default in AMQP
triggers).

## `target_devices`

A list of target Device IDs (e.g. `["BWh_mWEATIumVX8asPgxag", "A4QR-S9FTrahKiJihYAetA"]`). If it's
provided, only events coming from the target devices will be considered and generate messages, all
the others will be discarded.

Keep in mind that filtering at this level will still generate the events on the Astarte side and
publish them on RabbitMQ, so if it's possible it's better filtering at the trigger level instead,
since Astarte supports [specifying a Device ID or a
group](https://docs.astarte-platform.org/1.0/060-triggers.html#data-triggers) when creating a
trigger.

# Output message

Each consumed event will produce a Flow Message with the fields constructed in the following way:

* `key`: the key format will be `realm/device_id/interface/path`. For example, an event coming from
the device with Device ID `EA8lpOrkR8OJ-bp9dSVYQA` in the `test` realm on the
`org.astarte-platform.genericsensors.Values` interface with `/mysensor/value` path will produce a
message with key
`test/EA8lpOrkR8OJ-bp9dSVYQA/org.astarte-platform.genericsensors.Values/mysensor/value`
* `data`: the data sent from the Device. If a device sends `42.3` on the above mentioned interface,
  `data` will contain `42.3`.
* `type`: the `type` of the data. Currently this is not explicitly sent inside the event, so the
  type is deduced using an heuristic approach. This must be handled with care especially with
  numeric types, where there can be some instances where a `double` interface generates messages
  with `integer` type.
* `timestamp` contains the timestamp (in microseconds) of the event. If the source interface
  supports `explicit_timestamp`, the timestamp is the one explicitly sent from the device, otherwise
  it's the reception timestamp.

# Examples

The following example uses `astarte_devices_source` block to generate messages coming from the
`test` Realm on the `org.astarte-platform.genericsensors.Values` interface.

```
astarte_devices_source
  .realm("test")
  .amqp_exchange("astarte_events_test_1")
[...]
```

To make the example work, the following trigger must be installed in Astarte in the `test` Realm:

```
{
  "name": "example_trigger",
  "action": {
    "amqp_exchange": "astarte_events_test_1",
    "amqp_message_expiration_ms": 10000,
    "amqp_message_persistent": false
  },
  "simple_triggers": [
    {
      "type": "data_trigger",
      "on": "incoming_data",
      "interface_name": "org.astarte-platform.genericsensors.Values",
      "interface_major": 1,
      "match_path": "/*"
    }
  ]
}
```
