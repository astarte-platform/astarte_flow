# sort

* type: producer_consumer
* accepted input: any kind of message
* output: any kind of message (order is changed)

This block is a stateful realtime block, which reorders an out of order sequence of messages, and
optionally removes any duplicate message.

# Properties

* `window_size_ms`: Window size in milliseconds. (required, integer)
* `deduplicate`: Duplicated messages are discarded when true. (optional, boolean, default: false)

## `window_size_ms`

The amount of time a message is kept for reorder and deduplicate operations.
This block always introduces a lag of `window_size_ms` milliseconds, so the window size should be
carefully choosen.

## `deduplicate`

When this option is `true` messages are deduplicated. Two messages are duplicate when they have
same timestamp and value (any other message attribute is ignored) and they are both inside the
same sliding window.

# Output message

No transformation is performed on messages, however some messages taken from input are discarded or
reordered.

# Examples

The following example uses sort to deduplicate messages that might be duplicated due to source or
transport peculiarities:

```
[...]
| sort
  .window_size_ms(2000)
  .deduplicate(true)
[...]
```
