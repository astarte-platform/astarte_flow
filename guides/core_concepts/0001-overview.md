# Overview

Astarte Flow is a data processing framework which allows you to build reusable pipelines to process,
classify and analyze your data. Flow integrates seamlessly with
[Astarte](https://docs.astarte-platform.org/latest) and [Kubernetes](https://kubernetes.io), letting
you focus on your algorithms while it handles data retrieval, routing and orchestration.

One of Astarte Flow key features is the ability to provide your own container as a data
processing block, without having to worry about all the low level details needed to deploy it inside
Kubernetes and making it receive data. By using [Flow Python
SDK](https://github.com/astarte-platform/astarte_flow_sdk_python), you just have to use the provided
callbacks and functions to interact with incoming and outgoing messages in a standard format, Flow
will take care of the rest.

These are some of the main concepts used in Astarte Flow and covered in this guide:

- [Messages](0002-flow-messages.html) are Flow's representation of a piece of data that is being
  processed.
- [Blocks](0003-blocks.html) are the fundamental processing unit of Astarte Flow.
  [Container Blocks](0111-container.html) are a special kind of block which allows you to process
  your data with a Docker container.
- [Pipelines](0004-pipelines.html) are collections of blocks providing routing logic and
  representing a specific computation.
- [Flows](0005-flows.html) are specific instances of a pipeline, created providing concrete values
  to the parametric values of a pipeline.

The two main ways to interact with Flow are through the [pipeline builder]() and through the [REST
API](api/index.html).
