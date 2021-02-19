# mqtt_sink

* type: consumer
* input: binary messages

This is a consumer block that takes data from an incoming message and publishes it using an
[MQTT](https://mqtt.org/) connection.

This block supports only incoming messages with type `binary`, so serialization of different message
types must be handled in a preceding block.

This block has been implemented using the [Elixir](https://elixir-lang.org/) [tortoise MQTT client
application](https://hexdocs.pm/tortoise/introduction.html).

# Properties

* `broker_url`: The URL of the broker the source will connect to. (required, string)
* `client_id`: The client id used to connect. Defaults to a random string. (optional, string)
* `ignore_ssl_errors`: If true, accept invalid certificates (e.g. self-signed) when using SSL.
   (optional, boolean, default: `false`)
* `username`: Username used to authenticate to the broker. (optional, string)
* `password`: Password used to authenticate to the broker. (optional, string)
* `ca_cert_pem`: PEM encoded CA certificate. (optional, string)
* `client_cert_pem`: PEM encoded client certificate, used for mutual SSL authentication.
  (optional, string)
* `private_key_pem`: PEM encoded private key, used for mutual SSL authentication. (optional,
  string)
* `qos`: The QoS used when publishing (optional, integer, default: `0`)

## `broker_url`

The URL of the broker the source will connect to. The transport will be deduced by the URL: if
`mqtts://` is used, SSL transport will be used, if `mqtt://` is used, TCP transport will be used.

## `client_id`

The client id used to connect. Defaults to a random string.

## `ignore_ssl_errors`

If true, accept invalid certificates (e.g.
[self-signed](https://en.wikipedia.org/wiki/Self-signed_certificate)) when using SSL.

## `username`

Username used to authenticate to the broker.

## `password`

Password used to authenticate to the broker.

## `ca_cert_pem`

A PEM encoded CA certificate. If not provided, the default CA trust store provided by `:certifi`
will be used.

## `client_cert_pem`

A PEM encoded client certificate, used for mutual SSL authentication. If this is provided, also
`private_key_pem` must be provided.

## `private_key_pem`

A PEM encoded private key, used for mutual SSL authentication. If this is provided, also
`client_cert_pem` must be provided.

## `qos`

The MQTT QoS used when publishing. Defaults to `0`, possible valid values are `0`, `1` or `2`.

# Accepted input message

This block supports only messages with a `binary` type. Serialization must be explicitly handled in
another block. Messages with a different type are discarded by the block.

The message fields are used as follows:

* `key` becomes the MQTT topic for the published message
* `data` is used as message payload
* `type` must always be `binary`, otherwise the message is discarded

# Examples

This example uses the `mqtt_sink` block to connect to an MQTT broker with host `example.com` on port
`8883` and publish incoming messages with QoS 1

```
[...]
| mqtt_sink
  .broker_url("mqtts://example.com:8883")
  .qos(1)
```
