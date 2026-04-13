defmodule MalanWeb.UserSocketTest do
  use MalanWeb.ChannelCase, async: true

  alias MalanWeb.UserSocket
  alias Malan.Test.Helpers

  describe "connect/3" do
    test "accepts a valid token and assigns auth context" do
      {:ok, user, session} = Helpers.Accounts.regular_user_with_session()

      assert {:ok, socket} =
               connect(UserSocket, %{"token" => session.api_token}, connect_info: %{})

      assert socket.assigns.authed_user_id == user.id
      assert socket.assigns.authed_username == user.username
      assert socket.assigns.authed_session_id == session.id
      assert socket.assigns.authed_user_roles == ["user"]
    end

    test "rejects when the token param is missing" do
      assert :error = connect(UserSocket, %{}, connect_info: %{})
    end

    test "rejects an unknown token" do
      assert :error = connect(UserSocket, %{"token" => "not-a-real-token"}, connect_info: %{})
    end

    test "rejects an empty token" do
      assert :error = connect(UserSocket, %{"token" => ""}, connect_info: %{})
    end

    test "rejects a non-binary token" do
      assert :error = connect(UserSocket, %{"token" => 123}, connect_info: %{})
    end
  end

  describe "id/1" do
    test "returns a user-scoped id when authenticated" do
      socket = %Phoenix.Socket{assigns: %{authed_user_id: "user-abc"}}
      assert UserSocket.id(socket) == "user_socket:user-abc"
    end

    test "returns nil when no user is assigned" do
      assert UserSocket.id(%Phoenix.Socket{assigns: %{}}) == nil
    end
  end
end
