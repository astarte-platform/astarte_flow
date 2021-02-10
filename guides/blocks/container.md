# container

**This block API will likely change in future versions.**

This is a special block which allows to offload computation to a
[Docker container](https://www.docker.com/resources/what-container).

Messages are sent and received to/from the container via
[AMQP](https://www.rabbitmq.com/tutorials/amqp-concepts.html).

The block will manage the creation of the Container in a [Kubernetes](https://kubernetes.io/)
cluster using the
[Astarte Kubernetes Operator](https://github.com/astarte-platform/astarte-kubernetes-operator).

The Container runs with the `runAsNonRoot` security feature set to `true`. This means that you
should make sure that your application doesn't run as the root user. You should use a normal user
with the necessary permissions to run the application instead.

Containers allow implementing and deploying algorithms with a language-agnostic approach. However a
[Python SDK](https://github.com/astarte-platform/astarte_flow_sdk_python) is available as a
replacement to AMQP connection and JSON SerDes code.

Most of the times containers can be avoided and simple messages transformation and filtering can
be achieved using [Lua 5.2](https://www.lua.org/manual/5.2/) scripting blocks.

# Properties

* `image`: Docker container image (required, string)
* `type`: Container type, either `"producer"`, `"consumer"` or `"producer_consumer"` (required)
* `image_pull_secrets`: The secrets used to pull images from private registries (optional, array of
  strings)

## `image`

Docker container image.

## `type`

**This block property is going to be removed in favor of implicit configuration.**

According to container type a container is used as an AMQP producer, cosumer or as a middle
processing block.

## `image_pull_secrets`

A list of names of Kubernetes secrets that will be used to pull the image. This is required only if
the image is pulled from a private registry. The secrets must be already existing and must live in
the same namespace where Astarte Flow is deployed.

For more information on creating them, please read the relevant [Kubernetes
documentation](https://kubernetes.io/docs/concepts/containers/images/#creating-a-secret-with-a-docker-config) 

# Accepted Input Messages

Input messages are consumed only from `consumer` and `producer_consumer` containers.

For those types of containers accepted input messages type and format depends on their
implementation.

# Output message

An output message is produced only from `producer` and `producer_consumer` containers.

For those types of containers the output message format depends on their implementation.

# Examples

The following example uses a container (pulled from `"example/test"`) and declares it as producer
and consumer, wich consumes messages produced by any_producer_block and feeds into
any_consumer_block:
```
any_producer_block
| container
  .image("example/test")
  .type("producer_consumer")
| any_consumer_block
```
