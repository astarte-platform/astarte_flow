# Blocks

Astarte Flow base computation unit is a block and their purpose is consuming, producing and
processing messages.

Blocks are used as pipelines building blocks by chaining them together, in order to define a
logical computation topology.

There are 3 kinds of blocks that play different roles in a pipeline:
* Producer (Source): they produce messages from events coming from the outside world
* Consumer (Sink): they output data from Astarte Flow to the outside world
* Producer & Consumer (Transform / Process): they transform messages

# Blocks Configuration

Blocks behavior depends on their configuration, that can be changed by setting some properties (
e.g. `to_json` block has a `pretty` boolean property which allows deciding wether JSON output is
human readable (pretty) or not).

## Validation

Blocks configuration is validated against its [JSON Schema](https://json-schema.org/), therefore a
new block implementation requires writing a JSON Schema for it.

# Implementing a Block

Blocks can be implemented using different technologies:
* As a Docker container using any language suitable for Docker (e.g. Python), which is the best
  option for implementing custom complex algorithms
* As a chain of existing blocks (a pipeline), that is the go-to solution when a block can be
  implemented by just chaining blocks together
* As a Lua 5.2 script, that is the idea solution for small adjustments and simple data
  transformations, such as applying a conversion formula
* As an Elixir module, that is how built-in blocks are implemented
