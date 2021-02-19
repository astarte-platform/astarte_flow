# mqtt_source

* type: producer
* output: a message each time an [MQTT](https://mqtt.org/) message is received

An Astarte Flow source that produces data from an [MQTT](https://mqtt.org/) connection.

This block has been implemented using the [Elixir](https://elixir-lang.org/)
[tortoise MQTT client application](https://hexdocs.pm/tortoise/introduction.html).

# Properties

* `broker_url`: The URL of the broker the source will connect to. (required, string)
* `subscriptions`: A non-empty list of topic filters to subscribe to. (required, string array)
* `client_id`: The client id used to connect. Defaults to a random string. (optional, string)
* `ignore_ssl_errors`: If true, accept invalid certificates (e.g. self-signed) when using SSL.
   (optional, boolean, default: false)
* `username`: Username used to authenticate to the broker. (optional, string)
* `password`: Password used to authenticate to the broker. (optional, string)
* `ca_cert_pem`: PEM encoded CA certificate. (optional, string)
* `client_cert_pem`: PEM encoded client certificate, used for mutual SSL authentication.
  (optional, string)
* `private_key_pem`: PEM encoded private key, used for mutual SSL authentication. (optional,
  string)
* `subtype`: A MIME type that will be put as `subtype` in the generated Messages. Defaults to `application/octet-stream`.

## `broker_url`

The URL of the broker the source will connect to. The transport will be deduced by the URL: if
`mqtts://` is used, SSL transport will be used, if `mqtt://` is used, TCP transport will be used.

## `subscriptions`

A non-empty list of topic filters to subscribe to.

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

## `subtype`

A MIME type that will be put as [`subtype`](0002-flow-messages.html#subtype) in the generated Messages. Defaults to `application/octet-stream`.

# Output message

* `key`: contains the MQTT topic on which the message was received
* `data`: contains the payload of the message
* `type`: is always `binary`
* `subtype`: is always `"application/octet-stream"` but can be configured with the `subtype` option
* `metadata`: contains the `Astarte.Flow.Blocks.MqttSource.broker_url` key with the broker url as
   value.
* `timestamp`: contains the timestamp (in microseconds) the response was received.

# Examples

The following example uses the `mqtt_source` block to connect to `www.example.com` MQTT broker and
to subcribe to `#` topic.

```
mqtt_source
  .broker_url("mqtts://www.example.com/")
  .subscriptions(["#"])
[...]
```
