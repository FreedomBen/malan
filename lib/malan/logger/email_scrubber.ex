defmodule Malan.Logger.EmailScrubber do
  @moduledoc """
  `:logger` filter that redacts email-like substrings from log messages.

  Email addresses can appear in request paths (e.g.
  `/api/users/foo@bar.com/reset_password`, since the `:id` path parameter is
  resolved through `Accounts.get_user_by_id_or_username/1` and usernames may be
  email addresses). Phoenix's request logger and any caller that builds a
  message containing the request URL would otherwise emit those substrings
  verbatim. This filter rewrites them in place to `#{inspect("[REDACTED_EMAIL]")}`.

  Installed as a primary filter from `Malan.Application.start/2`, so it applies
  to every handler (console, `Sentry.LoggerBackend`, etc.). The same `scrub/1`
  helper is also called from `Malan.Sentry.before_send/1` to cover Sentry
  events that bypass the Logger.

  This is a defense-in-depth measure; the long-term fix is to stop accepting
  emails as path segments.
  """

  @placeholder "[REDACTED_EMAIL]"

  # Local-part:  letters, digits, and `._%+-`.
  # Domain:      letters, digits, dots, hyphens, with a 2+ char alpha TLD.
  # Conservative on purpose — we'd rather miss an exotic address than redact
  # a non-email substring that happens to contain `@`.
  @email_regex ~r/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/

  # URL-encoded form (`%40` instead of `@`). Phoenix typically logs the
  # decoded path, but the encoded form may show up in query strings or in
  # callers that log the raw request URI.
  @encoded_email_regex ~r/[A-Za-z0-9._+\-]+%40[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/

  @doc """
  `:logger` filter callback. Returns the event with email substrings redacted
  from `:msg`. Never drops events.
  """
  @spec filter(:logger.log_event(), :logger.filter_arg()) :: :logger.filter_return()
  def filter(%{msg: msg} = event, _opts) do
    %{event | msg: scrub_msg(msg)}
  end

  def filter(event, _opts), do: event

  @doc """
  Replace any email-like substrings in `str` with `#{inspect("[REDACTED_EMAIL]")}`.
  Handles both `foo@bar.com` and `foo%40bar.com`.
  """
  @spec scrub(binary()) :: binary()
  @spec scrub(any()) :: any()
  def scrub(str) when is_binary(str) do
    str
    |> String.replace(@email_regex, @placeholder)
    |> String.replace(@encoded_email_regex, @placeholder)
  end

  def scrub(other), do: other

  defp scrub_msg({:string, str}) when is_binary(str), do: {:string, scrub(str)}

  defp scrub_msg({:string, str}) when is_list(str) do
    case :unicode.characters_to_binary(str) do
      bin when is_binary(bin) -> {:string, scrub(bin)}
      _ -> {:string, str}
    end
  end

  defp scrub_msg({:report, %{} = report}) do
    {:report, Map.new(report, fn {k, v} -> {k, scrub_value(v)} end)}
  end

  defp scrub_msg({:report, list}) when is_list(list) do
    {:report,
     Enum.map(list, fn
       {k, v} -> {k, scrub_value(v)}
       other -> scrub_value(other)
     end)}
  end

  defp scrub_msg({format, args}) when is_list(args) do
    {format, Enum.map(args, &scrub_value/1)}
  end

  defp scrub_msg(other), do: other

  defp scrub_value(v) when is_binary(v), do: scrub(v)

  defp scrub_value(v) when is_list(v) do
    case :unicode.characters_to_binary(v) do
      bin when is_binary(bin) -> scrub(bin)
      _ -> v
    end
  rescue
    _ -> v
  end

  defp scrub_value(v), do: v
end
