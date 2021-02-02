# http_sink

* type: consumer
* input: binary messages

This is a consumer block that takes data from an incoming message and makes a POST request
to the configured URL.

This block supports only incoming messages with type `binary`, so serialization
of different message types must be handled in a preceding block.

For the time being, the delivery is best-effort (i.e. if a message is not delivered, it is discarded).

# Properties

* `url`: The URL of the HTTP request. (required, string)
* `headers`: Http request headers. (optional, object with string values)
* `ignore_ssl_errors`: If `true`, ignore SSL errors that happen while performing the request.
  (optional, boolean)

## `url`

The HTTP request URL such as `"http://www.example.com/test"`.

## `headers`

An optional object with additional headers such as `{authorization: "Bearer <token>"}`.

# Accepted input message

The HTTP request built by the `http_sink` can be customized by the input message with the following properties:

* `data`: the body of the request.
* `type`: is always `binary`.
* `subtype`: if present, it will be the value of the `content-type` HTTP header.

# Examples

The following example uses `http_sink` block to send HTTP POST requests to `http://www.example.com/test`
whenever a valid message is received.

```
[...]
| http_sink
  .url("http://www.example.com/test")
```
