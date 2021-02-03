# Streams

A stream is a sequence of messages, with each [message](0002-flow-messages.md) having the same key.

Different streams might processed by the same set of [blocks](0003-blocks.md) inside a
[flow](0005-flows.md), message processing might be interleaved but their relative order (inside the
same stream) is kept.

A practical example of the concept of streams is the sequence of messages coming from several
similar sensors, which can share the same processing infrastructure but must be stored as different
time series.

Streams will play an important role in load balancing and automatic consistent sharding, therefore
messages that belong to a stream are always processed in-order by the same set of computing resources.
