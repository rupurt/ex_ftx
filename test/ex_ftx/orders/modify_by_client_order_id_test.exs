defmodule ExFtx.Orders.ModifyByClientOrderIdTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  doctest ExFtx.Orders.ModifyByClientOrderId

  setup_all do
    HTTPoison.start()
    :ok
  end

  @valid_credentials %ExFtx.Credentials{
    api_key: System.get_env("FTX_API_KEY"),
    api_secret: System.get_env("FTX_API_SECRET")
  }
  @invalid_credentials %ExFtx.Credentials{
    api_key: "invalid",
    api_secret: "invalid"
  }
  @valid_payload %ExFtx.OrderPayload{
    client_id: UUID.uuid4(),
    market: "BTC/USD",
    side: "buy",
    price: 25000.0,
    type: "limit",
    size: 0.0001,
    reduce_only: false,
    ioc: false,
    post_only: true
  }
  @valid_modify_payload %ExFtx.ModifyOrderByClientIdPayload{
    client_id: UUID.uuid4(),
    price: 25001.0,
    size: 0.00011
  }
  @valid_no_client_id_modify_payload %ExFtx.ModifyOrderByClientIdPayload{
    price: 25001.0,
    size: 0.00011
  }
  @insufficient_margin_modify_payload Map.merge(@valid_modify_payload, %{
                                        client_id: UUID.uuid4(),
                                        size: 1.0
                                      })
  @size_too_small_modify_payload Map.merge(@valid_modify_payload, %{
                                   client_id: UUID.uuid4(),
                                   size: 0.00001
                                 })

  test ".post/3 ok" do
    use_cassette "orders/modify_by_client_order_id/post_ok" do
      assert {:ok, order} = ExFtx.Orders.Create.post(@valid_credentials, @valid_payload)

      assert {:ok, modified_order} =
               ExFtx.Orders.ModifyByClientOrderId.post(
                 @valid_credentials,
                 order.client_id,
                 @valid_modify_payload
               )

      assert modified_order.client_id != order.client_id
      assert modified_order.id != order.id
      assert modified_order.created_at != nil
    end
  end

  test ".post/3 ok no client_id" do
    use_cassette "orders/modify_by_client_order_id/post_ok_no_client_id" do
      assert {:ok, order} = ExFtx.Orders.Create.post(@valid_credentials, @valid_payload)

      assert {:ok, modified_order} =
               ExFtx.Orders.ModifyByClientOrderId.post(
                 @valid_credentials,
                 order.client_id,
                 @valid_no_client_id_modify_payload
               )

      assert modified_order.client_id != order.client_id
      assert modified_order.client_id == nil
      assert modified_order.id != order.id
      assert modified_order.created_at != nil
    end
  end

  test ".post/3 insufficient margin" do
    use_cassette "orders/modify_by_client_order_id/post_insufficient_margin" do
      assert {:ok, order} = ExFtx.Orders.Create.post(@valid_credentials, @valid_payload)

      assert ExFtx.Orders.ModifyByClientOrderId.post(
               @valid_credentials,
               order.client_id,
               @insufficient_margin_modify_payload
             ) ==
               {:error, "Not enough balances"}
    end
  end

  test ".post/3 size too small" do
    use_cassette "orders/modify_by_client_order_id/post_size_too_small" do
      assert {:ok, order} = ExFtx.Orders.Create.post(@valid_credentials, @valid_payload)

      assert ExFtx.Orders.ModifyByClientOrderId.post(
               @valid_credentials,
               order.client_id,
               @size_too_small_modify_payload
             ) ==
               {:error, "Size too small for provide"}
    end
  end

  test ".post/3 unauthorized" do
    use_cassette "orders/modify_by_client_order_id/post_unauthorized" do
      assert {:ok, order} = ExFtx.Orders.Create.post(@valid_credentials, @valid_payload)

      assert ExFtx.Orders.ModifyByClientOrderId.post(
               @invalid_credentials,
               order.client_id,
               @valid_modify_payload
             ) ==
               {:error, "Not logged in"}
    end
  end
end
