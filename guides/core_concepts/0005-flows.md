# Flows

A Pipeline is just a blueprint, therefore it must be instantiated and all parameters must be known.

*If we imagine our messages as chocolate chip cookies, a Flow is the cookies production line, while
a Pipeline is the description about how the cookies production line should be built.*

Flows consumes resources such as memory and CPU while they process messages, and they have a
throughput that can be measured in messages per second.

It is really important to realize that queueing theory applies here, therefore processing power and
pipeline design should match message arrival rate and other requirements such as latency.

# Flow Configuration

When a Flow is created using a parametric pipeline, a configuration specifying the parameter values
should be provided. This is done using a custom JSON object which contain all the required
parameters, and that will be validated using the pipeline schema.

# Flows Management

Astarte Flow allows flows management (start, stop, inspect) using
[Astarte Dashboard](https://github.com/astarte-platform/astarte-dashboard) or
[Astarte Flow REST API](api/index.html#/pipelines/createPipeline). The latter should be prefered
for building custom Astarte Flow clients, scripts and automations.
