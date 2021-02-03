# Pipelines

A Pipeline is a blueprint (therefore a description) built as a chain of [blocks](0003-blocks.html).

A pipeline can be parametric, so the same description can be made generic and applied in different
scenarios that require the same computation steps (but performed with different parameters).

Parameters are provided with a JSON configuration object when a pipeline is instantiated, and they
can be accessed using [JSON Path](https://goessner.net/articles/JsonPath/).

Once a pipeline has been instantiated it is called a [Flow](0005-flows.html), and from that moment
it starts processing [messages](0002-flow-messages.html), taking up the necessary computation
resources.

# Designing / Writing a Pipeline

A pipeline can be designed using a visual editor (Pipeline Builder, which is part of
[Astarte Dashboard](https://github.com/astarte-platform/astarte-dashboard/)) or written using
Astarte Flow [Pipeline DSL](0010-defining-a-pipeline.html).

# Managing Pipelines

A pipeline can be installed using Astarte Dashboard or using
[Astarte Flow REST API](api/index.html#/pipelines/createPipeline). The latter is best-suited for
scripts and automations.
