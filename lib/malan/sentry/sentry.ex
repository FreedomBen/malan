defmodule Malan.Sentry do
  # For Sentry fingerprinting
  #   https://docs.sentry.io/platforms/elixir/#fingerprinting
  def before_send(%{exception: [%{type: Phoenix.Router.NoRouteError}]} = event) do
    # %{event | fingerprint: ["ecto", "db_connection", "timeout"]}
    event
  end

  def before_send(event) do
    event
  end

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
