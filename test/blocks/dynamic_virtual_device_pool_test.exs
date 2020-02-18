#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule Astarte.Flow.Blocks.DynamicVirtualDevicePoolTest do
  use ExUnit.Case
  import Mox

  alias Astarte.Flow.Blocks.DynamicVirtualDevicePool
  alias Astarte.Flow.Message
  alias Astarte.Flow.VirtualDevicesSupervisor

  @pairing_url "http://localhost:4003"
  @realm "test"
  @jwt "almostajwt"
  @already_started_device_id "FJrMBxtwTP2CTkqYUVmurw"
  @already_registered_device_id "CGqGxxoIR4qOvJ1zQKA4yQ"
  @unknown_device_id "5_pCwEMcTLSPUFhBrqCuGw"
  @known_credentials_secret "12345"
  @new_credentials_secret "67890"
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

  @pairing_jwt_map %{
    @realm => @jwt
  }

  @valid_opts [
    pairing_jwt_map: @pairing_jwt_map,
    pairing_url: @pairing_url,
    interface_provider: @interfaces_dir,
    credentials_storage: CredentialsStorageMock,
    pairing_agent: PairingAgentMock
  ]

  @already_started_device_opts [
    realm: @realm,
    device_id: @already_started_device_id,
    credentials_secret: @known_credentials_secret,
    pairing_url: @pairing_url,
    interface_provider: @interfaces_dir
  ]

  describe "invalid key" do
    setup [
      :set_mox_from_context,
      :verify_on_exit!,
      :start_pool,
      :subscribe_to_test_producer
    ]

    test "does not generate publish", %{producer: producer} do
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
  end

  describe "already started device" do
    setup [
      :set_mox_from_context,
      :verify_on_exit!,
      :base_mocks_init,
      :start_device,
      :start_pool,
      :subscribe_to_test_producer
    ]

    test "does not generate publish with valid key but wrong data type", %{producer: producer} do
      timestamp = DateTime.utc_now()
      timestamp_micros = DateTime.to_unix(timestamp, :microsecond)

      full_path =
        "#{@realm}/#{@already_started_device_id}/org.astarteplatform.test.DeviceDatastream/realValue"

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

    test "generates publish with valid key", %{producer: producer} do
      timestamp = DateTime.utc_now()
      timestamp_micros = DateTime.to_unix(timestamp, :microsecond)

      full_path =
        "#{@realm}/#{@already_started_device_id}/org.astarteplatform.test.DeviceDatastream/realValue"

      data = 42.0

      ConnectionMock
      |> expect(:publish_sync, fn "#{@realm}/#{@already_started_device_id}",
                                  ^full_path,
                                  bson_payload,
                                  _opts ->
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

    test "drops invalid realm", %{producer: producer} do
      timestamp = DateTime.utc_now()
      timestamp_micros = DateTime.to_unix(timestamp, :microsecond)
      unhandled_realm = "unhandled"

      data = 42.0

      full_path_1 =
        "#{@realm}/#{@already_started_device_id}/org.astarteplatform.test.DeviceDatastream/realValue"

      CredentialsStorageMock
      |> expect(:fetch_credentials_secret, fn "unhandled", @already_started_device_id ->
        :error
      end)

      messages =
        for realm <- [@realm, unhandled_realm] do
          key =
            "#{realm}/#{@already_started_device_id}/org.astarteplatform.test.DeviceDatastream/realValue"

          %Message{
            key: key,
            data: data,
            type: :integer,
            timestamp: timestamp_micros
          }
        end

      ConnectionMock
      |> expect(:publish_sync, fn "#{@realm}/#{@already_started_device_id}",
                                  ^full_path_1,
                                  bson_payload,
                                  _opts ->
        assert %{"v" => ^data, "t" => t} = Cyanide.decode!(bson_payload)
        assert t == DateTime.truncate(timestamp, :millisecond)
        :ok
      end)

      :ok = TestProducer.push(producer, messages)

      # Wait a little to ensure the message goes through
      :timer.sleep(100)
    end
  end

  describe "device registered but not started" do
    setup [
      :set_mox_from_context,
      :verify_on_exit!,
      :base_mocks_init,
      :start_pool,
      :subscribe_to_test_producer
    ]

    test "starts and generates publish with valid key", %{producer: producer} do
      timestamp = DateTime.utc_now()
      timestamp_micros = DateTime.to_unix(timestamp, :microsecond)

      full_path =
        "#{@realm}/#{@already_registered_device_id}/org.astarteplatform.test.DeviceDatastream/realValue"

      data = 42.0

      CredentialsStorageMock
      |> expect(:fetch_credentials_secret, fn @realm, @already_registered_device_id ->
        {:ok, @known_credentials_secret}
      end)

      ConnectionMock
      |> expect(:publish_sync, fn "#{@realm}/#{@already_registered_device_id}",
                                  ^full_path,
                                  bson_payload,
                                  _opts ->
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
      :timer.sleep(1000)
    end
  end

  describe "unregistered device" do
    setup [
      :set_mox_from_context,
      :verify_on_exit!,
      :base_mocks_init,
      :start_pool,
      :subscribe_to_test_producer
    ]

    test "registers, starts and generates publish with valid key", %{producer: producer} do
      timestamp = DateTime.utc_now()
      timestamp_micros = DateTime.to_unix(timestamp, :microsecond)

      full_path =
        "#{@realm}/#{@unknown_device_id}/org.astarteplatform.test.DeviceDatastream/realValue"

      data = 42.0

      CredentialsStorageMock
      |> expect(:fetch_credentials_secret, fn @realm, @unknown_device_id ->
        :error
      end)
      |> expect(:store_credentials_secret, fn @realm,
                                              @unknown_device_id,
                                              @new_credentials_secret ->
        :ok
      end)

      PairingAgentMock
      |> expect(:register_device, fn _client, @unknown_device_id ->
        {:ok,
         %{status: 201, body: %{"data" => %{"credentials_secret" => @new_credentials_secret}}}}
      end)

      ConnectionMock
      |> expect(:publish_sync, fn "#{@realm}/#{@unknown_device_id}",
                                  ^full_path,
                                  bson_payload,
                                  _opts ->
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
      :timer.sleep(1000)
    end
  end

  defp subscribe_to_test_producer(%{pool: pool}) do
    {:ok, producer} = TestProducer.start_link()
    GenStage.sync_subscribe(pool, to: producer)

    {:ok, %{producer: producer}}
  end

  defp start_device(_context) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        VirtualDevicesSupervisor,
        {Astarte.Device, @already_started_device_opts}
      )

    Astarte.Device.wait_for_connection(pid)

    :ok
  end

  defp start_pool(_) do
    {:ok, pool} = DynamicVirtualDevicePool.start_link(@valid_opts)

    # Kill all Astarte.Device on exit after every test
    on_exit(fn ->
      device_pids =
        DynamicSupervisor.which_children(VirtualDevicesSupervisor)
        |> Enum.map(fn {_, pid, _, _} -> pid end)

      for pid <- device_pids do
        ref = Process.monitor(pid)
        DynamicSupervisor.terminate_child(VirtualDevicesSupervisor, pid)

        assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500
      end
    end)

    {:ok, %{pool: pool}}
  end

  defp base_mocks_init(_) do
    PairingMock
    |> expect(:get_mqtt_v1_credentials, &get_valid_mqtt_v1_credentials/3)
    |> expect(:info, &get_info/2)

    ConnectionMock
    |> expect(:start_link, fn _opts ->
      # Make the device think it's connected
      device_process = self()
      :gen_statem.cast(device_process, {:connection_status, :up})

      {:ok, :not_a_pid}
    end)
    |> expect(:publish_sync, fn _client_id, _topic, _payload, opts ->
      # Introspection
      assert Keyword.get(opts, :qos) == 2
      :ok
    end)
    |> expect(:publish_sync, fn _client_id, _topic, _payload, opts ->
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
