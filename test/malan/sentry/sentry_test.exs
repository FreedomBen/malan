defmodule Malan.SentryTest do
  use ExUnit.Case, async: true

  alias Malan.Sentry, as: MalanSentry
  alias Sentry.Interfaces.Breadcrumb
  alias Sentry.Interfaces.Request

  @placeholder "[REDACTED_EMAIL]"

  describe "before_send/1" do
    test "scrubs emails from request url and query string" do
      event = %{
        request: %Request{
          url: "https://example.com/api/users/foo@bar.com/reset_password",
          query_string: "redirect=https://x.test/u/foo%40bar.com"
        }
      }

      assert %{request: %Request{url: url, query_string: qs}} = MalanSentry.before_send(event)
      assert url == "https://example.com/api/users/#{@placeholder}/reset_password"
      assert qs == "redirect=https://x.test/u/#{@placeholder}"
    end

    test "scrubs emails from query_string when provided as a map" do
      event = %{
        request: %Request{
          url: "/foo",
          query_string: %{"who" => "foo@bar.com", "ok" => "1"}
        }
      }

      assert %{request: %Request{query_string: qs}} = MalanSentry.before_send(event)
      assert qs == %{"who" => @placeholder, "ok" => "1"}
    end

    test "scrubs emails from query_string when provided as a keyword-style list" do
      event = %{
        request: %Request{
          url: "/foo",
          query_string: [{"who", "foo@bar.com"}, {"ok", "1"}]
        }
      }

      assert %{request: %Request{query_string: qs}} = MalanSentry.before_send(event)
      assert qs == [{"who", @placeholder}, {"ok", "1"}]
    end

    test "scrubs emails from breadcrumb messages and data" do
      event = %{
        breadcrumbs: [
          %Breadcrumb{
            message: "looking up user foo@bar.com",
            data: %{"url" => "/api/users/foo@bar.com"}
          },
          %Breadcrumb{message: "no email here"}
        ]
      }

      assert %{breadcrumbs: [first, second]} = MalanSentry.before_send(event)
      assert first.message == "looking up user #{@placeholder}"
      assert first.data == %{"url" => "/api/users/#{@placeholder}"}
      assert second.message == "no email here"
    end

    test "scrubs the top-level event message" do
      event = %{message: "boom for foo@bar.com"}
      assert %{message: msg} = MalanSentry.before_send(event)
      assert msg == "boom for #{@placeholder}"
    end

    test "preserves the NoRouteError fingerprinting clause" do
      event = %{
        exception: [%{type: Phoenix.Router.NoRouteError}],
        request: %Request{url: "/missing/foo@bar.com"}
      }

      assert %{request: %Request{url: url}, exception: [%{type: type}]} =
               MalanSentry.before_send(event)

      assert url == "/missing/#{@placeholder}"
      assert type == Phoenix.Router.NoRouteError
    end

    test "is a no-op when there is nothing to scrub" do
      event = %{message: nil, request: nil, breadcrumbs: nil}
      assert MalanSentry.before_send(event) == event
    end
  end
end
