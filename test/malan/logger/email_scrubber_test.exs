defmodule Malan.Logger.EmailScrubberTest do
  use ExUnit.Case, async: true

  alias Malan.Logger.EmailScrubber

  @placeholder "[REDACTED_EMAIL]"

  describe "scrub/1" do
    test "redacts a plain email" do
      assert EmailScrubber.scrub("user foo@bar.com signed in") ==
               "user #{@placeholder} signed in"
    end

    test "redacts an email embedded in a URL path" do
      assert EmailScrubber.scrub("GET /api/users/foo@bar.com/reset_password") ==
               "GET /api/users/#{@placeholder}/reset_password"
    end

    test "redacts a URL-encoded email (%40)" do
      assert EmailScrubber.scrub("GET /api/users/foo%40bar.com/reset_password") ==
               "GET /api/users/#{@placeholder}/reset_password"
    end

    test "redacts multiple emails in one string" do
      input = "from a@b.co to c@d.net via e%40f.org"

      assert EmailScrubber.scrub(input) ==
               "from #{@placeholder} to #{@placeholder} via #{@placeholder}"
    end

    test "redacts emails with plus tags and dots in the local part" do
      assert EmailScrubber.scrub("contact first.last+tag@sub.example.co.uk now") ==
               "contact #{@placeholder} now"
    end

    test "leaves strings without emails untouched" do
      assert EmailScrubber.scrub("nothing to redact here") == "nothing to redact here"
      assert EmailScrubber.scrub("user @ home") == "user @ home"
      assert EmailScrubber.scrub("") == ""
    end

    test "is a no-op for non-binary input" do
      assert EmailScrubber.scrub(nil) == nil
      assert EmailScrubber.scrub(42) == 42
      assert EmailScrubber.scrub(%{a: 1}) == %{a: 1}
    end
  end

  describe "filter/2" do
    test "scrubs a {:string, binary} message" do
      event = %{level: :info, msg: {:string, "GET /api/users/foo@bar.com/x"}, meta: %{}}

      assert %{msg: {:string, "GET /api/users/" <> rest}} = EmailScrubber.filter(event, [])
      assert rest == "#{@placeholder}/x"
    end

    test "scrubs a {:string, charlist} message" do
      event = %{level: :info, msg: {:string, ~c"hi foo@bar.com"}, meta: %{}}

      assert %{msg: {:string, "hi " <> rest}} = EmailScrubber.filter(event, [])
      assert rest == @placeholder
    end

    test "scrubs binaries inside a {format, args} message" do
      event = %{level: :info, msg: {"user=~ts", ["foo@bar.com"]}, meta: %{}}

      assert %{msg: {"user=~ts", [redacted]}} = EmailScrubber.filter(event, [])
      assert redacted == @placeholder
    end

    test "scrubs binary values inside a {:report, map} message" do
      event = %{
        level: :info,
        msg: {:report, %{path: "/u/foo@bar.com", status: 200}},
        meta: %{}
      }

      assert %{msg: {:report, report}} = EmailScrubber.filter(event, [])
      assert report.path == "/u/#{@placeholder}"
      assert report.status == 200
    end

    test "scrubs binary values inside a {:report, keyword list} message" do
      event = %{
        level: :info,
        msg: {:report, [path: "/u/foo@bar.com", status: 200]},
        meta: %{}
      }

      assert %{msg: {:report, [path: path, status: 200]}} = EmailScrubber.filter(event, [])
      assert path == "/u/#{@placeholder}"
    end

    test "leaves messages without emails untouched" do
      event = %{level: :info, msg: {:string, "all clear"}, meta: %{}}
      assert EmailScrubber.filter(event, []) == event
    end

    test "passes through events without an :msg field" do
      event = %{level: :info, meta: %{}}
      assert EmailScrubber.filter(event, []) == event
    end
  end
end
