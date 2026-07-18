defmodule Plotline.AI.Gemini do
  @moduledoc false

  @behaviour Plotline.AI.Provider

  require Logger

  @base_url "https://generativelanguage.googleapis.com/v1beta"

  @impl true
  def generate(system_instruction, user_message) do
    with {:ok, api_key} <- fetch_api_key(),
         {:ok, model} <- fetch_model(),
         {:ok, body} <- request_with_retries(api_key, model, system_instruction, user_message) do
      parse_response(body)
    end
  end

  defp fetch_api_key do
    case api_key() do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :not_configured}
    end
  end

  defp fetch_model do
    model =
      System.get_env("GEMINI_MODEL") ||
        Application.get_env(:plotline, Plotline.AI, []) |> Keyword.get(:model) ||
        "gemini-flash-lite-latest"

    {:ok, model}
  end

  defp request_with_retries(api_key, model, system_instruction, user_message) do
    retries = Keyword.get(ai_config(), :request_retries, 5)
    base_ms = Keyword.get(ai_config(), :retry_base_ms, 15_000)

    do_request(api_key, model, system_instruction, user_message, retries, base_ms)
  end

  defp do_request(api_key, model, system_instruction, user_message, retries_left, base_ms) do
    case request(api_key, model, system_instruction, user_message) do
      {:ok, body} ->
        {:ok, body}

      {:error, :rate_limited} when retries_left > 0 ->
        attempt = Keyword.get(ai_config(), :request_retries, 5) - retries_left + 1
        sleep_ms = trunc(base_ms * :math.pow(2, attempt - 1))

        Logger.warning(
          "Gemini rate limited; retrying in #{sleep_ms}ms (#{retries_left} retries left)"
        )

        Process.sleep(sleep_ms)
        do_request(api_key, model, system_instruction, user_message, retries_left - 1, base_ms)

      other ->
        other
    end
  end

  defp request(api_key, model, system_instruction, user_message) do
    url = "#{@base_url}/models/#{model}:generateContent"

    payload = %{
      system_instruction: %{parts: [%{text: system_instruction}]},
      contents: [%{role: "user", parts: [%{text: user_message}]}],
      generationConfig: %{
        temperature: 0.4,
        maxOutputTokens: 4_096
      }
    }

    case Req.post(url,
           params: [key: api_key],
           json: payload,
           receive_timeout: 60_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, api_error_message(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(%{"candidates" => [%{"content" => %{"parts" => [%{"text" => text} | _]}} | _]}) do
    {:ok, String.trim(text)}
  end

  defp parse_response(%{"candidates" => []}) do
    {:error, :empty_response}
  end

  defp parse_response(body) do
    {:error, {:unexpected_response, api_error_message(body)}}
  end

  defp api_error_message(%{"error" => %{"message" => message}}) when is_binary(message), do: message
  defp api_error_message(_), do: "request failed"

  defp ai_config, do: Application.get_env(:plotline, Plotline.AI, [])

  defp api_key do
    ai_config()
    |> Keyword.get(:api_key)
    |> case do
      key when is_binary(key) and key != "" -> key
      _ -> System.get_env("GEMINI_API_KEY")
    end
  end
end
