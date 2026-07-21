defmodule Malan.Test.Helpers.Accounts do
  import Ecto.Query, only: [from: 2]

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
    {:ok, user, _cs} =
      attrs
      |> Enum.into(admin_attrs())
      |> Accounts.register_user()

    make_user_admin(user)
  end

  @doc "Returns: {:ok, user}"
  def moderator_user(attrs \\ %{}) do
    {:ok, user, _cs} =
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
    case attrs |> Enum.into(regular_attrs()) |> Accounts.register_user() do
      {:ok, user, _cs} -> {:ok, user}
      {:error, _} = err -> err
    end
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

  @doc """
  Returns: {:ok, user, totp_secret, backup_codes}

  The user has a **confirmed** TOTP enrollment (email deliberately left
  unverified — enrollment does not require it); the raw `totp_secret` lets
  tests mint codes via `NimbleTOTP.verification_code/1`. The replay guard is rewound one step
  after confirmation (see `rewind_totp_last_used/2`) so the current step's
  code is immediately usable by the test.
  """
  def regular_user_with_totp(attrs \\ %{}) do
    {:ok, user} = regular_user(attrs)

    {:ok, %{secret_base32: secret_base32}} =
      Accounts.start_totp_enrollment(user, user.password, "192.168.2.200")

    secret = Base.decode32!(secret_base32, padding: false)

    {:ok, backup_codes} =
      Accounts.confirm_totp_enrollment(
        user,
        NimbleTOTP.verification_code(secret),
        "192.168.2.200",
        nil
      )

    rewind_totp_last_used(user)

    {:ok, user, secret, backup_codes}
  end

  @doc """
  Rewind the user's stored TOTP replay guard (`last_used_ts`) by `steps`
  periods, so a test can immediately accept a code for the current step
  instead of waiting out the 30s replay window.
  """
  def rewind_totp_last_used(user, steps \\ 1) do
    from(t in Malan.Accounts.UserTotp, where: t.user_id == ^user.id)
    |> Repo.update_all(inc: [last_used_ts: -30 * steps])
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
    {:ok, session} =
      session
      |> Session.admin_changeset(%{expires_at: expires_at})
      |> Repo.update()

    session
  end

  def set_revoked(session) do
    session
    |> set_revoked_at(Utils.DateTime.adjust_cur_time(-10, :seconds))
  end

  def set_revoked_at(session, revoked_at) do
    {:ok, session, _cs} = Accounts.revoke_session_at(session, revoked_at)
    session
  end

  def session_valid?(id) when is_binary(id) do
    Accounts.get_session!(id)
    |> session_valid?()
  end

  def session_valid?(session) do
    Accounts.session_valid_bool?(session.expires_at, session.revoked_at)
  end

  def session_revoked?(id) when is_binary(id) do
    Accounts.get_session!(id)
    |> Accounts.session_revoked?()
  end

  def session_expired?(id) when is_binary(id) do
    Accounts.get_session!(id)
    |> Accounts.session_expired?()
  end

  def session_revoked_or_expired?(session_id) when is_binary(session_id) do
    Accounts.get_session!(session_id)
    |> Accounts.session_revoked_or_expired?()
  end
end
