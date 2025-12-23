defmodule Malan.AccountsSyncTest do
  @moduledoc """
  Tests for Accounts functions that require synchronous execution
  due to global state dependencies (e.g., admin functions that list all sessions).
  """
  use Malan.DataCase, async: false

  alias Malan.Accounts
  alias Malan.Test.Helpers

  describe "global session pagination" do
    test "list_sessions/2 returns all sessions paginated" do
      # Clear any existing sessions to ensure test isolation
      Malan.Repo.delete_all(Malan.Accounts.Session)

      {:ok, u1, _s1} = Helpers.Accounts.regular_user_with_session()
      Process.sleep(1100)
      {:ok, _s2} = Helpers.Accounts.create_session(u1)
      Process.sleep(1100)
      {:ok, _s3} = Helpers.Accounts.create_session(u1)
      Process.sleep(1100)
      {:ok, _s4} = Helpers.Accounts.create_session(u1)
      Process.sleep(1100)
      {:ok, _s5} = Helpers.Accounts.create_session(u1)
      Process.sleep(1100)
      {:ok, _s6} = Helpers.Accounts.create_session(u1)

      # Test that all 6 sessions are returned and properly ordered
      all_sessions = Accounts.list_sessions(0, 10)
      assert length(all_sessions) == 6

      # Verify sessions are ordered by inserted_at DESC (newest first)
      timestamps = Enum.map(all_sessions, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})

      # Test that second page is empty
      assert Accounts.list_sessions(1, 10) == []

      # Test pagination with smaller page sizes
      page1 = Accounts.list_sessions(0, 2)
      page2 = Accounts.list_sessions(1, 2)
      page3 = Accounts.list_sessions(2, 2)

      # Each page should have exactly 2 sessions
      assert length(page1) == 2
      assert length(page2) == 2
      assert length(page3) == 2

      # All sessions should be unique across pages
      all_page_ids = Enum.map(page1 ++ page2 ++ page3, & &1.id)
      assert length(all_page_ids) == length(Enum.uniq(all_page_ids))

      # First page should have the newest sessions
      assert Enum.at(page1, 0).inserted_at >= Enum.at(page1, 1).inserted_at
      assert Enum.at(page1, 1).inserted_at >= Enum.at(page2, 0).inserted_at

      # Test larger page size pagination
      page1_large = Accounts.list_sessions(0, 4)
      page2_large = Accounts.list_sessions(1, 4)

      assert length(page1_large) == 4
      assert length(page2_large) == 2
    end
  end
end
