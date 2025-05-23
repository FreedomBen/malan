defmodule Malan.AccountsSyncTest do
  @moduledoc """
  Tests for Accounts functions that require synchronous execution
  due to global state dependencies (e.g., admin functions that list all sessions).
  """
  use Malan.DataCase, async: false

  alias Malan.Accounts
  alias Malan.Test.Utils, as: TestUtils
  alias Malan.Test.Helpers

  # Helper function to nil out api_token for comparison
  defp nillify_api_token(sessions) when is_list(sessions) do
    Enum.map(sessions, fn session -> %{session | api_token: nil} end)
  end

  describe "global session pagination" do
    test "list_sessions/2 returns all sessions paginated" do
      # Clear any existing sessions to ensure test isolation
      Malan.Repo.delete_all(Malan.Accounts.Session)
      
      {:ok, u1, s1} = Helpers.Accounts.regular_user_with_session()
      Process.sleep(1100)
      {:ok, s2} = Helpers.Accounts.create_session(u1)
      Process.sleep(1100)
      {:ok, s3} = Helpers.Accounts.create_session(u1)
      Process.sleep(1100)
      {:ok, s4} = Helpers.Accounts.create_session(u1)
      Process.sleep(1100)
      {:ok, s5} = Helpers.Accounts.create_session(u1)
      Process.sleep(1100)
      {:ok, s6} = Helpers.Accounts.create_session(u1)

      # With ORDER BY inserted_at DESC, newest sessions come first: [s6, s5, s4, s3, s2, s1]
      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(0, 10),
               nillify_api_token([s6, s5, s4, s3, s2, s1])
             )

      assert TestUtils.lists_equal_ignore_order(Accounts.list_sessions(1, 10), [])

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(0, 2),
               nillify_api_token([s6, s5])
             )

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(1, 2),
               nillify_api_token([s4, s3])
             )

      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(2, 2),
               nillify_api_token([s2, s1])
             )

      # Page 1 with size 4 should contain the remaining 2 sessions
      assert TestUtils.lists_equal_ignore_order(
               Accounts.list_sessions(1, 4),
               nillify_api_token([s2, s1])
             )
    end
  end
end