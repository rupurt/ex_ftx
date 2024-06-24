defmodule ExFtx.Account.ShowTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  doctest ExFtx.Account.Show

  setup_all do
    HTTPoison.start()
    :ok
  end

  @valid_credentials %ExFtx.Credentials{
    api_key: System.get_env("FTX_API_KEY"),
    api_secret: System.get_env("FTX_API_SECRET"),
    sub_account: System.get_env("FTX_SUBACCOUNT")
  }
  @invalid_credentials %ExFtx.Credentials{
    api_key: "invalid",
    api_secret: "invalid",
    sub_account: nil
  }

  test ".get/1 ok" do
    use_cassette "account/show/get_ok" do
      assert {:ok, account} = ExFtx.Account.Show.get(@valid_credentials)
      assert %ExFtx.Account{} = account
      assert account.backstop_provider == false
    end
  end

  test ".get/1 unauthorized" do
    use_cassette "account/show/get_unauthorized" do
      assert ExFtx.Account.Show.get(@invalid_credentials) == {:error, "Not logged in"}
    end
  end
end
