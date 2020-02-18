#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Flow.Blocks.VirtualDevicePoolTest do
  use ExUnit.Case
  import Mox

  alias Astarte.Flow.Blocks.VirtualDevicePool
  alias Astarte.Flow.Message
  alias Astarte.Flow.VirtualDevicesSupervisor

  @pairing_url "http://localhost:4003"
  @realm "test"
  @device_id_1 "FJrMBxtwTP2CTkqYUVmurw"
  @device_id_2 "5_pCwEMcTLSPUFhBrqCuGw"
  @credentials_secret "12345"
  @interfaces_dir Path.expand("test/interfaces")
  @certificate """
  -----BEGIN CERTIFICATE-----
  MIIDYDCCAkigAwIBAgIJAJXCkuI7009FMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
  BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
  aWRnaXRzIFB0eSBMdGQwHhcNMTkwNjE0MDk0MjMzWhcNMjAwNjEzMDk0MjMzWjBF
  MQswCQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50
  ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
  CgKCAQEAwUs5H6MrCBtLtpyiZcIQ0mz3cgS4mZIk1KjMZcWx5LoMT7BywjQqiHmZ
  xKz+p5Kmi43hoy/wDEpfY4KgCWPoGoUxitBVdCAaUWP6SPj+WDnVvl2uHBNDqp49
  ENZJwdX1cx4On6X0DcQMwH6sHkjv3kVS3lXrzIVvEXIn9QFEv9AxJymLMR9VDOyU
  F7vmwRCi07CGva4sAceY85P9WmLu5XOrt0FSsQzQmf2nL5ZpFjfTrt8tTN4axXKi
  Fop9KL0Xc7B4baWVIyxUJWw+MinQTvlwif9IP94Y6EOgO1H782DFG0BCq/q3W3KR
  HBhMthNqcjiiGtnVE29PqxVYEsc87wIDAQABo1MwUTAdBgNVHQ4EFgQUTHDT6pQ5
  I2oIAR9TNmP57QjEL4IwHwYDVR0jBBgwFoAUTHDT6pQ5I2oIAR9TNmP57QjEL4Iw
  DwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAjc0jh1f9+moyaaFo
  20/jhvkeSjS9+iD2RlCc2mxvvkRf2+ECQ+mY+MAXH37FJy9U4pPp5cz8x+kdKwYm
  VKYzvs6YCnZIyWo0ryxqIJscLZSsQF7uSxyp9n+UODdHtONe2PW1qAp+fXKHb6oT
  eEX3vXbggfG1RN13sK/jCG5wI8qrasEZcTVU+sv+KdLtq9e4jdQ9JPkEZNuGZoqU
  RktOI9Njy+a74pE17WD0XZKK81TcW6c0fPAkFiG61rHh41BLWfrn+60QsvaqMnWr
  ap9JZn1gjqddbwXBpHm/bojvkN/DcCGikxPFUQo3/lICDreo9J+E25iAXTut55Ue
  LAsZ1Q==
  -----END CERTIFICATE-----
  """

  @devices [
    [
      realm: @realm,
      device_id: @device_id_1,
      credentials_secret: @credentials_secret,
      interface_provider: @interfaces_dir
    ],
    [
      realm: @realm,
      device_id: @device_id_2,
      credentials_secret: @credentials_secret,
      interface_provider: @interfaces_dir
    ]
  ]

  @device_count length(@devices)

  @valid_opts [
    pairing_url: @pairing_url,
    devices: @devices
  ]

  setup [
    :set_mox_from_context,
    :verify_on_exit!,
    :mocks_init,
    :start_pool,
    :subscribe_to_test_producer
  ]

  test "invalid key does not generate publish", %{producer: producer} do
    timestamp = DateTime.utc_now()
    timestamp_micros = DateTime.to_unix(timestamp, :microsecond)

    message = %Message{
      key: "invalid",
      data: 42,
      type: :integer,
      timestamp: timestamp_micros
    }

    :ok = TestProducer.push(producer, message)

    # Wait a little to ensure the message goes through
    :timer.sleep(100)
  end

  test "valid key with wrong data type does not generate publish", %{producer: producer} do
    timestamp = DateTime.utc_now()
    timestamp_micros = DateTime.to_unix(timestamp, :microsecond)
    full_path = "#{@realm}/#{@device_id_1}/org.astarteplatform.test.DeviceDatastream/realValue"

    message = %Message{
      key: full_path,
      data: "this is a string but the interface wants a double",
      type: :string,
      timestamp: timestamp_micros
    }

    :ok = TestProducer.push(producer, message)

    # Wait a little to ensure the message goes through
    :timer.sleep(100)
  end

  test "valid key generates publish", %{producer: producer} do
    timestamp = DateTime.utc_now()
    timestamp_micros = DateTime.to_unix(timestamp, :microsecond)
    full_path = "#{@realm}/#{@device_id_1}/org.astarteplatform.test.DeviceDatastream/realValue"
    data = 42.0

    ConnectionMock
    |> expect(:publish_sync, fn "#{@realm}/#{@device_id_1}", ^full_path, bson_payload, _opts ->
      assert %{"v" => ^data, "t" => t} = Cyanide.decode!(bson_payload)
      assert t == DateTime.truncate(timestamp, :millisecond)
      :ok
    end)

    message = %Message{
      key: full_path,
      data: data,
      type: :integer,
      timestamp: timestamp_micros
    }

    :ok = TestProducer.push(producer, message)

    # Wait a little to ensure the message goes through
    :timer.sleep(100)
  end

  test "both devices publish with valid keys, invalid device is dropped", %{producer: producer} do
    timestamp = DateTime.utc_now()
    timestamp_micros = DateTime.to_unix(timestamp, :microsecond)
    unhandled_id = "6X-Y_AUrS9Ce1H0_tmsUYA"

    data = 42.0
    full_path_1 = "#{@realm}/#{@device_id_1}/org.astarteplatform.test.DeviceDatastream/realValue"
    full_path_2 = "#{@realm}/#{@device_id_2}/org.astarteplatform.test.DeviceDatastream/realValue"

    messages =
      for device_id <- [@device_id_1, @device_id_2, unhandled_id] do
        key = "#{@realm}/#{device_id}/org.astarteplatform.test.DeviceDatastream/realValue"

        %Message{
          key: key,
          data: data,
          type: :integer,
          timestamp: timestamp_micros
        }
      end

    ConnectionMock
    |> expect(:publish_sync, fn "#{@realm}/#{@device_id_1}", ^full_path_1, bson_payload, _opts ->
      assert %{"v" => ^data, "t" => t} = Cyanide.decode!(bson_payload)
      assert t == DateTime.truncate(timestamp, :millisecond)
      :ok
    end)
    |> expect(:publish_sync, fn "#{@realm}/#{@device_id_2}", ^full_path_2, bson_payload, _opts ->
      assert %{"v" => ^data, "t" => t} = Cyanide.decode!(bson_payload)
      assert t == DateTime.truncate(timestamp, :millisecond)
      :ok
    end)

    :ok = TestProducer.push(producer, messages)

    # Wait a little to ensure the message goes through
    :timer.sleep(100)
  end

  defp subscribe_to_test_producer(%{pool: pool}) do
    {:ok, producer} = TestProducer.start_link()
    GenStage.sync_subscribe(pool, to: producer)

    {:ok, %{producer: producer}}
  end

  defp start_pool(_) do
    {:ok, pool} = VirtualDevicePool.start_link(@valid_opts)

    device_pids =
      DynamicSupervisor.which_children(VirtualDevicesSupervisor)
      |> Enum.map(fn {_, pid, _, _} -> pid end)

    # Check that all devices are started
    assert length(device_pids) == @device_count

    # Check that we waited for connected for all devices
    for pid <- device_pids do
      assert {:connected, _} = :sys.get_state(pid)
    end

    # Kill all Astarte.Device on exit after every test
    on_exit(fn ->
      for pid <- device_pids do
        ref = Process.monitor(pid)
        DynamicSupervisor.terminate_child(VirtualDevicesSupervisor, pid)

        assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500
      end
    end)

    {:ok, %{pool: pool}}
  end

  defp mocks_init(_) do
    PairingMock
    |> expect(:get_mqtt_v1_credentials, @device_count, &get_valid_mqtt_v1_credentials/3)
    |> expect(:info, @device_count, &get_info/2)

    ConnectionMock
    |> expect(:start_link, @device_count, fn _opts ->
      # Make the device think it's connected
      device_process = self()
      :gen_statem.cast(device_process, {:connection_status, :up})

      {:ok, :not_a_pid}
    end)
    |> expect(:publish_sync, @device_count, fn _client_id, _topic, _payload, opts ->
      # Introspection
      assert Keyword.get(opts, :qos) == 2
      :ok
    end)
    |> expect(:publish_sync, @device_count, fn _client_id, _topic, _payload, opts ->
      # Empty cache
      assert Keyword.get(opts, :qos) == 2
      :ok
    end)

    :ok
  end

  defp get_valid_mqtt_v1_credentials(_client, _device_id, _csr) do
    body =
      %{}
      |> put_in(Enum.map(["data", "client_crt"], &Access.key(&1, %{})), @certificate)

    {:ok, %{status: 201, body: body}}
  end

  defp get_info(_client, _device_id) do
    body =
      %{}
      |> put_in(
        Enum.map(["data", "protocols", "astarte_mqtt_v1", "broker_url"], &Access.key(&1, %{})),
        "mqtts://broker.example.com"
      )

    {:ok, %{status: 200, body: body}}
  end
end
