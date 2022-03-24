defmodule Malan.SentryEventFilter do
  @behaviour Sentry.EventFilter

  # https://docs.sentry.io/platforms/elixir/#filtering-events
  def exclude_exception?(%Phoenix.ActionClauseError{}, :plug) do
    # if return value will be 400, don't report error
    #   true
    # otherwise
    false
  end

  def exclude_exception?(_exception, _source), do: false
end
