defmodule ExFtx.HTTPClient do
  @type verb :: :get | :post | :put | :delete
  @type params :: map
  @type path :: String.t()
  @type uri :: String.t()
  @type credentials :: ExFtx.Credentials.t()
  @type error_reason :: Maptu.Extension.non_strict_error_reason() | HTTPoison.Error.t()
  @type non_auth_response :: {:ok, ExFtx.JsonResponse.t()} | {:error, error_reason}
  @type auth_response :: {:ok, ExFtx.JsonResponse.t()} | {:error, error_reason}

  @spec domain :: String.t()
  def domain, do: Application.get_env(:ex_ftx, :domain, "ftx.com")

  @spec protocol :: String.t()
  def protocol, do: Application.get_env(:ex_ftx, :protocol, "https://")

  @spec origin :: String.t()
  def origin, do: protocol() <> domain()

  @spec url(uri) :: String.t()
  def url(uri), do: origin() <> uri

  @spec api_path :: String.t()
  def api_path, do: Application.get_env(:ex_ftx, :api_path, "/api")

  @spec non_auth_get(path, params) :: non_auth_response
  def non_auth_get(path, params \\ %{}) do
    non_auth_request(:get, path |> to_uri(params))
  end

  @spec non_auth_request(verb, uri) :: non_auth_response
  def non_auth_request(verb, uri) do
    headers = [] |> put_content_type(:json)

    %HTTPoison.Request{
      method: verb,
      url: url(uri),
      headers: headers
    }
    |> send
  end

  @spec auth_get(path, credentials, params) :: auth_response
  def auth_get(path, credentials, params) do
    auth_request(:get, path |> to_uri(params), credentials, "")
  end

  @spec auth_post(path, credentials, params) :: auth_response
  def auth_post(path, credentials, params) do
    uri = path |> to_uri(%{})
    body = Jason.encode!(params)
    auth_request(:post, uri, credentials, body)
  end

  @spec auth_delete(path, credentials, params) :: auth_response
  def auth_delete(path, credentials, params \\ %{}) do
    uri = path |> to_uri(%{})
    body = Jason.encode!(params)
    auth_request(:delete, uri, credentials, body)
  end

  @spec auth_request(verb, uri, credentials, term) :: auth_response
  def auth_request(verb, uri, credentials, body) do
    headers =
      verb
      |> auth_headers(uri, body, credentials)
      |> put_content_type(:json)

    %HTTPoison.Request{
      method: verb,
      url: url(uri),
      headers: headers,
      body: body
    }
    |> send
  end

  defp to_uri(path, params) do
    %URI{
      path: api_path() <> path,
      query: URI.encode_query(params)
    }
    |> URI.to_string()
    |> String.trim("?")
  end

  defp put_content_type(headers, :json) do
    Keyword.put(headers, :"Content-Type", "application/json")
  end

  defp send(request) do
    request
    |> HTTPoison.request()
    |> parse_response
  end

  defp auth_headers(http_method, uri, request_body, credentials) do
    normalized_http_method = http_method |> normalize_http_method
    timestamp = ExFtx.Auth.timestamp()

    signature =
      ExFtx.Auth.sign(
        credentials.api_secret,
        timestamp,
        normalized_http_method,
        uri,
        request_body
      )

    ["FTX-KEY": credentials.api_key, "FTX-SIGN": signature, "FTX-TS": timestamp]
    |> put_sub_account_auth_header(credentials.sub_account)
  end

  defp put_sub_account_auth_header(headers, nil), do: headers
  defp put_sub_account_auth_header(headers, sub_account), do: headers |> Keyword.put(:"FTX-SUBACCOUNT", sub_account)

  defp normalize_http_method(:get), do: "GET"
  defp normalize_http_method(:post), do: "POST"
  defp normalize_http_method(:put), do: "PUT"
  defp normalize_http_method(:delete), do: "DELETE"

  defp parse_response({:ok, %HTTPoison.Response{body: body}}) do
    {:ok, json} = Jason.decode(body)
    Mapail.map_to_struct(json, ExFtx.JsonResponse, transformations: [:snake_case])
  end

  defp parse_response({:error, _} = result) do
    result
  end
end
