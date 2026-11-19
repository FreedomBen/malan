defmodule Malan.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Malan.Logger.EmailScrubber

  @impl true
  def start(_type, _args) do
    install_sentry_logger_handler()
    install_email_scrubber()
    attach_oban_logger()

    children = [
      # Start the Ecto repository
      Malan.Repo,
      # Start the Telemetry supervisor
      MalanWeb.Telemetry,
      # Start PromEx for Prometheus metrics (separate port, cluster-internal)
      Malan.PromEx,
      # Start Oban for background job processing (audit log writes)
      {Oban, Application.fetch_env!(:malan, Oban)},
      # Start rate limiter backend
      {Malan.RateLimiter, Application.get_env(:malan, Malan.RateLimiter, [])},
      # Start the PubSub system
      {Phoenix.PubSub, name: Malan.PubSub},
      # Start the Endpoint (http/https)
      MalanWeb.Endpoint
      # Start a worker by calling: Malan.Worker.start_link(arg)
      # {Malan.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Malan.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MalanWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Attach the Sentry :logger handler so process crashes are reported as
  # Sentry events (defaults: capture_level :error, plain log messages not
  # captured) — the modern replacement for the removed Sentry.LoggerBackend
  # setup. Idempotent: a repeat attach returns `{:error, {:already_exist, _}}`,
  # which we treat as success.
  defp install_sentry_logger_handler do
    case :logger.add_handler(:sentry_handler, Sentry.LoggerHandler, %{}) do
      :ok -> :ok
      {:error, {:already_exist, _}} -> :ok
    end
  end

  # Install the email-redaction filter on the primary :logger so it applies
  # to every handler (console, Sentry.LoggerHandler, etc). Idempotent: a
  # repeat install (e.g. during a release reload) returns `{:error, :already_exists}`,
  # which we treat as success.
  defp install_email_scrubber do
    case :logger.add_primary_filter(
           :malan_email_scrubber,
           {&EmailScrubber.filter/2, []}
         ) do
      :ok -> :ok
      {:error, {:already_exist, _}} -> :ok
    end
  end

  # Attach Oban's default structured (JSON) logger so background job
  # successes (`job:stop`) and failures (`job:exception`) are written to the
  # log. Idempotent: a repeat attach (e.g. release reload) returns
  # `{:error, :already_exists}`, which we treat as success.
  #
  # Emitted at :debug deliberately. Every audit-logged request produces a
  # job, and at :info each job adds 2+ structured log lines that pass
  # through the EmailScrubber regexes and the Sentry logger handler —
  # log-volume amplification with no signal. Prod (LOG_LEVEL=info)
  # suppresses them; dev (debug) keeps them. Failures still surface via
  # Sentry's oban integration (capture_errors: true), LogWriter's warning
  # on final attempt, and PromEx's Oban metrics. Do not raise this to
  # :warning — that would push every successful job through those log
  # paths for no added signal.
  defp attach_oban_logger do
    case Oban.Telemetry.attach_default_logger(level: :debug) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end
end
