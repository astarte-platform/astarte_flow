# http_source

* type: producer
* output: binary messages

This is a producer block that generates messages by polling HTTP URLs with a GET request.

It works by specifying a `base_url` and a list of `target_paths` to perform requests on.
`HttpSource` will perform GET requests in a round robin fashion on all `target_paths`, waiting
`polling_interval_ms` between two consecutive requests.

# Properties

* `base_url`: Target base URL. (required, string)
* `target_paths`: Relative paths. (required, string array)
* `polling_interval_ms`: Polling interval. (required, integer)
* `headers`: Http request headers. (optional, object with string values)

## `base_url`

Target base URL such as `"http://www.example.com"`.

## `target_paths`

Relative paths to the `base_url` as a string array such as `["/first.json", "/second.json"]`.

## `polling_interval_ms`

The time between two consecutive polling requests, expressed in milliseconds (e.g. `5000` for a 5 seconds interval).

## `headers`

An optional object with additional headers such as `{authorization: "Bearer <token>"}`.

# Output message

If the request succeeds, `http_source` produces a message containing these fields:

* `key`: contains the `target_path` of the request
* `data`: contains the body of the response
* `type`: is always `binary`
* `subtype`: is populated with the contents of the `content-type` HTTP header, defaulting
  to `"application/octet-stream"` if it's not found.
* `metadata`: contains the `"base_url"` key with `base_url` as value. Moreover, it contains all the
  HTTP headers contained in the response with their keys prefixed with `"Astarte.Flow.HttpSource."`.
* `timestamp`: contains the timestamp (in microseconds) the response was received.

If the request can't be performed or an error status (`>= 400`) is returned, no message is
produced.

# Examples

The following example uses `http_source` block for polling `http://www.example.com/first.json` and
`http://www.example.com/second.json` every 5000 milliseconds (with a round robin policy on target
paths `/first.json` and `/second.json`).

```
http_source
  .base_url("http://www.example.com")
  .target_paths(["/first.json", "/second.json"])
  .polling_interval_ms(5000)
```
