defmodule Malan.Accounts do
  @moduledoc """
  The Accounts context.
  """

  require Logger

  import Ecto.Query, warn: false
  import Malan.Pagination, only: [valid_page: 2]

  alias Malan.Repo

  alias Malan.Accounts.User
  alias Malan.Utils

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users(page_num, page_size) when valid_page(page_num, page_size) do
    from(
      u in User,
      select: u,
      limit: ^page_size,
      offset: ^(page_num * page_size)
    )
    |> Repo.all()
  end

  def get_user(id) do
    Repo.one(from(u in User, where: u.id == ^id and is_nil(u.deleted_at)))
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id) do
    query = from(u in User, where: u.id == ^id and is_nil(u.deleted_at))
    user = Repo.one(query)

    if is_nil(user) do
      raise Ecto.NoResultsError, queryable: query
    else
      user
    end
  end

  @doc """
  Gets a single user with their associations (like phone numbers and addresses)

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user_full(123)
      %User{}

      iex> get_user_full(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_full(id) do
    # Repo.one(from(u in User, where: u.id == ^id and is_nil(u.deleted_at), preload: [:phone_numbers, :addresses]))

    # Pipe version
    User
    |> where([u], u.id == ^id)
    |> where([u], is_nil(u.deleted_at))
    |> preload([:phone_numbers, :addresses])
    |> Repo.one()
  end

  @doc """
  Gets a single user with their associations (like phone numbers and addresses)

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user_full!(123)
      %User{}

      iex> get_user_full!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_full!(id) do
    # query = from(u in User, where: u.id == ^id and is_nil(u.deleted_at), preload: [:phone_numbers, :addresses])

    # Pipe version
    query =
      User
      |> where([u], u.id == ^id)
      |> where([u], is_nil(u.deleted_at))
      |> preload([:phone_numbers, :addresses])

    user = Repo.one(query)

    if is_nil(user) do
      raise Ecto.NoResultsError, queryable: query
    else
      user
    end
  end

  defp get_user_by_id_or_username_query(id_or_username) do
    cond do
      Utils.is_uuid?(id_or_username) ->
        from(u in User,
          where:
            (u.id == ^id_or_username or u.username == ^id_or_username) and is_nil(u.deleted_at)
        )

      true ->
        from(u in User, where: u.username == ^id_or_username and is_nil(u.deleted_at))
    end
  end

  def get_user_by_id_or_username(id_or_username) do
    query = get_user_by_id_or_username_query(id_or_username)
    Repo.one(query)
  end

  def get_user_by_id_or_username!(id_or_username) do
    query = get_user_by_id_or_username_query(id_or_username)
    user = Repo.one(query)

    if is_nil(user) do
      raise Ecto.NoResultsError, queryable: query
    else
      user
    end
  end

  defp get_user_full_by_id_or_username_query(:id, id) do
    User
    |> where([u], u.id == ^id or u.username == ^id)
    |> where([u], is_nil(u.deleted_at))
    |> preload([:phone_numbers, :addresses])
  end

  defp get_user_full_by_id_or_username_query(:username, username) do
    User
    |> where([u], u.username == ^username)
    |> where([u], is_nil(u.deleted_at))
    |> preload([:phone_numbers, :addresses])
  end

  defp get_user_full_by_id_or_username_query(id_or_username) do
    cond do
      Utils.is_uuid?(id_or_username) ->
        get_user_full_by_id_or_username_query(:id, id_or_username)

      true ->
        get_user_full_by_id_or_username_query(:username, id_or_username)
    end
  end

  @doc ~S"""
  Retrieve the user matching the specified argument which can be either id or username.

  Returns %User{} if found, or nil if not found

  ## Examples

      iex>  Accounts.get_user_full_by_id_or_username("username")
      %User{}
  """
  def get_user_full_by_id_or_username(id_or_username) do
    get_user_full_by_id_or_username_query(id_or_username)
    |> Repo.one()
  end

  @doc ~S"""
  Retrieve the user matching the specified argument which can be either id or username.

  Returns %User{} if found, raises Ecto.NoResultsError if not found

  ## Examples

      iex>  Accounts.get_user_full_by_id_or_username!("username")
      %User{}
  """
  def get_user_full_by_id_or_username!(id_or_username) do
    query = get_user_full_by_id_or_username_query(id_or_username)
    user = Repo.one(query)

    if is_nil(user) do
      raise Ecto.NoResultsError, queryable: query
    else
      user
    end
  end

  @doc ~S"""
  Returns nil if no matching user is found.
  Raises Ecto.MultipleResultsError if more than one is found:  https://hexdocs.pm/ecto/Ecto.MultipleResultsError.html

      iex> Accounts.get_user_by(title: "My post")

  """
  def get_user_by(params) do
    # TODO: Don't return users where deleted_at is not nil
    Repo.get_by(User, params)
  end

  @doc ~S"""
  Raises Ecto.NoResultsError if no matching user is found.  https://hexdocs.pm/ecto/Ecto.NoResultsError.html
  Raises Ecto.MultipleResultsError if more than one is found:  https://hexdocs.pm/ecto/Ecto.MultipleResultsError.html

      iex> Accounts.get_user_by!(title: "My post")

  """
  def get_user_by!(params) do
    # TODO: Don't return users where deleted_at is not nil
    Repo.get_by!(User, params)
  end

  def get_user_by_password_reset_token(token) do
    get_user_by(password_reset_token_hash: Utils.Crypto.hash_token(token))
  end

  # def get_user_by(username: username) do
  #   TODO: Don't return users where deleted_at is not nil
  #   Repo.one(
  #     from u in User,
  #     where: u.username == ^username
  #   )
  # end

  @doc """
  Creates a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  # @doc """
  # Updates a user.

  ### Examples

  #    iex> update_user(user, %{field: new_value})
  #    {:ok, %User{}}

  #    iex> update_user(user, %{field: bad_value})
  #    {:error, %Ecto.Changeset{}}

  # """
  # def update_user(%User{password: nil} = user, attrs) do
  #   update_usr(user, attrs)
  # end
  # do: update_usr(user, attrs)

  @doc """
  Updates a user's password.  If password is being changed, all non-permanent
  session tokens are revoked immediately

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, %{"password" => _password} = attrs) do
    with {:ok, user} <- update_usr(user, attrs),
         {:ok, _num_revoked} <- revoke_active_sessions(user),
         do: {:ok, user}
  end

  def update_user(%User{} = user, attrs),
    do: update_usr(user, attrs)

  def update_user_password(%User{} = user, password),
    do: update_user(user, %{"password" => password})

  def update_user_password(user_id, password) do
    get_user(user_id)
    |> update_user_password(password)
  end

  @doc """
  Checks if the provided password reset token in valid.  If it is, returns {:ok}.

  If not returns {:error, :missing_password_reset_token} if the user does not have a valid reset token issued or {:error, :invalid_password_reset_token} if the password reset token is incorrect.

  Returns {:error, :expired_password_reset_token} if token is expired
  """
  def validate_password_reset_token(user, password_reset_token) do
    cond do
      Utils.nil_or_empty?(user.password_reset_token_hash) ->
        {:error, :missing_password_reset_token}

      Utils.DateTime.expired?(user.password_reset_token_expires_at) ->
        {:error, :expired_password_reset_token}

      user.password_reset_token_hash == Utils.Crypto.hash_token(password_reset_token) ->
        {:ok}

      true ->
        {:error, :invalid_password_reset_token}
    end
  end

  @doc """
  Clears password reset token for user.

  Returns {:ok, %User{}} on success
  """
  def clear_password_reset_token(%User{} = user) do
    user
    |> User.password_reset_clear_changeset()
    |> Repo.update()
  end

  def clear_password_reset_token(user_id) do
    get_user(user_id)
    |> clear_password_reset_token()
  end

  @doc """
    Returns:

      {:ok, %User{}}
      {:error, :missing_password_reset_token}
      {:error, :invalid_password_reset_token}
  """
  def reset_password_with_token(%User{} = orig_user, token, new_password) do
    with {:ok} <- validate_password_reset_token(orig_user, token),
         {:ok, %User{}} <- clear_password_reset_token(orig_user),
         {:ok, %User{} = user} <- update_user_password(orig_user, new_password) do
      {:ok, user}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def reset_password_with_token(id, token, new_password),
    do: reset_password_with_token(get_user(id), token, new_password)

  # "private utility for the update_user funcs.  Use a public update_user()"
  defp update_usr(user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Generates a password reset token that can then be used to reset the user's password.

  Returns {:ok, %User{}} on success
  """
  def generate_password_reset(%User{} = user) do
    user
    |> User.password_reset_create_changeset()
    |> Repo.update()
  end

  @doc ""
  def admin_update_user(user, attrs) do
    user
    |> User.admin_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    # Repo.delete(user)
    user
    |> User.delete_changeset()
    |> Repo.update()
  end

  def lock_user(%User{} = user, locked_by_id) do
    with cs <- User.lock_changeset(user, locked_by_id),
         {:ok, user} <- Repo.update(cs),
         {:ok, _num_revoked} <- revoke_active_sessions(user) do
      {:ok, user}
    else
      {:error, changeset} -> {:error, changeset}
      err -> {:error, err}
    end
  end

  def unlock_user(%User{} = user) do
    user
    |> User.unlock_changeset()
    |> Repo.update()
  end

  alias Malan.Accounts.Session

  @doc """
  Returns the list of sessions.  Can pass a user_id as first arg to get all session for user

  ## Examples

      iex> list_sessions(user)
      [%Session{}, ...]
      iex> list_sessions(user_id)
      [%Session{}, ...]
      iex> list_sessions()
      [%Session{}, ...]

  """
  def list_sessions(%User{id: user_id}, page_num, page_size) do
    list_sessions(user_id, page_num, page_size)
  end

  def list_sessions(user_id, page_num, page_size) do
    Repo.all(
      from s in Session,
        select: s,
        where: s.user_id == ^user_id,
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  def list_sessions(page_num, page_size) do
    Repo.all(
      from s in Session,
        select: s,
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  def list_active_sessions(%User{id: id}, page_num, page_size),
    do: list_active_sessions(id, page_num, page_size)

  def list_active_sessions(user_id, page_num, page_size) do
    Repo.all(
      from s in Session,
        where: s.user_id == ^user_id,
        where: is_nil(s.revoked_at) or s.expires_at < ^DateTime.utc_now(),
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  @doc """
  Returns the list of all user sessions.  Requires being an admin.

  ## Examples

      iex> list_user_sessions()
      [%Session{}, ...]

  """
  def list_user_sessions(user_id, page_num, page_size) do
    list_sessions(user_id, page_num, page_size)
  end

  @doc """
  Gets a single session.

  Raises `Ecto.NoResultsError` if the Session does not exist.

  ## Examples

      iex> get_session!(123)
      %Session{}

      iex> get_session!(456)
      ** (Ecto.NoResultsError)

  """
  def get_session!(id), do: Repo.get!(Session, id)

  @doc """
  Looks up user_id and password_hash in the DB based on given username

  Returns [user_id, password_hash] if username is found, otherwise nil.

  username has unique index on it so should never have more than one result

  Returns {user_id, password_hash, locked_at}
  """
  def get_user_id_pass_hash_by_username(username) do
    Repo.one(
      from u in User,
        select: {u.id, u.password_hash, u.locked_at, u.approved_ips},
        where: u.username == ^username,
        where: is_nil(u.deleted_at)
    )
  end

  @doc """
  Checks that the given_pass is correct for user with id user_id.

  Returns {:ok, user_id} if given_pass is correct.  Otherwise {:error, :unauthorized}
  """
  def verify_pass(user_id, given_pass, password_hash, [] = _approved_ips, _remote_ip) do
    verify_pass(user_id, given_pass, password_hash)
  end

  def verify_pass(user_id, given_pass, password_hash, approved_ips, remote_ip) do
    cond do
      remote_ip in approved_ips -> verify_pass(user_id, given_pass, password_hash)
      true -> {:error, :ip_addr}
    end
  end

  def verify_pass(user_id, given_pass, password_hash) do
    cond do
      Utils.Crypto.verify_password(given_pass, password_hash) -> {:ok, user_id}
      true -> {:error, :unauthorized}
    end
  end

  @doc """
  Verify password for a locked user.

  If password is correct, returns {:error, :user_locked}
  If password in incorrect, returns {:error, :unauthorized}
  """
  def verify_pass_locked(user_id, given_pass, password_hash, _locked_at) do
    case verify_pass(user_id, given_pass, password_hash) do
      {:ok, _user_id} -> {:error, :user_locked}
      {:error, :unauthorized} -> {:error, :unauthorized}
    end
  end

  @doc "Pretend to be checking the password so timing attacks don't work"
  def fake_pass_verify(error) do
    Utils.Crypto.fake_verify_password()
    {:error, error}
  end

  @doc """
  Checks that the given_pass is correct for username.

  Returns {:ok, user_id} if given_pass is correct, or
          {:error, :user_locked}
          {:error, :unauthorized}
          {:error, :not_a_user}
  """
  def authenticate_by_username_pass(username, given_pass, remote_ip) do
    case get_user_id_pass_hash_by_username(username) do
      {user_id, password_hash, nil, approved_ips} ->
        verify_pass(user_id, given_pass, password_hash, approved_ips, remote_ip)

      {user_id, password_hash, locked_at, _} ->
        verify_pass_locked(user_id, given_pass, password_hash, locked_at)

      nil ->
        fake_pass_verify(:not_a_user)
    end
  end

  @doc """
  Retrieves user roles from the DB for user_id.

  Returns list of roles:  e.g. ["admin", "moderator"]
  """
  def get_user_roles(user_id) do
    Repo.one(
      from u in User,
        select: [u.roles],
        where: u.id == ^user_id
    )
    |> List.first()
  end

  @doc """
  Retrieves user roles from the DB and extracts into a tuple of:

  {:ok, ["admin", "moderator"]
  """
  def list_user_roles(user_id), do: {:ok, get_user_roles(user_id)}

  def user_has_role?(roles, role) when is_list(roles) do
    {:ok, role, Enum.member?(roles, role)}
  end

  def user_has_role?(user_id, role) do
    user_has_role?(get_user_roles(user_id), role)
  end

  def user_is_admin?(roles) when is_list(roles) do
    {:ok, "admin", admin} = user_has_role?(roles, "admin")
    {:ok, admin}
  end

  def user_is_admin?(user_id) do
    {:ok, "admin", admin} = user_has_role?(user_id, "admin")
    {:ok, admin}
  end

  def user_is_moderator?(roles) when is_list(roles) do
    {:ok, "moderator", moderator} = user_has_role?(roles, "moderator")
    {:ok, moderator}
  end

  def user_is_moderator?(user_id) do
    {:ok, "moderator", moderator} = user_has_role?(user_id, "moderator")
    {:ok, moderator}
  end

  def user_add_role(role, user_id) do
    user = get_user!(user_id)

    cond do
      Enum.member?(user.roles, role) ->
        {:ok, user}

      true ->
        user
        |> User.admin_changeset(%{roles: user.roles ++ [role]})
        |> Repo.update()
    end
  end

  def user_tos(accept_tos, user_id) do
    # TODO don't retrieve the entire user.
    # Just generate update sql that replaces only the part we want to replace
    get_user!(user_id)
    |> update_user(%{accept_tos: accept_tos})
  end

  @doc "Accepts the Terms of Service for the user.  Returns {:ok, user}"
  def user_accept_tos(user_id), do: user_tos(true, user_id)

  @doc "Rejects the Terms of Service for the user.  Returns {:ok, user}"
  def user_reject_tos(user_id), do: user_tos(false, user_id)

  def user_set_privacy_policy(accept_privacy_policy, user_id) do
    # TODO don't retrieve the entire user.
    # Just generate update sql that replaces only the part we want to replace
    get_user!(user_id)
    |> update_user(%{accept_privacy_policy: accept_privacy_policy})
  end

  def user_accept_privacy_policy(user_id),
    do: user_set_privacy_policy(true, user_id)

  def user_reject_privacy_policy(user_id),
    do: user_set_privacy_policy(false, user_id)

  def new_session(attrs) do
    %Session{}
    |> Session.create_changeset(attrs)
    |> Repo.insert()
  end

  def new_session(user_id, attrs) do
    attrs
    |> Map.put("user_id", user_id)
    |> new_session()
  end

  defp username_to_id(username) do
    case Utils.is_uuid_or_nil?(username) do
      true -> username
      _ -> Repo.one(from u in User, select: u.id, where: u.username == ^username)
    end
  end

  @doc """
  Create a new session for specified `username` if `pass` is correct.

  `ip_addr` will be recorded in the DB

  Returns {:ok, %Session{}} on success
      If user account is loked, you'll get back {:error, :user_locked}
      If unauthorized you'll get back {:error, :unauthorized}
      If user is not found, you'll get back {:error, :not_found}
  """
  def create_session(username, pass, remote_ip, attrs) do
    case authenticate_by_username_pass(username, pass, remote_ip) do
      {:ok, user_id} -> new_session(user_id, attrs)
      {:error, :user_locked} -> record_create_session_locked(username, remote_ip, attrs)
      {:error, :ip_addr} -> record_create_session_bad_ip(username, remote_ip, attrs)
      {:error, :unauthorized} -> record_create_session_unauthorized(username, remote_ip, attrs)
      {:error, :not_a_user} -> record_create_session_not_a_user(username, remote_ip, attrs)
    end
  end

  @doc """
  Record failed session creation attempt as unauthorized.

  Returns {:error, :unauthorized}
  """
  def record_create_session_locked(username_or_id, remote_ip, attrs, username \\ nil) do
    case Utils.is_uuid_or_nil?(username_or_id) do
      true ->
        record_transaction(
          false,
          username_or_id,
          nil,
          username_or_id,
          username,
          "sessions",
          "POST",
          Utils.trunc_str(
            "#Accounts.record_create_session_locked/3 - Unauthorized login attempt for user '#{username_or_id}' failed from IP '#{remote_ip}' because user account is locked:  #{Utils.map_to_string(attrs, [:password])}"
          ),
          %{}
        )

      # recursive
      _ ->
        record_create_session_locked(
          username_to_id(username_or_id),
          remote_ip,
          attrs,
          username_or_id
        )
    end

    {:error, :user_locked}
  end

  @doc """
  Record failed session creation attempt as unauthorized.

  Returns {:error, :unauthorized}
  """
  def record_create_session_bad_ip(username_or_id, remote_ip, attrs, username \\ nil) do
    case Utils.is_uuid_or_nil?(username_or_id) do
      true ->
        record_transaction(
          false,
          username_or_id,
          nil,
          username_or_id,
          username,
          "sessions",
          "POST",
          Utils.trunc_str(
            "#Accounts.record_create_session_bad_ip/3 - Unauthorized login attempt for user '#{username_or_id}' failed from IP '#{remote_ip}' because IP is not on user's approved list:  #{Utils.map_to_string(attrs, [:password])}"
          ),
          %{}
        )

      # recursive
      _ ->
        record_create_session_bad_ip(
          username_to_id(username_or_id),
          remote_ip,
          attrs,
          username_or_id
        )
    end

    {:error, :unauthorized}
  end

  @doc """
  Record failed session creation attempt as unauthorized.

  Returns {:error, :unauthorized}
  """
  def record_create_session_unauthorized(username_or_id, remote_ip, attrs, username \\ nil) do
    case Utils.is_uuid_or_nil?(username_or_id) do
      true ->
        record_transaction(
          false,
          username_or_id,
          nil,
          username_or_id,
          username,
          "sessions",
          "POST",
          Utils.trunc_str(
            "#Accounts.record_create_session_unauthorized/3 - Unauthorized login attempt for user '#{username_or_id}' failed from IP '#{remote_ip}':  #{Utils.map_to_string(attrs, [:password])}"
          ),
          %{}
        )

      # recursive
      _ ->
        record_create_session_unauthorized(
          username_to_id(username_or_id),
          remote_ip,
          attrs,
          username_or_id
        )
    end

    {:error, :unauthorized}
  end

  @doc """
  Record failed session creation attempt as unauthorized.

  Returns {:error, :not_a_user}
  """
  def record_create_session_not_a_user(username_or_id, remote_ip, attrs, username \\ nil) do
    case Utils.is_uuid_or_nil?(username_or_id) do
      true ->
        record_transaction(
          false,
          username_or_id,
          nil,
          username_or_id,
          username,
          "sessions",
          "POST",
          Utils.trunc_str(
            "#Accounts.record_create_session_not_a_user/3 - Unauthorized login attempt for user with ID or username of '#{username_or_id}' (that user does not exist) from IP '#{remote_ip}':  #{Utils.map_to_string(attrs, [:password])}"
          ),
          %{}
        )

      # recursive
      _ ->
        record_create_session_not_a_user(
          username_to_id(username_or_id),
          remote_ip,
          attrs,
          username_or_id
        )
    end

    {:error, :not_a_user}
  end

  @doc """
  Deletes a session.

  ## Examples

      iex> delete_session(session)
      {:ok, %Session{}}

      iex> delete_session(session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_session(%Session{} = session) do
    session
    |> Session.revoke_changeset(%{revoked_at: DateTime.add(DateTime.utc_now(), -1, :second)})
    |> Repo.update()
  end

  @doc ~S"""
  Returns nil if no matching user is found.
  Raises Ecto.MultipleResultsError if more than one is found:  https://hexdocs.pm/ecto/Ecto.MultipleResultsError.html

      iex> Accounts.get_session_by(title: "My post")

  """
  def get_session_by(params) do
    Repo.get_by(Session, params)
  end

  @doc ~S"""
  Raises Ecto.NoResultsError if no matching user is found.  https://hexdocs.pm/ecto/Ecto.NoResultsError.html
  Raises Ecto.MultipleResultsError if more than one is found:  https://hexdocs.pm/ecto/Ecto.MultipleResultsError.html

      iex> Accounts.get_session_by!(title: "My post")

  """
  def get_session_by!(params) do
    Repo.get_by!(Session, params)
  end

  @doc """
  Looks up user_id, expires_at, revoked_at, roles in the DB based
  on given api_token_hash.  Roles are included because this query
  is run on every single API call and we also need the roles each
  time.  It's less clean to combine them, but a lot more efficient.

  Returns Map if token is found, otherwise nil.

  username has unique index on it so should never have more than
  one result

  Returns %{
            user_id: s.user_id,
            username: u.username,
            expires_at: s.expires_at,
            revoked_at: s.revoked_at,
            roles: u.roles,
            latest_tos_accept_ver: u.latest_tos_accept_ver,
            latest_pp_accept_ver: u.latest_pp_accept_ver
          }
  """
  def get_session_expires_revoked_by_token(api_token_hash) do
    Repo.one(
      from s in Session,
        join: u in User,
        on: s.user_id == u.id,
        select: %{
          user_id: s.user_id,
          username: u.username,
          session_id: s.id,
          expires_at: s.expires_at,
          revoked_at: s.revoked_at,
          ip_address: s.ip_address,
          valid_only_for_ip: s.valid_only_for_ip,
          roles: u.roles,
          latest_tos_accept_ver: u.latest_tos_accept_ver,
          latest_pp_accept_ver: u.latest_pp_accept_ver
        },
        where: s.api_token_hash == ^api_token_hash
    )
  end

  def session_valid?(nil, _) do
    {:error, :not_found}
  end

  @doc """
  Checks the validity of the specified session (looking at
  expiration and revocation).

  Returns

    {:ok, user_id, username, session_id, ip_address, valid_only_for_ip, roles, expires_at, latest_tos_accept_ver, latest_pp_accept_ver}
    {:error, :revoked}
    {:error, :expired}
    {:error, :ip_addr}
  """
  def session_valid?(
        %{
          user_id: user_id,
          username: username,
          session_id: session_id,
          expires_at: expires_at,
          revoked_at: revoked_at,
          ip_address: ip_address,
          valid_only_for_ip: valid_only_for_ip,
          roles: roles,
          latest_tos_accept_ver: latest_tos_accept_ver,
          latest_pp_accept_ver: latest_pp_accept_ver
        },
        remote_ip
      ) do
    cond do
      !!revoked_at ->
        {:error, :revoked}

      DateTime.compare(expires_at, DateTime.utc_now()) == :lt ->
        {:error, :expired}

      valid_only_for_ip && ip_address != remote_ip ->
        {:error, :ip_addr}

      true ->
        {:ok, user_id, username, session_id, ip_address, valid_only_for_ip, roles, expires_at,
         latest_tos_accept_ver, latest_pp_accept_ver}
    end
  end

  # def session_valid?(user_id, username, session_id, expires_at, revoked_at, ip_addr, roles, remote_ip) do
  #   session_valid?([user_id, username, session_id, expires_at, revoked_at, ip_addr, roles], remote_ip)
  # end

  def session_revoked?(revoked_at), do: !!revoked_at

  def session_expired?(expires_at),
    do: DateTime.compare(expires_at, DateTime.utc_now()) == :lt

  @doc ~S"""
  This is a very *simple* check for validity that returns a boolean.  This should **NOT** be relied on for security!  It only considers expiration and revocation, and does not consider other important things like IP address of the requester.
  """
  def session_valid_bool?(expires_at, revoked_at),
    do: !session_revoked?(revoked_at) && !session_expired?(expires_at)

  @doc """
  Returns {:ok, user_id, username, user_roles, expires_at, latest_tos_accept_ver, latest_pp_accept_ver}
  if API token is valid.  Otherwise returns {:err, :revoked}

  If the session's :revoked_at is nil and :expires_at is in the future,
  the session is valid.  Otherwise the session is invalid

  ## Examples

    assert {:ok, user_id, username, session_id, user_roles, expires_at, latest_tos_accept_ver, latest_pp_accept_ver} = validate_session(api_token)
    assert {:error, :revoked} = validate_session(api_token)
    assert {:error, :expired} = validate_session(api_token)
    assert {:error, :not_found} = validate_session(api_token)
  """
  def validate_session(api_token, remote_ip) do
    api_token
    |> Utils.Crypto.hash_token()
    |> get_session_expires_revoked_by_token()
    |> session_valid?(remote_ip)
  end

  def revoke_active_sessions(%User{id: user_id}),
    do: revoke_active_sessions(user_id)

  def revoke_active_sessions(user_id) do
    {num_revoked, nil} =
      Repo.update_all(
        from(s in Session, where: s.user_id == ^user_id and is_nil(s.revoked_at)),
        set: [revoked_at: DateTime.add(DateTime.utc_now(), -1, :second)]
      )

    record_transaction(
      true,
      nil,
      nil,
      user_id,
      nil,
      "sessions",
      "DELETE",
      "#Accounts.revoke_active_sessions/1 - Revoked #{num_revoked} active sessions for user #{user_id}",
      %{}
    )

    {:ok, num_revoked}
  end

  def revoke_session(%Session{} = session), do: delete_session(%Session{} = session)

  alias Malan.Accounts.Team

  @doc """
  Returns the list of teams.

  ## Examples

      iex> list_teams()
      [%Team{}, ...]

  """
  def list_teams do
    Repo.all(Team)
  end

  @doc """
  Gets a single team.

  Raises `Ecto.NoResultsError` if the Team does not exist.

  ## Examples

      iex> get_team!(123)
      %Team{}

      iex> get_team!(456)
      ** (Ecto.NoResultsError)

  """
  def get_team!(id), do: Repo.get!(Team, id)

  @doc """
  Creates a team.

  ## Examples

      iex> create_team(%{field: value})
      {:ok, %Team{}}

      iex> create_team(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_team(attrs \\ %{}) do
    %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a team.

  ## Examples

      iex> update_team(team, %{field: new_value})
      {:ok, %Team{}}

      iex> update_team(team, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_team(%Team{} = team, attrs) do
    team
    |> Team.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a team.

  ## Examples

      iex> delete_team(team)
      {:ok, %Team{}}

      iex> delete_team(team)
      {:error, %Ecto.Changeset{}}

  """
  def delete_team(%Team{} = team) do
    Repo.delete(team)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking team changes.

  ## Examples

      iex> change_team(team)
      %Ecto.Changeset{data: %Team{}}

  """
  def change_team(%Team{} = team, attrs \\ %{}) do
    Team.changeset(team, attrs)
  end

  alias Malan.Accounts.PhoneNumber

  @doc """
  Returns the list of phone_numbers.

  ## Examples

      iex> list_phone_numbers()
      [%PhoneNumber{}, ...]

  """
  def list_phone_numbers do
    Repo.all(PhoneNumber)
  end

  @doc """
  Gets a single phone_number.

  Raises `Ecto.NoResultsError` if the Phone number does not exist.

  ## Examples

      iex> get_phone_number!(123)
      %PhoneNumber{}

      iex> get_phone_number!(456)
      ** (Ecto.NoResultsError)

  """
  def get_phone_number!(id), do: Repo.get!(PhoneNumber, id)

  @doc """
  Creates a phone_number.

  ## Examples

      iex> create_phone_number(user_id, %{field: value})
      {:ok, %PhoneNumber{}}

      iex> create_phone_number(user_id, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_phone_number(user_id, attrs \\ %{}) do
    %PhoneNumber{}
    |> PhoneNumber.create_changeset(Map.merge(attrs, %{"user_id" => user_id}))
    |> Repo.insert()
  end

  @doc """
  Updates a phone_number.

  ## Examples

      iex> update_phone_number(phone_number, %{field: new_value})
      {:ok, %PhoneNumber{}}

      iex> update_phone_number(phone_number, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_phone_number(%PhoneNumber{} = phone_number, attrs) do
    phone_number
    |> PhoneNumber.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a phone_number.

  ## Examples

      iex> delete_phone_number(phone_number)
      {:ok, %PhoneNumber{}}

      iex> delete_phone_number(phone_number)
      {:error, %Ecto.Changeset{}}

  """
  def delete_phone_number(%PhoneNumber{} = phone_number) do
    Repo.delete(phone_number)
  end

  defp phone_verified_at(true), do: Utils.DateTime.utc_now_trunc()
  defp phone_verified_at(false), do: nil

  def verify_phone_number(%PhoneNumber{} = phone_number, verified \\ true) do
    phone_number
    |> PhoneNumber.verify_changeset(%{verified_at: phone_verified_at(verified)})
    |> Repo.update()
  end

  alias Malan.Accounts.Address

  @doc """
  Returns the list of addresses.

  ## Examples

      iex> list_addresses()
      [%Address{}, ...]

  """
  def list_addresses do
    Repo.all(Address)
  end

  @doc """
  Gets a single address.

  Raises `Ecto.NoResultsError` if the Address does not exist.

  ## Examples

      iex> get_address!(123)
      %Address{}

      iex> get_address!(456)
      ** (Ecto.NoResultsError)

  """
  def get_address!(id), do: Repo.get!(Address, id)

  @doc """
  Creates a address.

  ## Examples

      iex> create_address(user_id, %{field: value})
      {:ok, %Address{}}

      iex> create_address(user_id, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_address(user_id, attrs \\ %{}) do
    %Address{}
    |> Address.create_changeset(Map.merge(attrs, %{"user_id" => user_id}))
    |> Repo.insert()
  end

  @doc """
  Updates a address.

  ## Examples

      iex> update_address(address, %{field: new_value})
      {:ok, %Address{}}

      iex> update_address(address, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_address(%Address{} = address, attrs) do
    address
    |> Address.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a address.

  ## Examples

      iex> delete_address(address)
      {:ok, %Address{}}

      iex> delete_address(address)
      {:error, %Ecto.Changeset{}}

  """
  def delete_address(%Address{} = address) do
    Repo.delete(address)
  end

  defp address_verified_at(true), do: Utils.DateTime.utc_now_trunc()
  defp address_verified_at(false), do: nil

  def verify_address(%Address{} = address, verified \\ true) do
    address
    |> Address.verify_changeset(%{verified_at: address_verified_at(verified)})
    |> Repo.update()
  end

  alias Malan.Accounts.Transaction

  @doc """
  Returns the list of transactions.

  ## Examples

      iex> list_transactions()
      [%Transaction{}, ...]

  """
  def list_transactions(page_num, page_size) do
    from(t in Transaction,
      select: t,
      limit: ^page_size,
      offset: ^(page_num * page_size)
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of transactions for the specified user

  ## Examples

      iex> list_transactions("user_id")
      [%Transaction{}, ...]

  """
  def list_transactions(%User{id: user_id}, page_num, page_size),
    do: list_transactions(user_id, page_num, page_size)

  def list_transactions(user_id_or_username, page_num, page_size) do
    cond do
      user_id_or_username == nil ->
        []

      Utils.is_uuid?(user_id_or_username) ->
        list_transactions_by_user_id(user_id_or_username, page_num, page_size)

      true ->
        list_transactions_by_username(user_id_or_username, page_num, page_size)
    end
  end

  #
  # SELECT t.* FROM transactions AS t WHERE t.id = (SELECT u.id FROM users AS u WHERE u.username = '$1');
  #
  # Written as join:
  #
  # SELECT t.* FROM transactions AS t JOIN users AS u ON u.username = '$1' WHERE t.user_id = u.id;
  # SELECT t.* FROM transactions AS t LEFT JOIN users AS u ON u.username = '$1' WHERE t.user_id = u.id;
  #
  def list_transactions_by_username(username, page_num, page_size) do
    # Initially attempted using a subquery in "where', but ran into a cast error.
    # Also found some docs that said that subqueries in ecto couldn't be used
    # in where clauses, but I don't think that's true anymore

    # user_id_q =
    #   from u in User,
    #   select: u.id,
    #   where: u.username == ^username

    # Repo.all(
    #   from t in Transaction,
    #     where: t.user_id == ^[subquery(user_id_q)]
    # )

    from(t in Transaction,
      select: t,
      join: u in User,
      on: u.username == ^username,
      where: t.user_id == u.id,
      limit: ^page_size,
      offset: ^(page_num * page_size)
    )
    |> Repo.all()
  end

  def list_transactions_by_user_id(nil, page_num, page_size) do
    Repo.all(
      from t in Transaction,
        where: is_nil(t.user_id),
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  def list_transactions_by_user_id(user_id, page_num, page_size) do
    Repo.all(
      from t in Transaction,
        where: t.user_id == ^user_id,
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  @doc """
  Returns the list of transactions created by the specified session id.

  ## Examples

      iex> list_transactions_by_session_id(session_id)
      [%Transaction{}, ...]

  """
  def list_transactions_by_session_id(nil, page_num, page_size) do
    Repo.all(
      from t in Transaction,
        where: is_nil(t.session_id),
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  def list_transactions_by_session_id(session_id, page_num, page_size) do
    Repo.all(
      from t in Transaction,
        where: t.session_id == ^session_id,
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  @doc """
  Returns the list of transactions that affected the specified user id.

  ## Examples

      iex> list_transactions_by_who(user_id)
      [%Transaction{}, ...]

  """
  def list_transactions_by_who(nil, page_num, page_size) do
    Repo.all(
      from t in Transaction,
        where: is_nil(t.who),
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  def list_transactions_by_who(user_id, page_num, page_size) do
    Repo.all(
      from t in Transaction,
        where: t.who == ^user_id,
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  @doc """
  Gets a single transaction.

  Raises `Ecto.NoResultsError` if the Transaction does not exist.

  ## Examples

      iex> get_transaction!(123)
      %Transaction{}

      iex> get_transaction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_transaction!(id), do: Repo.get!(Transaction, id)

  @doc ~S"""
  Returns nil if no matching user is found.
  Raises Ecto.MultipleResultsError if more than one is found:  https://hexdocs.pm/ecto/Ecto.MultipleResultsError.html

      iex> Accounts.get_transactions_by(title: "My post")

  """
  def get_transaction_by(params) do
    Repo.get_by(Transaction, params)
  end

  @doc ~S"""
  Returns transaction

  Raises Ecto.NoResultsError if no matching user is found.  https://hexdocs.pm/ecto/Ecto.NoResultsError.html
  Raises Ecto.MultipleResultsError if more than one is found:  https://hexdocs.pm/ecto/Ecto.MultipleResultsError.html

      iex> Accounts.get_transactions_by!(title: "My post")
      %Transaction{}
  """
  def get_transaction_by!(params) do
    Repo.get_by!(Transaction, params)
  end

  @doc """
  Retrieve the owner (user_id) of the specified transaction.

  Raises Malan.CantBeNil if given a nil argument for transaction_id
  Returns %{user_id: "user_id"}

      iex> Accounts.get_transaction_user(transaction_id)
      %{user_id: "user_id"}
  """
  def get_transaction_user(transaction_id) do
    Utils.raise_if_nil!("transaction_id", transaction_id)

    Repo.one(
      from t in Transaction,
        select: %{user_id: t.user_id},
        where: t.id == ^transaction_id
    )
  end

  @doc """
  Creates a transaction.  A transaction is immutable once it is created, so it
  cannot be updated later.  Make sure you have all the info you need now!

  `success?` is whether the operation being logged was successful
  `user_id` is the user owning the session that made the change
  `session_id` is the session that made the change
  `who_id` is the user id of the user being changed
  `type` is either "users" or "sessions" depending on which table was changed
  `verb` is GET || PUT || POST || DELETE
  `what` is a human readable stering describing the change
  `when_utc` is a utc timestamp of when the change happened

  ## Examples

      iex> create_transaction(%{field: value})
      {:ok, %Transaction{}}

      iex> create_transaction(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_transaction(
        success?,
        user_id,
        session_id,
        who_id,
        who_username,
        type,
        verb,
        what,
        tx_changeset,
        when_utc \\ nil
      ) do
    create_transaction(success?, user_id, session_id, who_id, who_username, tx_changeset, %{
      "success" => success?,
      "type" => type,
      "verb" => verb,
      "what" => what,
      "when" => when_utc
    })
  end

  def create_transaction(
        success?,
        user_id,
        session_id,
        who_id,
        who_username,
        tx_changeset,
        attrs \\ %{}
      ) do
    %Transaction{}
    |> Transaction.create_changeset(
      Map.merge(attrs, %{
        "success" => success?,
        "user_id" => user_id,
        "session_id" => session_id,
        "who" => who_id,
        "who_username" => who_username,
        "changeset" => tx_changeset
      })
    )
    |> Repo.insert()
  end

  @doc ~S"""
  Record a transaction with the specified properties. Logs failures and reports to Sentry

  Returns {:ok, transaction} on success or {:error, changeset} on failure
  """
  def record_transaction(
        success?,
        user_id,
        session_id,
        who,
        who_username,
        type,
        verb,
        what,
        tx_changeset
      ) do
    case create_transaction(
           success?,
           user_id,
           session_id,
           who,
           who_username,
           type,
           verb,
           what,
           tx_changeset
         ) do
      {:ok, transaction} ->
        {:ok, transaction}

      {:error, changeset} ->
        report_transaction_error(changeset, user_id, session_id, who, who_username, verb, what)
    end
  end

  defp report_transaction_error(changeset, user_id, session_id, who, who_username, verb, what) do
    # TODO: Report a failure in create_transaction to Sentry
    Logger.warning(
      "Error recording transaction: user_id: '#{user_id}', session_id: '#{session_id}', who: '#{who}', who_username: '#{who_username}', verb: '#{verb}', what: '#{what}' - Changeset Errors to str:  '#{Utils.Ecto.Changeset.errors_to_str(changeset)}'"
    )

    {:error, changeset}
  end

  @doc """
  Updates a transaction.  Because transactions are immutable and can't
  be changed after the fact, this function should raise

  ## Examples

      iex> update_transaction(transaction, %{field: new_value})
      {:ok, %Transaction{}}

      iex> update_transaction(transaction, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_transaction(%Transaction{} = transaction, _attrs) do
    # transaction
    # |> Transaction.changeset(attrs)
    # |> Repo.update()

    raise Malan.ObjectIsImmutable,
      action: "update",
      type: "Transaction",
      id: transaction.id
  end

  @doc """
  Deletes a transaction.

  ## Examples

      iex> delete_transaction(transaction)
      {:ok, %Transaction{}}

      iex> delete_transaction(transaction)
      {:error, %Ecto.Changeset{}}

  """
  def delete_transaction(%Transaction{} = transaction) do
    # Repo.delete(transaction)

    raise Malan.ObjectIsImmutable,
      action: "delete",
      type: "Transaction",
      id: transaction.id
  end
end
