# virtual_device_pool

* type: consumer
* input: any kind of message conforming to the [input format](#accepted-input-messages)

This is a consumer block that sends incoming messages to Astarte, acting as one or more virtual
devices.

Information about Device ID, interfaces and paths are deduced from the message key, so it's
important that the key conforms to the [supported format](#accepted-input-messages). You can use a
[lua_map block](0112-lua_map.html) to add the appropriate key to your message.

Please refer to [Astarte documentation](https://docs.astarte-platform.org) to more information about
Astarte concepts like Device IDs, Interfaces etc.

## Target devices

The block has two different behaviours regarding target devices, depending on its configuration:
static and dynamic.

With static devices, the set of target devices is known beforehand and all devices have to
registered manually before using them inside Astarte Flow. Every device can have a different set of
interfaces when using a static device list.

Using dynamic devices the list of devices is built dynamically: every time the block sees a new
Device ID, it registers the device using Pairing API, saves its credentials_secret in the storage
and starts publishing as the device. To do so, a Pairing JWT will have to be provided to the block.
When using dynamic devices, all devices will share the same set of interfaces.

# Properties

## Static devices

* `pairing_url`: Astarte Pairing API base URL. (required, string)
* `target_devices`: An object containing all the information about target devices. (required,
  object)

## `pairing_url`

Target Astarte Pairing API URL. This is usually you base Astarte URL with a `/pairing` suffix (e.g.
`"http://astarte.example.com/pairing"`).

## `target_devices`

An object used to configure the target devices. The object _must_ contain these keys:

* `realm`: the target Realm for the device (required, string)
* `device_id`: the Device ID of the target device (required, string)
* `credentials_secret`: the `credentials_secret` of the target device (required, string)
* `interfaces`: the interfaces supported by the target device. Note that this should be an array of
  objects, the whole interface definition must be present for every interface. Right now only
  datastream interfaces are supported. (requires, array of objects)
  
This is an example of a `target_devices` object:

```
{
  realm: "test",
  device_id: "EA8lpOrkR8OJ-bp9dSVYQA",
  credentials_secret: "N0hUYzmGzpK2SdN8FLoFtw==",
  interfaces: [
    {
      interface_name: "org.astarte-platform.genericsensors.Values",
      version_major: 1,
      version_minor: 0,
      type: "datastream",
      ownership: "device",
      description: "Generic sensors sampled data.",
      mappings: [
        {
          endpoint: "/%{sensor_id}/value",
          type: "double",
          explicit_timestamp: true,
          description: "Sampled real value.",
          doc: "Datastream of sampled real values."
        }
      ]
    }
  ]
}
```

## Dynamic devices

* `pairing_url`: Astarte Pairing API base URL. (required, string)
* `realms`: An object containing realms information. (required, object)
* `interfaces`: the interfaces supported by the target devices. Note that this should be an array of
  objects, the whole interface definition must be present for every interface (required, array of
  objects).

## `pairing_url`

Target Astarte Pairing API URL. This is usually you base Astarte URL with a `/pairing` suffix (e.g.
`"http://astarte.example.com/pairing"`).

## `realms`

An object used to configure the target devices. The object _must_ contain these keys:

* `realm`: the realm name (required, string)
* `jwt`: a JWT with the correct claims to access the target Astarte Pairing API instance. (required,
  string)

This is an example of a `realms` object:

```
{
  realm: "test",
  jwt: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE2MTIyODA4MjIsImFfcGEiOlsiLio6Oi4qIl19.RjqQGV3-ZNbqJ-wj77Sw41CfsWHhlLf9hBZ1Ni-2TQNeKwdpWlmClA1yrtRv41dtVojWjGPLdPMeC7R7yx46VgJlnJXrNE1ffxflAtls5kE3cMF8h6scqbS4Hy7oP_G2g7XS1c9HCwwkiSRzqu6pUY0XgtI0ss35OhvrpkNn0UC4sGS8uAxQauATbfzBdIvkiWPqF-CUrT23sHISlfEv6Y_cnciszJsGTGhVlG1M2hqYHITgnFOivxCgLPQUpqI0GCjkPbfJp9eBClDXJdvIimzRQ74Hv0arBOC6OrCLvztMAwQaxBm47w9sCjkP-aCMN2JqBpmimzFEU8ulXVjxQcgfnAIWrL1cMo4DOhwPvRmyy6Zc9ahRzQdpYvbzbTTfMkPU6u3m-u9CL5JXI8B1l_RriambWsbUeMsOR0WZG9zC98YUwar9bA1o6S7w-3DzxuXDZ4yEe_VdEO8QHb9G_5S1nYXClFXoeL2tRk4Ib9g2HzewC3Zt7pQCX3ksukaPwsxauivQ6m3C_j6LEPiPR4FG2-rJyWFrnAmltYlYs0z7rP0WQjicNIpIRZkB2ovi8gw-PHXFbVlmFfoTx7yl2wWXxLIFDoDieZGdbYcciOERZZ_JzeF7XEWnJvUPmIGhwa5W-UEhAPHXrYjuvHeWTC-FIV5yvjiiSKYjA-DiZSU"
}
```

## `interfaces`

The interfaces supported by the target devices. Note that this should be an array of objects, the
whole interface definition in must be present for every interface. Right now only datastream
interfaces are supported.

This is an example of an `interfaces` array:

```
[
  {
    interface_name: "org.astarte-platform.genericsensors.Values",
    version_major: 1,
    version_minor: 0,
    type: "datastream",
    ownership: "device",
    description: "Generic sensors sampled data.",
    mappings: [
      {
        endpoint: "/%{sensor_id}/value",
        type: "double",
        explicit_timestamp: true,
        description: "Sampled real value.",
        doc: "Datastream of sampled real values."
      }
    ]
  }
]
```

# Accepted Input Messages

When receiving a message, the `virtual_device_pool` block expects a key with this format:

```
realm/device_id/interface_name/path
```

So, for example, an incoming message with key
`test/EA8lpOrkR8OJ-bp9dSVYQA/org.astarte-platform.genericsensors.Values/mysensor/value` will produce
a message sent from a device in the `test` realm with Device ID `EA8lpOrkR8OJ-bp9dSVYQA` on the
`org.astarte-platform.genericsensors.Values` interface with `/mysensor/value` path.

If you're using a static `virtual_device_pool`, the Device ID must be present in the list of target
devices. If you're using a dynamic `virtual_device_pool`, the device will be registered if needed.

`data` (and its `type`) must be compatible with the type declared in the mapping of the interface,
so if an interface expects a `double` value but a `string` is received, the message will be
discarded.

If the interface supports an `explicit_timestamp`, the message `timestamp` is used as explicit
timestamp.

# Examples

## Static devices

```
[...]
| virtual_device_pool
  .pairing_url("https://astarte.example.com/pairing")
  .target_devices(
    [
      {
        realm: "test",
        device_id: "EA8lpOrkR8OJ-bp9dSVYQA",
        credentials_secret: "N0hUYzmGzpK2SdN8FLoFtw==",
        interfaces: [
          {
            interface_name: "org.astarte-platform.genericsensors.Values",
            version_major: 1,
            version_minor: 0,
            type: "datastream",
            ownership: "device",
            description: "Generic sensors sampled data.",
            mappings: [
              {
                endpoint: "/%{sensor_id}/value",
                type: "double",
                explicit_timestamp: true,
                description: "Sampled real value.",
                doc: "Datastream of sampled real values."
              }
            ]
          }
        ]
      }
    ]
  )
```

## Dynamic devices

```
| virtual_device_pool
  .pairing_url("https://astarte.example.com/pairing")
  .realms([
    {
      realm: "test",
      jwt: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE2MTIyODA4MjIsImFfcGEiOlsiLio6Oi4qIl19.RjqQGV3-ZNbqJ-wj77Sw41CfsWHhlLf9hBZ1Ni-2TQNeKwdpWlmClA1yrtRv41dtVojWjGPLdPMeC7R7yx46VgJlnJXrNE1ffxflAtls5kE3cMF8h6scqbS4Hy7oP_G2g7XS1c9HCwwkiSRzqu6pUY0XgtI0ss35OhvrpkNn0UC4sGS8uAxQauATbfzBdIvkiWPqF-CUrT23sHISlfEv6Y_cnciszJsGTGhVlG1M2hqYHITgnFOivxCgLPQUpqI0GCjkPbfJp9eBClDXJdvIimzRQ74Hv0arBOC6OrCLvztMAwQaxBm47w9sCjkP-aCMN2JqBpmimzFEU8ulXVjxQcgfnAIWrL1cMo4DOhwPvRmyy6Zc9ahRzQdpYvbzbTTfMkPU6u3m-u9CL5JXI8B1l_RriambWsbUeMsOR0WZG9zC98YUwar9bA1o6S7w-3DzxuXDZ4yEe_VdEO8QHb9G_5S1nYXClFXoeL2tRk4Ib9g2HzewC3Zt7pQCX3ksukaPwsxauivQ6m3C_j6LEPiPR4FG2-rJyWFrnAmltYlYs0z7rP0WQjicNIpIRZkB2ovi8gw-PHXFbVlmFfoTx7yl2wWXxLIFDoDieZGdbYcciOERZZ_JzeF7XEWnJvUPmIGhwa5W-UEhAPHXrYjuvHeWTC-FIV5yvjiiSKYjA-DiZSU"
    }
  ])
  .interfaces([
    {
      interface_name: "org.astarte-platform.genericsensors.Values",
      version_major: 1,
      version_minor: 0,
      type: "datastream",
      ownership: "device",
      description: "Generic sensors sampled data.",
      mappings: [
        {
          endpoint: "/%{sensor_id}/value",
          type: "double",
          explicit_timestamp: true,
          description: "Sampled real value.",
          doc: "Datastream of sampled real values."
        }
      ]
    }
  ])
```
