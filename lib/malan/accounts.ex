defmodule Malan.Accounts do
  @moduledoc """
  The Accounts context.
  """

  require Logger

  import Ecto.Query, warn: false
  import Malan.Pagination, only: [valid_page: 2]
  import Malan.Accounts.Log, only: [dummy_ip: 0]

  alias Malan.Repo

  alias Malan.Accounts.User
  alias Malan.Accounts.Session
  alias Malan.Accounts.SessionExtension
  alias Malan.Accounts.EmailVerificationEvent
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
      order_by: [asc: u.inserted_at, asc: u.id],
      limit: ^page_size,
      offset: ^(page_num * page_size)
    )
    |> Repo.all()
  end

  @doc """
  List users for the admin console with an optional free-text search against
  username, email, display name, and first/last name. Returns
  `{users, has_next_page?}`. `page_num` is zero-indexed.

  Search terms shorter than 3 characters return `{[], false}` — pg_trgm
  indexes require 3-char n-grams to be selective, and anything shorter
  degenerates to a full table scan.
  """
  def admin_list_users(page_num, page_size, opts \\ [])
      when valid_page(page_num, page_size) do
    search = opts |> Keyword.get(:search, "") |> to_string() |> String.trim()

    cond do
      search != "" and String.length(search) < 3 ->
        {[], false}

      true ->
        do_admin_list_users(page_num, page_size, search)
    end
  end

  defp do_admin_list_users(page_num, page_size, search) do
    base = from(u in User, where: is_nil(u.deleted_at))

    base =
      if search == "" do
        base
      else
        like = "%" <> String.downcase(search) <> "%"

        # username and email are citext; gin_trgm_ops is text-typed, so the
        # planner won't use the trigram index unless we cast. The three
        # varchar columns stay bare — ILIKE against NULL returns NULL which
        # is falsy in an OR chain, so no coalesce is needed.
        from(u in base,
          where:
            ilike(fragment("?::text", u.username), ^like) or
              ilike(fragment("?::text", u.email), ^like) or
              ilike(u.display_name, ^like) or
              ilike(u.first_name, ^like) or
              ilike(u.last_name, ^like)
        )
      end

    rows =
      from(u in base,
        order_by: [desc: u.inserted_at, asc: u.id],
        limit: ^(page_size + 1),
        offset: ^(page_num * page_size)
      )
      |> Repo.all()

    if length(rows) > page_size do
      {Enum.take(rows, page_size), true}
    else
      {rows, false}
    end
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
  Retrieve the user matching the specified param(s) or `nil`.

  Returns `%User{}` if found, raises Ecto.NoResultsError if not found

  Returns `nil` if no matching user is found.
  Raises Ecto.MultipleResultsError if more than one is found:  https://hexdocs.pm/ecto/Ecto.MultipleResultsError.html

      iex> Accounts.get_user_by(email: "brad@example.com")

  """
  def get_user_by(params) do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.get_by(params)
  end

  @doc ~S"""
  Retrieve the user matching the specified param(s).

  Returns `%User{}` if found, raises Ecto.NoResultsError if not found

  Raises `Ecto.NoResultsError` if no matching user is found.  https://hexdocs.pm/ecto/Ecto.NoResultsError.html
  Raises `Ecto.MultipleResultsError` if more than one is found:  https://hexdocs.pm/ecto/Ecto.MultipleResultsError.html

      iex> Accounts.get_user_by!(email: "brad@example.com")

  """
  def get_user_by!(params) do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.get_by!(params)
  end

  def get_user_by_email(email) do
    get_user_by(email: email)
  end

  def get_user_by_password_reset_token(token) do
    get_user_by(password_reset_token_hash: Utils.Crypto.hash_token(token))
  end

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
  def update_user(user, attrs, remote_ip \\ dummy_ip(), opts \\ [])

  def update_user(%User{} = user, %{"password" => _password} = attrs, rip, opts) do
    original_email = user.email

    with {:ok, updated} <- update_usr(user, attrs, rip, opts),
         {:ok, _num_revoked} <- revoke_active_sessions(updated, rip) do
      maybe_send_email_change_verification(updated, original_email, rip)
      {:ok, updated}
    end
  end

  def update_user(%User{} = user, attrs, rip, opts) do
    original_email = user.email

    case update_usr(user, attrs, rip, opts) do
      {:ok, updated} ->
        maybe_send_email_change_verification(updated, original_email, rip)
        {:ok, updated}

      other ->
        other
    end
  end

  defp maybe_send_email_change_verification(%User{} = updated, original_email, rip) do
    if is_binary(original_email) and original_email != updated.email do
      meta = %{ip: rip}

      case generate_email_verification(updated, rate_limit?: true, context: :email_change, meta: meta) do
        {:ok, %User{} = user_with_token} ->
          Malan.Mailer.send_email_verification_email(user_with_token, :email_change)
          :ok

        _ ->
          :ok
      end
    else
      :ok
    end
  end

  def update_user_password(user, password, remote_ip \\ dummy_ip())

  def update_user_password(%User{} = user, password, rip),
    do: update_user(user, %{"password" => password}, rip)

  def update_user_password(user_id, password, rip) do
    get_user(user_id)
    |> update_user_password(password, rip)
  end

  def admin_update_password(user, password, remote_ip \\ dummy_ip())

  def admin_update_password(%User{} = user, password, rip),
    do: update_user(user, %{"password" => password}, rip, password_set_by_admin?: true)

  def admin_update_password(user_id, password, rip) do
    get_user(user_id)
    |> admin_update_password(password, rip)
  end

  @doc """
  Generates a password reset token that can then be used to reset the user's password.

  Requests are rate-limited based on `user.id` unless :no_rate_limit is passed

  Returns {:ok, %User{}} on success or
          {:error, changeset} on failure
          {:error, :too_many_requests} on hitting rate limit
  """
  def generate_password_reset(%User{} = user) do
    # case Malan.RateLimits.PasswordReset.LowerLimit.check_rate(user.id) do
    case Malan.RateLimits.PasswordReset.check_rate(user.id) do
      {:allow, _count} ->
        generate_password_reset(user, :no_rate_limit)

      {:deny, _limit} ->
        {:error, :too_many_requests}
    end
  end

  @doc ~S"""
  Generates a password reset token that can then be used to reset the user's password.

  Returns {:ok, %User{}} on success or
          {:error, changeset} on failure
  """
  def generate_password_reset(%User{} = user, :no_rate_limit) do
    user
    |> User.password_reset_create_changeset()
    |> Repo.update()
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
  def reset_password_with_token(user, token, new_password, remote_ip \\ dummy_ip())

  def reset_password_with_token(%User{} = orig_user, token, new_password, rip) do
    with {:ok} <- validate_password_reset_token(orig_user, token),
         {:ok, %User{}} <- clear_password_reset_token(orig_user),
         {:ok, %User{} = user} <- update_user_password(orig_user, new_password, rip) do
      {:ok, user}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def reset_password_with_token(id, token, new_password, rip),
    do: reset_password_with_token(get_user(id), token, new_password, rip)

  def admin_reset_password_with_token(user, token, new_password, remote_ip \\ dummy_ip())

  def admin_reset_password_with_token(%User{} = orig_user, token, new_password, rip) do
    with {:ok} <- validate_password_reset_token(orig_user, token),
         {:ok, %User{}} <- clear_password_reset_token(orig_user),
         {:ok, %User{} = user} <- admin_update_password(orig_user, new_password, rip) do
      {:ok, user}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def admin_reset_password_with_token(id, token, new_password, rip),
    do: admin_reset_password_with_token(get_user(id), token, new_password, rip)

  # "private utility for the update_user funcs.  Use a public update_user()"
  defp update_usr(user, attrs, remote_ip, opts) do
    user
    |> User.update_changeset(Map.merge(attrs, %{"remote_ip" => remote_ip}), opts)
    |> Repo.update()
  end

  @doc ""
  def admin_update_user(user, attrs) do
    original_email = user.email
    admin_email_verified_toggle = extract_admin_email_verified_toggle(attrs)

    result =
      user
      |> User.admin_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        case admin_email_verified_toggle do
          :unset ->
            maybe_send_email_change_verification(updated, original_email, dummy_ip())

          value ->
            set_email_verified(updated, value, meta: %{})
        end

        {:ok, updated}

      other ->
        other
    end
  end

  defp extract_admin_email_verified_toggle(attrs) when is_map(attrs) do
    cond do
      Map.has_key?(attrs, "email_verified") -> Map.get(attrs, "email_verified")
      Map.has_key?(attrs, :email_verified) -> Map.get(attrs, :email_verified)
      true -> :unset
    end
  end

  defp extract_admin_email_verified_toggle(_), do: :unset

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user, remote_ip \\ dummy_ip()) do
    with {:ok, _num_revoked} <- revoke_active_sessions(user, remote_ip) do
      user
      |> User.delete_changeset()
      |> Repo.update()
    end
  end

  def lock_user(%User{} = user, locked_by_id, remote_ip \\ dummy_ip()) do
    with cs <- User.lock_changeset(user, locked_by_id),
         {:ok, user} <- Repo.update(cs),
         {:ok, _num_revoked} <- revoke_active_sessions(user, remote_ip) do
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
        order_by: [desc: s.inserted_at, desc: s.id],
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  def get_session_owned(id, user_id) do
    Repo.get_by(Session, id: id, user_id: user_id)
  end

  def list_sessions(page_num, page_size) do
    Repo.all(
      from s in Session,
        select: s,
        order_by: [desc: s.inserted_at, desc: s.id],
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
        order_by: [desc: s.inserted_at, desc: s.id],
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

  def get_session(id), do: Repo.get(Session, id)

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
        where: u.username == ^username or u.email == ^username,
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
          {:error, :too_many_requests}
  """
  def authenticate_by_username_pass(username, given_pass, remote_ip) do
    with {:allow, _} <- Malan.RateLimits.Login.check_rate(username) do
      case get_user_id_pass_hash_by_username(username) do
        {user_id, password_hash, nil, approved_ips} ->
          verify_pass(user_id, given_pass, password_hash, approved_ips, remote_ip)

        {user_id, password_hash, locked_at, _} ->
          verify_pass_locked(user_id, given_pass, password_hash, locked_at)

        nil ->
          fake_pass_verify(:not_a_user)
      end
    else
      {:deny, _limit} ->
        {:error, :too_many_requests}
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
    |> update_user(%{"accept_tos" => accept_tos})
  end

  @doc "Accepts the Terms of Service for the user.  Returns {:ok, user}"
  def user_accept_tos(user_id), do: user_tos(true, user_id)

  @doc "Rejects the Terms of Service for the user.  Returns {:ok, user}"
  def user_reject_tos(user_id), do: user_tos(false, user_id)

  def user_set_privacy_policy(accept_privacy_policy, user_id) do
    # TODO don't retrieve the entire user.
    # Just generate update sql that replaces only the part we want to replace
    get_user!(user_id)
    |> update_user(%{"accept_privacy_policy" => accept_privacy_policy})
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

  def new_session(user_id, remote_ip, attrs) do
    attrs
    |> Map.put("user_id", user_id)
    |> Map.put("remote_ip", remote_ip)
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
      {:ok, user_id} -> new_session(user_id, remote_ip, attrs)
      {:error, :user_locked} -> record_create_session_locked(username, remote_ip, attrs)
      {:error, :ip_addr} -> record_create_session_bad_ip(username, remote_ip, attrs)
      {:error, :unauthorized} -> record_create_session_unauthorized(username, remote_ip, attrs)
      {:error, :not_a_user} -> record_create_session_not_a_user(username, remote_ip, attrs)
      {:error, :too_many_requests} -> {:error, :too_many_requests}
    end
  end

  @doc """
  Record failed session creation attempt as unauthorized.

  Returns {:error, :unauthorized}
  """
  def record_create_session_locked(username_or_id, remote_ip, attrs, username \\ nil) do
    case Utils.is_uuid_or_nil?(username_or_id) do
      true ->
        record_log(
          false,
          username_or_id,
          nil,
          username_or_id,
          username,
          "sessions",
          "POST",
          "#Accounts.record_create_session_locked/3 - Unauthorized login attempt for user '#{username_or_id}' failed from IP '#{remote_ip}' because user account is locked:  #{Utils.map_to_string(attrs, [:password])}",
          remote_ip,
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
        record_log(
          false,
          username_or_id,
          nil,
          username_or_id,
          username,
          "sessions",
          "POST",
          "#Accounts.record_create_session_bad_ip/3 - Unauthorized login attempt for user '#{username_or_id}' failed from IP '#{remote_ip}' because IP is not on user's approved list:  #{Utils.map_to_string(attrs, [:password])}",
          remote_ip,
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
        record_log(
          false,
          username_or_id,
          nil,
          username_or_id,
          username,
          "sessions",
          "POST",
          "#Accounts.record_create_session_unauthorized/3 - Unauthorized login attempt for user '#{username_or_id}' failed from IP '#{remote_ip}':  #{Utils.map_to_string(attrs, [:password])}",
          remote_ip,
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
        record_log(
          false,
          username_or_id,
          nil,
          username_or_id,
          username,
          "sessions",
          "POST",
          "#Accounts.record_create_session_not_a_user/3 - Unauthorized login attempt for user with ID or username of '#{username_or_id}' (that user does not exist) from IP '#{remote_ip}':  #{Utils.map_to_string(attrs, [:password])}",
          remote_ip,
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
  def delete_session(%Session{} = session), do: revoke_session(session)

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

  @doc """
  Checks the validity of the specified session (looking at
  expiration and revocation).  Token failures will be logged.

  Returns

    {:ok, user_id, username, session_id, ip_address, valid_only_for_ip, roles, expires_at, latest_tos_accept_ver, latest_pp_accept_ver}
    {:error, :revoked}
    {:error, :expired}
    {:error, :ip_addr}
  """
  def session_valid?(nil, _) do
    {:error, :not_found}
  end

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
        Logger.info("[session_valid?]: A revoked API token was used.  Revoked at: #{revoked_at}")
        {:error, :revoked}

      DateTime.compare(expires_at, DateTime.utc_now()) == :lt ->
        Logger.info(
          "[session_valid?]: An expired API token was used.  Expired at: '#{expires_at}'"
        )

        {:error, :expired}

      valid_only_for_ip && ip_address != remote_ip ->
        Logger.info(
          "[session_valid?]: A token was used from the wrong ip address. valid ip: '#{ip_address}', remote_ip: '#{remote_ip}"
        )

        {:error, :ip_addr}

      true ->
        {:ok, user_id, username, session_id, ip_address, valid_only_for_ip, roles, expires_at,
         latest_tos_accept_ver, latest_pp_accept_ver}
    end
  end

  def session_revoked?(%Session{revoked_at: revoked_at}),
    do: session_revoked?(revoked_at)

  # session doesn't have the revoked_at set so it is nil
  def session_revoked?(%Session{}), do: false

  def session_revoked?(revoked_at), do: !!revoked_at

  def session_expired?(%Session{expires_at: expires_at}),
    do: session_expired?(expires_at)

  def session_expired?(expires_at),
    do: DateTime.compare(expires_at, DateTime.utc_now()) == :lt

  def session_revoked_or_expired?(nil),
    do: true

  def session_revoked_or_expired?(%Session{expires_at: expires_at, revoked_at: revoked_at}),
    do: session_revoked?(revoked_at) || session_expired?(expires_at)

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

  def revoke_active_sessions(user, remote_ip \\ dummy_ip())

  def revoke_active_sessions(%User{id: user_id}, remote_ip),
    do: revoke_active_sessions(user_id, remote_ip)

  def revoke_active_sessions(user_id, remote_ip) do
    {num_revoked, nil} =
      Repo.update_all(
        from(s in Session, where: s.user_id == ^user_id and is_nil(s.revoked_at)),
        set: [revoked_at: DateTime.add(DateTime.utc_now(), -1, :second)]
      )

    record_log(
      true,
      nil,
      nil,
      user_id,
      nil,
      "sessions",
      "DELETE",
      "#Accounts.revoke_active_sessions/1 - Revoked #{num_revoked} active sessions for user #{user_id}",
      remote_ip,
      %{}
    )

    {:ok, num_revoked}
  end

  def revoke_session(%Session{} = session) do
    session
    |> revoke_session_at(DateTime.utc_now() |> DateTime.add(-1, :second))
  end

  def revoke_session_at(%Session{} = session, %DateTime{} = datetime) do
    session
    |> Session.revoke_changeset(%{revoked_at: datetime})
    |> Repo.update()
  end

  def extend_session(%Session{} = session, attrs, authed_ids \\ %{}) do
    Repo.transaction(fn ->
      sc = Session.extend_changeset(session, attrs)
      sec = SessionExtension.create_changeset(sc, authed_ids)

      sec = Repo.insert!(sec)
      sc = Repo.update!(sc)
      {sc, sec}
    end)
  end

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
    Repo.all(
      from p in PhoneNumber,
        order_by: [asc: p.inserted_at, asc: p.id]
    )
  end

  def list_phone_numbers_for_user(user_id) do
    Repo.all(
      from p in PhoneNumber,
        where: p.user_id == ^user_id,
        order_by: [asc: p.inserted_at, asc: p.id]
    )
  end

  def get_phone_number(id), do: Repo.get(PhoneNumber, id)

  def get_phone_number_owned(id, user_id) do
    Repo.get_by(PhoneNumber, id: id, user_id: user_id)
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
    Repo.all(
      from a in Address,
        order_by: [asc: a.inserted_at, asc: a.id]
    )
  end

  def list_addresses_for_user(user_id) do
    Repo.all(
      from a in Address,
        where: a.user_id == ^user_id,
        order_by: [asc: a.inserted_at, asc: a.id]
    )
  end

  def get_address(id), do: Repo.get(Address, id)

  def get_address_owned(id, user_id) do
    Repo.get_by(Address, id: id, user_id: user_id)
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

  alias Malan.Accounts.Log

  @doc """
  Returns the list of logs.

  ## Examples

      iex> list_logs()
      [%Log{}, ...]

  """
  def list_logs(page_num, page_size) do
    from(l in Log,
      select: l,
      order_by: [asc: l.inserted_at, asc: l.id],
      limit: ^page_size,
      offset: ^(page_num * page_size)
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of logs for the specified user

  ## Examples

      iex> list_logs("user_id")
      [%Log{}, ...]

  """
  def list_logs(%User{id: user_id}, page_num, page_size),
    do: list_logs(user_id, page_num, page_size)

  def list_logs(user_id_or_username, page_num, page_size) do
    cond do
      user_id_or_username == nil ->
        []

      Utils.is_uuid?(user_id_or_username) ->
        list_logs_by_user_id(user_id_or_username, page_num, page_size)

      true ->
        list_logs_by_username(user_id_or_username, page_num, page_size)
    end
  end

  #
  # SELECT l.* FROM logs AS l WHERE l.id = (SELECT u.id FROM users AS u WHERE u.username = '$1');
  #
  # Written as join:
  #
  # SELECT l.* FROM logs AS l JOIN users AS u ON u.username = '$1' WHERE l.user_id = u.id;
  # SELECT l.* FROM logs AS l LEFT JOIN users AS u ON u.username = '$1' WHERE l.user_id = u.id;
  #
  def list_logs_by_username(username, page_num, page_size) do
    # Initially attempted using a subquery in "where', but ran into a cast error.
    # Also found some docs that said that subqueries in ecto couldn't be used
    # in where clauses, but I don't think that's true anymore

    # user_id_q =
    #   from u in User,
    #   select: u.id,
    #   where: u.username == ^username

    # Repo.all(
    #   from l in Log,
    #     where: l.user_id == ^[subquery(user_id_q)]
    # )

    from(l in Log,
      select: l,
      join: u in User,
      on: u.username == ^username,
      where: l.user_id == u.id,
      order_by: [asc: l.inserted_at, asc: l.id],
      limit: ^page_size,
      offset: ^(page_num * page_size)
    )
    |> Repo.all()
  end

  def list_logs_by_user_id(nil, page_num, page_size) do
    Repo.all(
      from l in Log,
        where: is_nil(l.user_id),
        order_by: [asc: l.inserted_at, asc: l.id],
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  def list_logs_by_user_id(user_id, page_num, page_size) do
    Repo.all(
      from l in Log,
        where: l.user_id == ^user_id,
        order_by: [asc: l.inserted_at, asc: l.id],
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  @doc """
  Returns the list of logs created by the specified session id.

  ## Examples

      iex> list_logs_by_session_id(session_id)
      [%Log{}, ...]

  """
  def list_logs_by_session_id(nil, page_num, page_size) do
    Repo.all(
      from l in Log,
        where: is_nil(l.session_id),
        order_by: [asc: l.inserted_at, asc: l.id],
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  def list_logs_by_session_id(session_id, page_num, page_size) do
    Repo.all(
      from l in Log,
        where: l.session_id == ^session_id,
        order_by: [asc: l.inserted_at, asc: l.id],
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  @doc """
  Returns the list of logs that affected the specified user id.

  ## Examples

      iex> list_logs_by_who(user_id)
      [%Log{}, ...]

  """
  def list_logs_by_who(nil, page_num, page_size) do
    Repo.all(
      from l in Log,
        where: is_nil(l.who),
        order_by: [asc: l.inserted_at, asc: l.id],
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  def list_logs_by_who(user_id, page_num, page_size) do
    Repo.all(
      from l in Log,
        where: l.who == ^user_id,
        order_by: [asc: l.inserted_at, asc: l.id],
        limit: ^page_size,
        offset: ^(page_num * page_size)
    )
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the Log does not exist.

  ## Examples

      iex> get_log!(123)
      %Log{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_log!(id), do: Repo.get!(Log, id)

  @doc ~S"""
  Returns nil if no matching user is found.
  Raises Ecto.MultipleResultsError if more than one is found:  https://hexdocs.pm/ecto/Ecto.MultipleResultsError.html

      iex> Accounts.get_logs_by(title: "My post")

  """
  def get_log_by(params) do
    Repo.get_by(Log, params)
  end

  @doc ~S"""
  Returns log

  Raises Ecto.NoResultsError if no matching user is found.  https://hexdocs.pm/ecto/Ecto.NoResultsError.html
  Raises Ecto.MultipleResultsError if more than one is found:  https://hexdocs.pm/ecto/Ecto.MultipleResultsError.html

      iex> Accounts.get_logs_by!(title: "My post")
      %Log{}
  """
  def get_log_by!(params) do
    Repo.get_by!(Log, params)
  end

  @doc """
  Retrieve the owner (user_id) of the specified log.

  Raises Malan.CantBeNil if given a nil argument for log_id
  Returns %{user_id: "user_id"}

      iex> Accounts.get_log_user(log_id)
      %{user_id: "user_id"}
  """
  def get_log_user(log_id) do
    Utils.raise_if_nil!("log_id", log_id)

    Repo.one(
      from l in Log,
        select: %{user_id: l.user_id},
        where: l.id == ^log_id
    )
  end

  @doc """
  Creates a log.  A log is immutable once it is created, so it
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

      iex> create_log(%{field: value})
      {:ok, %Log{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_log(
        success?,
        user_id,
        session_id,
        who_id,
        who_username,
        type,
        verb,
        what,
        remote_ip,
        log_changeset,
        when_utc \\ nil
      ) do
    create_log(
      success?,
      user_id,
      session_id,
      who_id,
      who_username,
      remote_ip,
      log_changeset,
      %{
        "success" => success?,
        "type" => type,
        "verb" => verb,
        "what" => what,
        "when" => when_utc
      }
    )
  end

  def create_log(
        success?,
        user_id,
        session_id,
        who_id,
        who_username,
        remote_ip,
        log_changeset,
        attrs \\ %{}
      ) do
    %Log{}
    |> Log.create_changeset(
      Map.merge(attrs, %{
        "success" => success?,
        "user_id" => user_id,
        "session_id" => session_id,
        "who" => who_id,
        "who_username" => who_username,
        "remote_ip" => remote_ip,
        "changeset" => log_changeset
      })
    )
    |> Repo.insert()
  end

  @doc ~S"""
  Record a log with the specified properties via Oban background job.

  The log write is enqueued asynchronously for reliability and performance.
  Oban guarantees delivery through its persistent job queue and retry mechanism.

  Returns {:ok, %Oban.Job{}} on successful enqueue or {:error, changeset} on failure.
  """
  def record_log(
        success?,
        user_id,
        session_id,
        who,
        who_username,
        type,
        verb,
        what,
        remote_ip,
        log_changeset
      ) do
    serializable_changeset =
      case log_changeset do
        %Ecto.Changeset{} -> Log.Changes.map_from_changeset(log_changeset)
        other -> other
      end

    %{
      "success" => success?,
      "user_id" => user_id,
      "session_id" => session_id,
      "who" => who,
      "who_username" => who_username,
      "type" => type,
      "verb" => verb,
      "what" => what,
      "remote_ip" => remote_ip,
      "changeset" => serializable_changeset,
      "when" => Utils.DateTime.utc_now_trunc() |> DateTime.to_iso8601()
    }
    |> json_safe()
    |> Malan.Workers.LogWriter.new()
    |> Oban.insert()
  end

  # Recursively converts structs, atoms, and date/time types to
  # JSON-safe primitives so Oban can serialize job args.
  defp json_safe(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp json_safe(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp json_safe(%Date{} = d), do: Date.to_iso8601(d)

  defp json_safe(value) when is_struct(value) do
    value |> Map.from_struct() |> Map.delete(:__meta__) |> json_safe()
  end

  defp json_safe(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {to_string(k), json_safe(v)} end)
  end

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(value) when is_tuple(value), do: value |> Tuple.to_list() |> json_safe()
  defp json_safe(value) when is_atom(value) and not is_boolean(value) and not is_nil(value), do: Atom.to_string(value)
  defp json_safe(value), do: value

  @doc """
  Updates a log.  Because logs are immutable and can't
  be changed after the fact, this function should raise

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %Log{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_log(%Log{} = log, _attrs) do
    # log
    # |> Log.changeset(attrs)
    # |> Repo.update()

    raise Malan.ObjectIsImmutable,
      action: "update",
      type: "Log",
      id: log.id
  end

  @doc """
  Deletes a log.

  ## Examples

      iex> delete_log(log)
      {:ok, %Log{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_log(%Log{} = log) do
    # Repo.delete(log)

    raise Malan.ObjectIsImmutable,
      action: "delete",
      type: "Log",
      id: log.id
  end

  alias Malan.Accounts.SessionExtension

  @doc """
  Returns the list of session_extensions.

  ## Examples

      iex> list_session_extensions(0, 10)
      [%SessionExtension{}, ...]

  """
  def list_session_extensions(page_num, page_size) when valid_page(page_num, page_size) do
    from(
      s in SessionExtension,
      select: s,
      order_by: [desc: s.inserted_at, desc: s.new_expires_at],
      limit: ^page_size,
      offset: ^(page_num * page_size)
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of session_extensions for the specified session.

  ## Examples

      iex> list_session_extensions(session.id, 0, 10)
      [%SessionExtension{}, ...]

  """
  def list_session_extensions(session_id, page_num, page_size)
      when valid_page(page_num, page_size) do
    from(
      s in SessionExtension,
      select: s,
      where: s.session_id == ^session_id,
      order_by: [desc: s.inserted_at, desc: s.new_expires_at],
      limit: ^page_size,
      offset: ^(page_num * page_size)
    )
    |> Repo.all()
  end

  @doc """
  Gets a single session_extension.

  Raises `Ecto.NoResultsError` if the Session extension does not exist.

  ## Examples

      iex> get_session_extension!(123)
      %SessionExtension{}

      iex> get_session_extension!(456)
      ** (Ecto.NoResultsError)

  """
  def get_session_extension!(id), do: Repo.get!(SessionExtension, id)

  # ---------------------------------------------------------------------------
  # Email verification
  # ---------------------------------------------------------------------------

  @doc """
  Fetch a user by the raw email verification token (looks up by hash).
  Returns nil when not found.
  """
  def get_user_by_email_verification_token(nil), do: nil
  def get_user_by_email_verification_token(""), do: nil

  def get_user_by_email_verification_token(token) when is_binary(token) do
    get_user_by(email_verification_token_hash: Utils.Crypto.hash_token(token))
  end

  @doc """
  Validate an email verification token against a loaded user.

  Returns:
    {:ok}                                   - token is valid and not expired
    {:error, :missing_email_verification_token}
    {:error, :expired_email_verification_token}
    {:error, :invalid_email_verification_token}
  """
  def validate_email_verification_token(%User{} = user, token) do
    cond do
      Utils.nil_or_empty?(user.email_verification_token_hash) ->
        {:error, :missing_email_verification_token}

      Utils.DateTime.expired?(user.email_verification_token_expires_at) ->
        {:error, :expired_email_verification_token}

      user.email_verification_token_hash == Utils.Crypto.hash_token(token) ->
        {:ok}

      true ->
        {:error, :invalid_email_verification_token}
    end
  end

  @doc """
  Clear the email verification token (does not touch email_verified).
  """
  def clear_email_verification_token(%User{} = user) do
    user
    |> User.email_verification_clear_changeset()
    |> Repo.update()
  end

  @doc """
  Generate an email verification token for a user.

  Always rate-limited based on `user.id` unless `:no_rate_limit` is passed.

  Success results:
    {:ok, %User{}}              - token generated (raw token on struct)
    {:ok, :already_verified}    - user already verified, no-op success
    {:ok, :skipped_domain}      - domain on skip list, no mail
    {:ok, :skipped_auto_send_disabled} - auto-send globally disabled

  Error results:
    {:error, :too_many_requests}
    {:error, %Ecto.Changeset{}}

  Audit rows are written for every outcome.
  """
  def generate_email_verification(user, mode_or_opts \\ [])

  def generate_email_verification(%User{} = user, :no_rate_limit) do
    generate_email_verification(user, rate_limit?: false, context: :resend)
  end

  def generate_email_verification(%User{} = user, opts) when is_list(opts) do
    rate_limit? = Keyword.get(opts, :rate_limit?, true)
    context = Keyword.get(opts, :context, :resend)
    meta = Keyword.get(opts, :meta, %{})

    cond do
      not is_nil(user.email_verified) ->
        record_email_verification_event(user, Map.merge(meta, %{event_type: "skipped_already_verified"}))
        {:ok, :already_verified}

      not Malan.Config.User.email_verification_auto_send?() and context in [:welcome, :email_change] ->
        record_email_verification_event(user, Map.merge(meta, %{event_type: "skipped_auto_send_disabled"}))
        {:ok, :skipped_auto_send_disabled}

      User.skip_email_verification_send?(user.email) ->
        record_email_verification_event(user, Map.merge(meta, %{event_type: "skipped_domain"}))
        {:ok, :skipped_domain}

      rate_limit? ->
        case Malan.RateLimits.EmailVerification.check_rate(user.id) do
          {:allow, _count} ->
            do_generate_email_verification(user, context, meta)

          {:deny, _limit} ->
            record_email_verification_event(user, Map.merge(meta, %{event_type: "failed_rate_limited"}))
            {:error, :too_many_requests}
        end

      true ->
        do_generate_email_verification(user, context, meta)
    end
  end

  defp do_generate_email_verification(%User{} = user, _context, meta) do
    user
    |> User.email_verification_create_changeset()
    |> Repo.update()
    |> case do
      {:ok, %User{} = updated} ->
        record_email_verification_event(
          updated,
          Map.merge(meta, %{
            event_type: "requested",
            token_hash: updated.email_verification_token_hash
          })
        )

        {:ok, updated}

      {:error, cs} ->
        {:error, cs}
    end
  end

  @doc """
  Atomically verify an email using a raw token. Clears the token fields and
  sets `email_verified` in the same write, so only one of N concurrent verifies
  can win.

  Returns:
    {:ok, %User{}}                           - success
    {:error, :failed_invalid_token}
    {:error, :failed_expired_token}
  """
  def verify_email_with_token(user_or_id, token, opts \\ [])

  def verify_email_with_token(nil, _token, _opts), do: {:error, :failed_invalid_token}

  def verify_email_with_token(user_id, token, opts) when is_binary(user_id) do
    case get_user(user_id) do
      nil -> {:error, :failed_invalid_token}
      user -> verify_email_with_token(user, token, opts)
    end
  end

  def verify_email_with_token(%User{} = user, token, opts) do
    now = Utils.DateTime.utc_now_trunc()
    token_hash = Utils.Crypto.hash_token(token)
    meta = Keyword.get(opts, :meta, %{})

    query =
      from u in User,
        where:
          u.id == ^user.id and
            u.email_verification_token_hash == ^token_hash and
            u.email_verification_token_expires_at > ^now,
        update: [
          set: [
            email_verified: ^now,
            email_verification_token_hash: nil,
            email_verification_token_expires_at: nil,
            updated_at: ^now
          ]
        ]

    case Repo.update_all(query, []) do
      {1, _} ->
        updated = get_user(user.id)

        record_email_verification_event(
          updated,
          Map.merge(meta, %{event_type: "verified", token_hash: token_hash})
        )

        {:ok, updated}

      {0, _} ->
        # Did not match. Classify via follow-up read (best-effort).
        current = get_user(user.id) || user

        reason =
          cond do
            current.email_verification_token_hash == token_hash and
                not is_nil(current.email_verification_token_expires_at) and
                Utils.DateTime.expired?(current.email_verification_token_expires_at) ->
              :failed_expired_token

            true ->
              :failed_invalid_token
          end

        record_email_verification_event(
          current,
          Map.merge(meta, %{
            event_type: Atom.to_string(reason),
            token_hash: token_hash
          })
        )

        {:error, reason}
    end
  end

  @doc """
  Admin helper: set `email_verified` directly.

  `value` is a boolean-ish toggle:
    - truthy -> sets to now
    - falsy -> clears

  Clears any in-flight verification token in the same write. Writes an
  `:admin_set` audit row (caller may pass :ip / :user_agent via `opts[:meta]`).
  """
  def set_email_verified(user_or_id, value, opts \\ [])

  def set_email_verified(user_id, value, opts) when is_binary(user_id) do
    case get_user(user_id) do
      nil -> {:error, :not_found}
      user -> set_email_verified(user, value, opts)
    end
  end

  def set_email_verified(%User{} = user, value, opts) do
    meta = Keyword.get(opts, :meta, %{})

    user
    |> User.admin_email_verified_changeset(value)
    |> Repo.update()
    |> case do
      {:ok, %User{} = updated} ->
        record_email_verification_event(
          updated,
          Map.merge(meta, %{event_type: "admin_set"})
        )

        {:ok, updated}

      {:error, cs} ->
        {:error, cs}
    end
  end

  @doc """
  Write an audit row to `email_verification_events`. `attrs` may include:
    - :event_type (required)
    - :token_hash
    - :ip
    - :user_agent

  The `user.id` and `user.email` are snapshotted automatically.
  """
  def record_email_verification_event(%User{} = user, attrs) do
    attrs =
      attrs
      |> normalize_event_attrs()
      |> Map.put("user_id", user.id)
      |> Map.put("email", user.email)

    %EmailVerificationEvent{}
    |> EmailVerificationEvent.create_changeset(attrs)
    |> Repo.insert()
  end

  defp normalize_event_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn {k, v} -> {to_string(k), v} end)
  end
end
