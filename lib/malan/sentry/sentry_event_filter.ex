defmodule Malan.SentryEventFilter do
  @behaviour Sentry.EventFilter

  # https://docs.sentry.io/platforms/elixir/#filtering-events

  # If the user passes invalid args that don't match handler, don't catch
  def exclude_exception?(%Phoenix.ActionClauseError{}, :plug) do
    # if return value will be 400, don't report error
    #   true
    # otherwise
    false
  end

  # If the user tries to hit a route that doesn't exist, don't catch
  #def exclude_exception?(%Phoenix.Router.NoRouteError{}, :plug), do: true
  def exclude_exception?(%Phoenix.Router.NoRouteError{}, :plug), do: false

  # Default handler, catch the exception
  def exclude_exception?(_exception, _source), do: false
end
