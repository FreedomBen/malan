defmodule Malan.Test.Helpers.Accounts do
  alias Malan.{Accounts, Repo, Utils}
  alias Malan.Accounts.{User, Session}

  def admin_attrs() do
    ui = System.unique_integer([:positive])

    %{
      email: "admin#{ui}@email.com",
      username: "adminuser#{ui}",
      first_name: "Admin",
      last_name: "Admin",
      nick_name: "addy"
    }
  end

  def moderator_attrs() do
    ui = System.unique_integer([:positive])

    %{
      email: "moderator#{ui}@email.com",
      username: "moderatoruser#{ui}",
      first_name: "Moderator",
      last_name: "User",
      nick_name: "moddy"
    }
  end

  def regular_attrs() do
    ui = System.unique_integer([:positive])

    %{
      email: "regular#{ui}@email.com",
      username: "regularuser#{ui}",
      first_name: "Regular",
      last_name: "User",
      nick_name: "reggy"
    }
  end

  @doc "Returns:  conn"
  def put_token(conn, api_token) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_token}")
  end

  @doc "Returns: {:ok, user}"
  def make_user_admin(user) do
    User.admin_changeset(user, %{roles: ["admin", "user"]})
    |> Repo.update()
  end

  @doc "Returns: {:ok, user}"
  def make_user_moderator(user) do
    User.admin_changeset(user, %{roles: ["moderator", "user"]})
    |> Repo.update()
  end

  @doc "Returns: {:ok, user}"
  def accept_user_tos_and_pp(user, accept) do
    User.update_changeset(user, %{accept_tos: accept, accept_privacy_policy: accept})
    |> Repo.update()
  end

  @doc "Returns: {:ok, user}"
  def accept_user_tos(user, accept) do
    User.update_changeset(user, %{accept_tos: accept})
    |> Repo.update()
  end

  @doc "Returns: {:ok, user}"
  def accept_user_pp(user, accept) do
    User.update_changeset(user, %{accept_privacy_policy: accept})
    |> Repo.update()
  end

  @doc "Returns: {:ok, user}"
  def lock_user(user, locked_by \\ nil) do
    Accounts.lock_user(user, locked_by)
  end

  @doc "Returns: {:ok, user}"
  def unlock_user(user) do
    Accounts.unlock_user(user)
  end

  @doc "Returns: {:ok, user}"
  def admin_user(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(admin_attrs())
      |> Accounts.register_user()

    make_user_admin(user)
  end

  @doc "Returns: {:ok, user}"
  def moderator_user(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(moderator_attrs())
      |> Accounts.register_user()

    make_user_moderator(user)
  end

  @doc "Returns: {:ok, session}"
  def create_session(user, session_attrs \\ %{}, remote_ip \\ "192.168.2.200") do
    Accounts.create_session(
      user.username,
      user.password,
      remote_ip,
      Map.merge(
        %{"ip_address" => remote_ip},
        session_attrs
      )
    )
  end

  @doc """
  Creates session and adds api_token to the conn

  Returns {:ok, conn, session}
  """
  def create_session_conn(conn, user, session_attrs \\ %{}) do
    with {:ok, session} <- create_session(user, session_attrs),
         {:ok, _user} <- accept_user_tos_and_pp(user, true),
         conn <- put_token(conn, session.api_token),
         do: {:ok, conn, session}
  end

  @doc "Returns: {:ok, user, session}"
  def admin_user_with_session(user_attrs \\ %{}, session_attrs \\ %{}) do
    with {:ok, user} <- admin_user(user_attrs),
         {:ok, session} <- create_session(user, session_attrs) do
      {:ok, user, session}
    else
      {:error, %Ecto.Changeset{errors: errors}} -> {:error, errors}
      _ -> {:error, "error making thing"}
    end
  end

  @doc "Returns: {:ok, user}"
  def regular_user(attrs \\ %{}) do
    attrs
    |> Enum.into(regular_attrs())
    |> Accounts.register_user()
  end

  @doc "Returns: {:ok, user, session}"
  def regular_user_with_session(user_attrs \\ %{}, session_attrs \\ %{}) do
    with {:ok, user} <- regular_user(user_attrs),
         {:ok, session} <- create_session(user, session_attrs) do
      {:ok, user, session}
    else
      {:error, %Ecto.Changeset{errors: errors}} -> {:error, errors}
      _ -> {:error, "error making thing"}
    end
  end

  @doc "Returns: {:ok, user, session}"
  def moderator_user_with_session(user_attrs \\ %{}, session_attrs \\ %{}) do
    with {:ok, user} <- moderator_user(user_attrs),
         {:ok, session} <- create_session(user, session_attrs) do
      {:ok, user, session}
    else
      {:error, %Ecto.Changeset{errors: errors}} -> {:error, errors}
      _ -> {:error, "error making thing"}
    end
  end

  @doc "Returns: {:ok, conn, user, session}"
  def regular_user_session_conn(conn, user_attrs \\ %{}, session_attrs \\ %{}) do
    with {:ok, user, session} <- regular_user_with_session(user_attrs, session_attrs),
         {:ok, user} <- accept_user_tos_and_pp(user, true),
         conn <- put_token(conn, session.api_token),
         do: {:ok, conn, user, session}
  end

  @doc "Returns: {:ok, conn, user, session}"
  def moderator_user_session_conn(conn, user_attrs \\ %{}, session_attrs \\ %{}) do
    with {:ok, user, session} <- moderator_user_with_session(user_attrs, session_attrs),
         {:ok, user} <- accept_user_tos_and_pp(user, true),
         conn <- put_token(conn, session.api_token),
         do: {:ok, conn, user, session}
  end

  @doc "Returns: {:ok, conn, user, session}"
  def admin_user_session_conn(conn, user_attrs \\ %{}, session_attrs \\ %{}) do
    with {:ok, user, session} <- admin_user_with_session(user_attrs, session_attrs),
         {:ok, user} <- accept_user_tos_and_pp(user, true),
         conn <- put_token(conn, session.api_token),
         do: {:ok, conn, user, session}
  end

  # This function can be used to get the specified number of users
  #
  # Example: regular_users_with_session(2)
  #
  #   Returns: [{:ok, user1, session1}, {:ok, user2, session2}]
  #
  def regular_users_with_session(num_users) do
    Enum.map(1..num_users, fn i ->
      regular_user_with_session(%{email: "admin#{i}@email.com", username: "adminuser#{i}"})
    end)
  end

  # This function can be used to get the specified number of users
  # with their session tokens added to the conn that is returned
  # with them
  #
  # Example: regular_users_session_conn(conn, 2)
  #
  #   Returns: [{:ok, conn, user1, session1}, {:ok, conn, user2, session2}]
  #
  def regular_users_session_conn(conn, num_users) do
    Enum.map(1..num_users, fn i ->
      regular_user_session_conn(conn, %{email: "admin#{i}@email.com", username: "adminuser#{i}"})
    end)
  end

  # This function can be used to get the specified number of users
  #
  # Example: admin_users_with_session(2)
  #
  #   Returns: [{:ok, user1, session1}, {:ok, user2, session2}]
  #
  def admin_users_with_session(num_users) do
    Enum.map(1..num_users, fn i ->
      admin_user_with_session(%{email: "admin#{i}@email.com", username: "adminuser#{i}"})
    end)
  end

  #
  # This function can be used to get the specified number of users
  # with their session tokens added to the conn that is returned
  # with them
  #
  # Example: admin_users_session_conn(conn, 2)
  #
  #   Returns: [{:ok, conn, user1, session1}, {:ok, conn, user2, session2}]
  #
  def admin_users_session_conn(conn, num_users) do
    Enum.map(1..num_users, fn i ->
      admin_user_session_conn(conn, %{email: "admin#{i}@email.com", username: "adminuser#{i}"})
    end)
  end

  def set_expired(session) do
    session
    |> set_expires_at(Utils.DateTime.adjust_cur_time(-10, :seconds))
  end

  def set_expires_at(session, expires_at) do
    {:ok, session} = session
    |> Session.admin_changeset(%{expires_at: expires_at})
    |> Repo.update()

    session
  end

  def set_revoked(session) do
    session
    |> set_revoked_at(Utils.DateTime.adjust_cur_time(-10, :seconds))
  end

  def set_revoked_at(session, revoked_at) do
    {:ok, session} = Accounts.revoke_session(session)
    session
  end
end
