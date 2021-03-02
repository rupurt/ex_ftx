defmodule ExFtx.SpotMargin.LendingHistory do
  alias ExFtx.JsonResponse

  @type credentials :: ExFtx.Credentials.t()
  @type borrow_rate :: ExFtx.LendingHistory.t()
  @type result :: {:ok, [borrow_rate]} | {:error, :parse_result_item}

  @spec get(credentials) :: result
  def get(credentials) do
    "/spot_margin/lending_history"
    |> ExFtx.HTTPClient.auth_get(credentials, %{})
    |> parse_response()
  end

  defp parse_response({:ok, %JsonResponse{success: true, result: markets}}) do
    markets
    |> Enum.map(&Mapail.map_to_struct(&1, ExFtx.LendingHistory))
    |> Enum.reduce(
      {:ok, []},
      fn
        {:ok, i}, {:ok, acc} -> {:ok, [i | acc]}
        _, _acc -> {:error, :parse_result_item}
      end
    )
  end

  defp parse_response({:ok, %JsonResponse{success: false, error: error}}) do
    {:error, error}
  end
end
