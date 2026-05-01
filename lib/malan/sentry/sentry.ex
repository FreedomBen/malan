defmodule Malan.Sentry do
  alias Malan.Logger.EmailScrubber

  # For Sentry fingerprinting
  #   https://docs.sentry.io/platforms/elixir/#fingerprinting
  def before_send(%{exception: [%{type: Phoenix.Router.NoRouteError}]} = event) do
    # %{event | fingerprint: ["ecto", "db_connection", "timeout"]}
    scrub_emails(event)
  end

  def before_send(event) do
    scrub_emails(event)
  end

  # Redact email-like substrings from the request URL/query string, the top-level
  # event message, and breadcrumb messages/data. Sentry events can carry email
  # addresses when the path contains one (the `:id` route segment resolves through
  # `Accounts.get_user_by_id_or_username/1`), and `Sentry.PlugContext` captures
  # them before the LoggerBackend filter ever runs.
  defp scrub_emails(event) do
    event
    |> update_if_present(:message, &EmailScrubber.scrub/1)
    |> update_if_present(:request, &scrub_request/1)
    |> update_if_present(:breadcrumbs, fn crumbs -> Enum.map(crumbs, &scrub_breadcrumb/1) end)
  end

  defp scrub_request(%{} = req) do
    req
    |> update_if_present(:url, &EmailScrubber.scrub/1)
    |> update_if_present(:query_string, &scrub_query_string/1)
  end

  defp scrub_request(other), do: other

  defp scrub_query_string(qs) when is_binary(qs), do: EmailScrubber.scrub(qs)

  defp scrub_query_string(qs) when is_map(qs) do
    Map.new(qs, fn {k, v} -> {EmailScrubber.scrub(k), EmailScrubber.scrub(v)} end)
  end

  defp scrub_query_string(qs) when is_list(qs) do
    Enum.map(qs, fn
      {k, v} -> {EmailScrubber.scrub(k), EmailScrubber.scrub(v)}
      other -> other
    end)
  end

  defp scrub_query_string(other), do: other

  defp scrub_breadcrumb(%{} = crumb) do
    crumb
    |> update_if_present(:message, &EmailScrubber.scrub/1)
    |> update_if_present(:data, &scrub_breadcrumb_data/1)
  end

  defp scrub_breadcrumb(other), do: other

  defp scrub_breadcrumb_data(%{} = data) do
    Map.new(data, fn {k, v} -> {k, EmailScrubber.scrub(v)} end)
  end

  defp scrub_breadcrumb_data(other), do: other

  # Map.update/4 trips on structs without the key; this variant is struct-safe
  # and skips updates when the value is missing or nil.
  defp update_if_present(%{} = map, key, fun) do
    case Map.get(map, key) do
      nil -> map
      value -> Map.put(map, key, fun.(value))
    end
  end

  defp update_if_present(other, _key, _fun), do: other

  @doc ~S"""
  Wraps the Sentry SDK to NOP when Sentry is not enabled.

  If the Sentry DSN is not set, then Sentry is disabled.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    case Malan.Config.Sentry.enabled?() do
      nil -> Malan.Config.Sentry.dsn() |> Malan.Utils.not_nil_or_empty?()
      _ -> !!Malan.Config.Sentry.enabled?()
    end
  end

  @spec capture_exception(Exception.t(), Keyword.t()) :: Sentry.send_result()
  def capture_exception(exception, opts \\ []) do
    if enabled?() do
      Sentry.capture_exception(exception, opts)
    end
  end

  @spec capture_message(String.t(), Keyword.t()) :: Sentry.send_result()
  def capture_message(msg, opts) do
    if enabled?() do
      Sentry.capture_message(msg, opts)
    end
  end
end
