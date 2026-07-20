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
  alias Malan.Accounts.TotpBackupCode
  alias Malan.Accounts.TotpCipher
  alias Malan.Accounts.UserTotp
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
      {:ok, %User{}, %Ecto.Changeset{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  # Returns `{:ok, user, changeset}` on success so callers can reuse the same
  # changeset for audit logging without rebuilding it. Rebuilding re-runs
  # `put_pass_hash`, which doubles the Pbkdf2 cost when registration includes
  # a password.
  def register_user(attrs \\ %{}) do
    changeset = User.registration_changeset(%User{}, attrs)

    case Repo.insert(changeset) do
      {:ok, user} -> {:ok, user, changeset}
      {:error, _} = err -> err
    end
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

    with {:ok, updated, changeset} <- update_usr(user, attrs, rip, opts),
         {:ok, _num_revoked} <- revoke_active_sessions(updated, rip) do
      maybe_send_email_change_verification(updated, original_email, rip)
      {:ok, updated, changeset}
    end
  end

  def update_user(%User{} = user, attrs, rip, opts) do
    original_email = user.email

    case update_usr(user, attrs, rip, opts) do
      {:ok, updated, changeset} ->
        maybe_send_email_change_verification(updated, original_email, rip)
        {:ok, updated, changeset}

      other ->
        other
    end
  end

  defp maybe_send_email_change_verification(%User{} = updated, original_email, rip) do
    if is_binary(original_email) and original_email != updated.email do
      meta = %{ip: rip}

      case generate_email_verification(updated,
             rate_limit?: true,
             context: :email_change,
             meta: meta
           ) do
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

  Returns {:ok, %User{}, %Ecto.Changeset{}} on success.
  The returned changeset is the one that produced the persisted user, so the
  audit log can record the actual token hash that was stored.

  Returns {:error, %Ecto.Changeset{}} on failure or
          {:error, :too_many_requests} on hitting rate limit
  """
  def generate_password_reset(%User{} = user) do
    # case Malan.RateLimits.PasswordReset.LowerLimit.check_rate(user.id) do
    case Malan.RateLimits.PasswordReset.check_rate(user.id) do
      {:allow, _count} ->
        generate_password_reset(user, :no_rate_limit)

      {:deny, _limit} ->
        {:error, :too_many_requests}

      {:error, _reason} ->
        # Fail-open: a transient Redis disconnect should not lock legitimate
        # users out of password reset. The rate limiter logs the failure.
        generate_password_reset(user, :no_rate_limit)
    end
  end

  @doc ~S"""
  Generates a password reset token that can then be used to reset the user's password.

  Returns {:ok, %User{}, %Ecto.Changeset{}} on success or
          {:error, %Ecto.Changeset{}} on failure.
  """
  def generate_password_reset(%User{} = user, :no_rate_limit) do
    changeset = User.password_reset_create_changeset(user)

    case Repo.update(changeset) do
      {:ok, user} -> {:ok, user, changeset}
      {:error, _} = err -> err
    end
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
         {:ok, %User{} = user, _cs} <- update_user_password(orig_user, new_password, rip) do
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
         {:ok, %User{} = user, _cs} <- admin_update_password(orig_user, new_password, rip) do
      {:ok, user}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def admin_reset_password_with_token(id, token, new_password, rip),
    do: admin_reset_password_with_token(get_user(id), token, new_password, rip)

  # "private utility for the update_user funcs.  Use a public update_user()"
  # Returns `{:ok, user, changeset}` on success so the public update_user
  # functions can hand the changeset back to callers without rebuilding it.
  defp update_usr(user, attrs, remote_ip, opts) do
    changeset = User.update_changeset(user, Map.merge(attrs, %{"remote_ip" => remote_ip}), opts)

    case Repo.update(changeset) do
      {:ok, updated} -> {:ok, updated, changeset}
      {:error, _} = err -> err
    end
  end

  @doc ""
  # Returns `{:ok, user, changeset}` on success so callers can reuse the
  # same changeset (e.g. for audit logging) without rebuilding it.
  # Rebuilding re-runs `put_pass_hash` and doubles the Pbkdf2 cost when
  # `attrs` contains a password.
  def admin_update_user(user, attrs) do
    original_email = user.email
    admin_email_verified_toggle = extract_admin_email_verified_toggle(attrs)
    changeset = User.admin_changeset(user, attrs)

    case Repo.update(changeset) do
      {:ok, updated} ->
        case admin_email_verified_toggle do
          :unset ->
            maybe_send_email_change_verification(updated, original_email, dummy_ip())
            {:ok, updated, changeset}

          value ->
            case set_email_verified(updated, value, meta: %{}) do
              {:ok, user_with_toggle} -> {:ok, user_with_toggle, changeset}
              other -> other
            end
        end

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
        where: is_nil(s.revoked_at) and s.expires_at > ^DateTime.utc_now(),
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
    case authenticate_by_username_pass_with_id(username, given_pass, remote_ip) do
      {:error, reason, _user_id} -> {:error, reason}
      other -> other
    end
  end

  # Like authenticate_by_username_pass/3, but failures for a known user
  # return {:error, reason, user_id} so create_session/4 can log the failed
  # attempt without re-resolving username -> id with an extra SELECT.
  # {:error, :not_a_user} and {:error, :too_many_requests} carry no id.
  #
  # The per-IP limit is checked before the per-username limit and before
  # any DB work: spraying random usernames gets a fresh per-username
  # bucket on every attempt (each burning a full-cost PBKDF2 verify, even
  # for nonexistent users), but every attempt from one source shares this
  # bucket. remote_ip is the CloudflareRealIp/RealIp-resolved client
  # address on all login surfaces.
  #
  # Both limiters fail-open on {:error, _}: a transient Redis disconnect
  # should not block logins (the limiter logs the failure). Login still
  # requires correct credentials, so fail-open is bounded.
  defp authenticate_by_username_pass_with_id(username, given_pass, remote_ip) do
    case Malan.RateLimits.Login.PerIp.check_rate(remote_ip) do
      {:deny, _limit} ->
        {:error, :too_many_requests}

      _allow_or_error ->
        check_username_rate_and_authenticate(username, given_pass, remote_ip)
    end
  end

  defp check_username_rate_and_authenticate(username, given_pass, remote_ip) do
    case Malan.RateLimits.Login.check_rate(username) do
      {:deny, _limit} ->
        {:error, :too_many_requests}

      _allow_or_error ->
        case get_user_id_pass_hash_by_username(username) do
          {user_id, password_hash, nil, approved_ips} ->
            verify_pass(user_id, given_pass, password_hash, approved_ips, remote_ip)
            |> attach_user_id(user_id)

          {user_id, password_hash, locked_at, _} ->
            verify_pass_locked(user_id, given_pass, password_hash, locked_at)
            |> attach_user_id(user_id)

          nil ->
            fake_pass_verify(:not_a_user)
        end
    end
  end

  defp attach_user_id({:ok, user_id}, _user_id), do: {:ok, user_id}
  defp attach_user_id({:error, reason}, user_id), do: {:error, reason, user_id}

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
    case get_user!(user_id) |> update_user(%{"accept_tos" => accept_tos}) do
      {:ok, user, _cs} -> {:ok, user}
      other -> other
    end
  end

  @doc "Accepts the Terms of Service for the user.  Returns {:ok, user}"
  def user_accept_tos(user_id), do: user_tos(true, user_id)

  @doc "Rejects the Terms of Service for the user.  Returns {:ok, user}"
  def user_reject_tos(user_id), do: user_tos(false, user_id)

  def user_set_privacy_policy(accept_privacy_policy, user_id) do
    # TODO don't retrieve the entire user.
    # Just generate update sql that replaces only the part we want to replace
    case get_user!(user_id) |> update_user(%{"accept_privacy_policy" => accept_privacy_policy}) do
      {:ok, user, _cs} -> {:ok, user}
      other -> other
    end
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
    # Failure tuples carry the user_id resolved during authentication, so
    # the record_create_session_* helpers are called with the id directly
    # and skip their username_to_id/1 lookup (an extra SELECT on the
    # unauthenticated failed-login path). :not_a_user logs a nil user_id —
    # we already know there is no matching user.
    case authenticate_by_username_pass_with_id(username, pass, remote_ip) do
      {:ok, user_id} ->
        check_totp_and_create_session(user_id, username, remote_ip, attrs)

      {:error, :user_locked, user_id} ->
        record_create_session_locked(user_id, remote_ip, attrs, username)

      {:error, :ip_addr, user_id} ->
        record_create_session_bad_ip(user_id, remote_ip, attrs, username)

      {:error, :unauthorized, user_id} ->
        record_create_session_unauthorized(user_id, remote_ip, attrs, username)

      {:error, :not_a_user} ->
        record_create_session_not_a_user(nil, remote_ip, attrs, username)

      {:error, :too_many_requests} ->
        {:error, :too_many_requests}
    end
  end

  # Runs after authenticate_by_username_pass_with_id/3 succeeds, so lock,
  # rate-limit, and password semantics are untouched. Only a *confirmed*
  # TOTP enrollment gates login; with none, a stray totp_code in attrs is
  # dropped harmlessly by the Session changeset's cast.
  defp check_totp_and_create_session(user_id, username, remote_ip, attrs) do
    case get_confirmed_user_totp(user_id) do
      nil ->
        new_session(user_id, remote_ip, attrs)

      %UserTotp{} = totp ->
        verify_totp_and_create_session(totp, user_id, username, remote_ip, attrs)
    end
  end

  defp verify_totp_and_create_session(totp, user_id, username, remote_ip, attrs) do
    code = normalize_code(Map.get(attrs, "totp_code") || Map.get(attrs, :totp_code))

    if code == "" do
      # Correct password, no code supplied (or one that normalized away).
      # Distinct audit event from a wrong guess, and no TotpVerify charge —
      # nothing was guessed.
      record_create_session_mfa_required(user_id, remote_ip, attrs, username)
    else
      with :ok <- check_totp_rate(user_id),
           {:ok, _method} <- verify_totp_or_backup(user_id, username, totp, code, remote_ip) do
        clear_totp_rate(user_id)
        new_session(user_id, remote_ip, attrs)
      else
        {:error, :too_many_requests} = err ->
          err

        {:error, :invalid_mfa_code} ->
          record_create_session_invalid_mfa_code(user_id, remote_ip, attrs, username)
      end
    end
  end

  @doc """
  Record failed session creation attempt: the password was correct but the
  user has MFA enabled and supplied no code.

  Returns {:error, :mfa_required}
  """
  def record_create_session_mfa_required(user_id, remote_ip, attrs, username \\ nil) do
    record_log(
      false,
      user_id,
      nil,
      user_id,
      username,
      "sessions",
      "POST",
      "#Accounts.record_create_session_mfa_required/4 - Login attempt for user '#{user_id}' from IP '#{remote_ip}' supplied a correct password but no multi-factor authentication code (MFA is required):  #{Utils.map_to_string(attrs, [:password, :totp_code])}",
      remote_ip,
      %{}
    )

    {:error, :mfa_required}
  end

  @doc """
  Record failed session creation attempt: the password was correct but the
  supplied MFA code was rejected.

  Returns {:error, :invalid_mfa_code}
  """
  def record_create_session_invalid_mfa_code(user_id, remote_ip, attrs, username \\ nil) do
    record_log(
      false,
      user_id,
      nil,
      user_id,
      username,
      "sessions",
      "POST",
      "#Accounts.record_create_session_invalid_mfa_code/4 - Login attempt for user '#{user_id}' from IP '#{remote_ip}' supplied a correct password but an invalid multi-factor authentication code:  #{Utils.map_to_string(attrs, [:password, :totp_code])}",
      remote_ip,
      %{}
    )

    {:error, :invalid_mfa_code}
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
          "#Accounts.record_create_session_locked/3 - Unauthorized login attempt for user '#{username_or_id}' failed from IP '#{remote_ip}' because user account is locked:  #{Utils.map_to_string(attrs, [:password, :totp_code])}",
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
          "#Accounts.record_create_session_bad_ip/3 - Unauthorized login attempt for user '#{username_or_id}' failed from IP '#{remote_ip}' because IP is not on user's approved list:  #{Utils.map_to_string(attrs, [:password, :totp_code])}",
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
          "#Accounts.record_create_session_unauthorized/3 - Unauthorized login attempt for user '#{username_or_id}' failed from IP '#{remote_ip}':  #{Utils.map_to_string(attrs, [:password, :totp_code])}",
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
          "#Accounts.record_create_session_not_a_user/3 - Unauthorized login attempt for user with ID or username of '#{username_or_id}' (that user does not exist) from IP '#{remote_ip}':  #{Utils.map_to_string(attrs, [:password, :totp_code])}",
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
      {:ok, %Session{}, %Ecto.Changeset{}}

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
          # `valid_only_for_approved_ips` is enforced per-request against
          # the user's *current* `approved_ips` list (not a snapshot from
          # session creation) so revoking an IP from `approved_ips`
          # immediately invalidates any IP-restricted session that was
          # bound to it. See `session_valid?/2`.
          valid_only_for_approved_ips: s.valid_only_for_approved_ips,
          approved_ips: u.approved_ips,
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
          valid_only_for_approved_ips: valid_only_for_approved_ips,
          approved_ips: approved_ips,
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

      # Fail-closed when the session opted into approved-IP restriction:
      # an empty `approved_ips` list rejects every request (`x not in []`
      # is always true), which mirrors the contradictory request the
      # client made (opt-in to a list while the list is empty).
      valid_only_for_approved_ips && remote_ip not in (approved_ips || []) ->
        Logger.info(
          "[session_valid?]: A token marked valid_only_for_approved_ips was used from a non-approved IP. remote_ip: '#{remote_ip}', approved_ips: #{inspect(approved_ips)}"
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

  @doc """
  Like `revoke_active_sessions/2` but spares `session_id_to_keep` — used
  when the user enables/disables MFA from a session they should stay logged
  into (MFA_PLAN.md Decision 4). A nil `session_id_to_keep` revokes all
  active sessions, same as `revoke_active_sessions/2`.
  """
  def revoke_active_sessions_except(user_or_id, remote_ip, session_id_to_keep)

  def revoke_active_sessions_except(user_or_id, remote_ip, nil),
    do: revoke_active_sessions(user_or_id, remote_ip)

  def revoke_active_sessions_except(%User{id: user_id}, remote_ip, session_id_to_keep),
    do: revoke_active_sessions_except(user_id, remote_ip, session_id_to_keep)

  def revoke_active_sessions_except(user_id, remote_ip, session_id_to_keep) do
    {num_revoked, nil} =
      Repo.update_all(
        from(s in Session,
          where: s.user_id == ^user_id and is_nil(s.revoked_at) and s.id != ^session_id_to_keep
        ),
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
      "#Accounts.revoke_active_sessions_except/3 - Revoked #{num_revoked} active sessions for user #{user_id} (spared current session #{session_id_to_keep})",
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
    changeset = Session.revoke_changeset(session, %{revoked_at: datetime})

    case Repo.update(changeset) do
      {:ok, session} -> {:ok, session, changeset}
      {:error, _} = err -> err
    end
  end

  def extend_session(%Session{} = session, attrs, authed_ids \\ %{}) do
    changeset = Session.extend_changeset(session, attrs)

    case Repo.transaction(fn ->
           sec_cs = SessionExtension.create_changeset(changeset, authed_ids)
           sec = Repo.insert!(sec_cs)
           updated = Repo.update!(changeset)
           {updated, sec}
         end) do
      {:ok, {session, ext}} -> {:ok, {session, ext}, changeset}
      {:error, _} = err -> err
    end
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

  defp json_safe(value) when is_atom(value) and not is_boolean(value) and not is_nil(value),
    do: Atom.to_string(value)

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
        record_email_verification_event(
          user,
          Map.merge(meta, %{event_type: "skipped_already_verified"})
        )

        {:ok, :already_verified}

      not Malan.Config.User.email_verification_auto_send?() and
          context in [:welcome, :email_change] ->
        record_email_verification_event(
          user,
          Map.merge(meta, %{event_type: "skipped_auto_send_disabled"})
        )

        {:ok, :skipped_auto_send_disabled}

      User.skip_email_verification_send?(user.email) ->
        record_email_verification_event(user, Map.merge(meta, %{event_type: "skipped_domain"}))
        {:ok, :skipped_domain}

      rate_limit? ->
        rate_limited_generate_email_verification(user, context, meta)

      true ->
        do_generate_email_verification(user, context, meta)
    end
  end

  defp rate_limited_generate_email_verification(%User{} = user, context, meta) do
    case Malan.RateLimits.EmailVerification.check_rate(user.id) do
      {:allow, _count} ->
        do_generate_email_verification(user, context, meta)

      {:deny, _limit} ->
        record_email_verification_event(
          user,
          Map.merge(meta, %{event_type: "failed_rate_limited"})
        )

        {:error, :too_many_requests}

      {:error, _reason} ->
        # Fail-open: a transient Redis disconnect should not block email
        # verification sends. The rate limiter logs the failure.
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

  ## TOTP multi-factor authentication

  @totp_period 30
  @totp_backup_code_count 10
  # Exactly 12: the TOTP-vs-backup-code disambiguation is length-based
  # (6 digits vs 12 chars), so this length is load-bearing, not cosmetic.
  @totp_backup_code_length 12

  @doc """
  MFA/TOTP status for a user.

  Returns `%{status: :none | :pending | :enabled, confirmed_at: DateTime.t() | nil,
  backup_codes_remaining: non_neg_integer}`. Never includes the secret,
  otpauth URI, or QR code — only the password-gated `start_totp_enrollment/3`
  may disclose those.
  """
  def totp_status(%User{id: user_id}), do: totp_status(user_id)

  def totp_status(user_id) when is_binary(user_id) do
    case get_user_totp(user_id) do
      nil ->
        %{status: :none, confirmed_at: nil, backup_codes_remaining: 0}

      %UserTotp{confirmed_at: nil} ->
        %{status: :pending, confirmed_at: nil, backup_codes_remaining: 0}

      %UserTotp{confirmed_at: confirmed_at} ->
        %{
          status: :enabled,
          confirmed_at: confirmed_at,
          backup_codes_remaining: count_unused_totp_backup_codes(user_id)
        }
    end
  end

  @doc "True when the user has a confirmed (enabled) TOTP enrollment."
  def totp_enabled?(%User{id: user_id}), do: totp_enabled?(user_id)

  def totp_enabled?(user_id) when is_binary(user_id) do
    from(t in UserTotp, where: t.user_id == ^user_id and not is_nil(t.confirmed_at))
    |> Repo.exists?()
  end

  @doc """
  Start TOTP enrollment for `user`, replacing any pending (unconfirmed)
  enrollment. Requires the user's current `password` (MFA_PLAN.md Decision 3)
  and a verified email address. The returned provisioning payload is shown
  once; the new enrollment stays inert until `confirm_totp_enrollment/4`.

  Returns:

      {:ok, %{secret_base32: b32, otpauth_uri: uri, qr_code_svg: svg}}
      {:error, :email_not_verified | :unauthorized | :totp_already_enabled | :too_many_requests}
  """
  def start_totp_enrollment(%User{} = user, password, remote_ip) do
    with :ok <- check_totp_email_verified(user),
         :ok <- check_totp_rate(user.id),
         :ok <- check_totp_password(user, password),
         :ok <- check_no_confirmed_totp(user.id) do
      do_start_totp_enrollment(user, remote_ip)
    else
      {:error, :unauthorized} = err ->
        record_totp_log(
          false,
          user,
          nil,
          "POST",
          "#Accounts.start_totp_enrollment/3 - Rejected TOTP enrollment start for user '#{user.id}' from IP '#{remote_ip}': bad password",
          remote_ip
        )

        err

      {:error, _reason} = err ->
        err
    end
  end

  defp do_start_totp_enrollment(%User{} = user, remote_ip) do
    secret = NimbleTOTP.secret()
    {key_id, ciphertext} = TotpCipher.encrypt(secret)
    issuer = Malan.Config.Totp.issuer()
    # Label and issuer param must agree so authenticators reading either
    # one show the same entry (Key URI spec).
    otpauth_uri = NimbleTOTP.otpauth_uri("#{issuer}:#{user.username}", secret, issuer: issuer)

    result =
      Repo.transaction(fn ->
        from(t in UserTotp, where: t.user_id == ^user.id and is_nil(t.confirmed_at))
        |> Repo.delete_all()

        case %UserTotp{}
             |> UserTotp.create_changeset(%{user_id: user.id, secret: ciphertext, key_id: key_id})
             |> Repo.insert() do
          {:ok, _totp} ->
            :ok

          # unique_constraint(:user_id): a confirmed row appeared concurrently
          {:error, _changeset} ->
            Repo.rollback(:totp_already_enabled)
        end
      end)

    case result do
      {:ok, :ok} ->
        clear_totp_rate(user.id)

        record_totp_log(
          true,
          user,
          nil,
          "POST",
          "#Accounts.start_totp_enrollment/3 - Started TOTP enrollment for user '#{user.id}' from IP '#{remote_ip}'",
          remote_ip
        )

        {:ok,
         %{
           secret_base32: Base.encode32(secret, padding: false),
           otpauth_uri: otpauth_uri,
           qr_code_svg: otpauth_uri |> EQRCode.encode() |> EQRCode.svg(width: 264)
         }}

      {:error, :totp_already_enabled} = err ->
        err
    end
  end

  @doc """
  Confirm a pending TOTP enrollment with a code from the authenticator.

  On success: marks the enrollment confirmed, seeds the replay guard with
  the accepted step, generates the backup-code set (plaintexts returned
  once, never retrievable again), and revokes all other active sessions —
  `current_session_id` is spared (Decision 4) and `remote_ip` stamps the
  audit trail.

  Takes no password: enrollment start demanded it moments earlier, and a
  bearer-token-only attacker cannot start an enrollment, so cannot reach
  confirm with a secret they control (Decision 8).

  Returns:

      {:ok, [backup_code_plaintexts]}
      {:error, :invalid_code | :no_pending_enrollment | :too_many_requests}
  """
  def confirm_totp_enrollment(%User{} = user, code, remote_ip, current_session_id) do
    code = normalize_code(code)

    with {:totp, %UserTotp{confirmed_at: nil} = totp} <- {:totp, get_user_totp(user.id)},
         :ok <- check_totp_rate(user.id),
         {:ok, secret} <- decrypt_totp_secret(totp),
         {:ok, accepted_ts} <- find_valid_totp_step(secret, code, totp.last_used_ts) do
      do_confirm_totp_enrollment(user, totp, accepted_ts, remote_ip, current_session_id)
    else
      {:totp, _no_pending_row} ->
        {:error, :no_pending_enrollment}

      {:error, :too_many_requests} = err ->
        err

      _invalid_code ->
        record_totp_log(
          false,
          user,
          current_session_id,
          "PUT",
          "#Accounts.confirm_totp_enrollment/4 - Rejected TOTP enrollment confirmation for user '#{user.id}' from IP '#{remote_ip}': invalid code",
          remote_ip
        )

        {:error, :invalid_code}
    end
  end

  defp do_confirm_totp_enrollment(user, totp, accepted_ts, remote_ip, current_session_id) do
    now = Utils.DateTime.utc_now_trunc()

    result =
      Repo.transaction(fn ->
        # CAS on the pending state so exactly one confirm can win
        {count, _} =
          from(t in UserTotp, where: t.id == ^totp.id and is_nil(t.confirmed_at))
          |> Repo.update_all(set: [confirmed_at: now, last_used_ts: accepted_ts, updated_at: now])

        if count == 1 do
          codes = generate_totp_backup_codes(user.id)
          revoke_active_sessions_except(user, remote_ip, current_session_id)
          codes
        else
          Repo.rollback(:no_pending_enrollment)
        end
      end)

    case result do
      {:ok, codes} ->
        clear_totp_rate(user.id)

        record_totp_log(
          true,
          user,
          current_session_id,
          "PUT",
          "#Accounts.confirm_totp_enrollment/4 - TOTP enabled for user '#{user.id}' from IP '#{remote_ip}'",
          remote_ip
        )

        {:ok, codes}

      {:error, :no_pending_enrollment} = err ->
        err
    end
  end

  @doc """
  Disable TOTP for `user`. Requires the current `password` **and** a valid
  TOTP or backup code (Decision 3: a stolen bearer token must not be able
  to silently strip MFA). Deletes the enrollment and all backup codes, then
  revokes all other active sessions, sparing `current_session_id`.

  Returns:

      {:ok, :disabled}
      {:error, :unauthorized | :invalid_mfa_code | :no_totp_enabled | :too_many_requests}
  """
  def disable_totp(%User{} = user, password, code_or_backup, remote_ip, current_session_id) do
    with {:totp, %UserTotp{confirmed_at: %DateTime{}} = totp} <- {:totp, get_user_totp(user.id)},
         :ok <- check_totp_rate(user.id),
         :ok <- check_totp_password(user, password),
         {:ok, _method} <- verify_totp_or_backup(user, totp, code_or_backup, remote_ip) do
      do_disable_totp(user, remote_ip, current_session_id)
    else
      {:totp, _no_confirmed_row} ->
        {:error, :no_totp_enabled}

      {:error, :too_many_requests} = err ->
        err

      {:error, reason} = err when reason in [:unauthorized, :invalid_mfa_code] ->
        record_totp_log(
          false,
          user,
          current_session_id,
          "POST",
          "#Accounts.disable_totp/5 - Rejected TOTP disable for user '#{user.id}' from IP '#{remote_ip}': #{totp_rejection_reason(reason)}",
          remote_ip
        )

        err
    end
  end

  defp do_disable_totp(%User{} = user, remote_ip, current_session_id) do
    {:ok, :ok} =
      Repo.transaction(fn ->
        from(t in UserTotp, where: t.user_id == ^user.id) |> Repo.delete_all()
        from(bc in TotpBackupCode, where: bc.user_id == ^user.id) |> Repo.delete_all()
        revoke_active_sessions_except(user, remote_ip, current_session_id)
        :ok
      end)

    clear_totp_rate(user.id)

    record_totp_log(
      true,
      user,
      current_session_id,
      "POST",
      "#Accounts.disable_totp/5 - TOTP disabled for user '#{user.id}' from IP '#{remote_ip}'",
      remote_ip
    )

    {:ok, :disabled}
  end

  @doc """
  Admin recovery path: force-disable a user's TOTP without password or code
  (the locked-out user's credentials are unavailable to the admin; heavily
  audit-logged instead). Deletes the enrollment and backup codes and
  revokes **all** of the target's active sessions — there is no "current
  session" of the target to spare.

  Returns `{:ok, :disabled}` or `{:error, :no_totp_enabled}` (no-op is an
  error, not a silent success).
  """
  def admin_disable_totp(%User{} = admin, %User{} = user, remote_ip) do
    case get_user_totp(user.id) do
      %UserTotp{confirmed_at: %DateTime{}} ->
        {:ok, :ok} =
          Repo.transaction(fn ->
            from(t in UserTotp, where: t.user_id == ^user.id) |> Repo.delete_all()
            from(bc in TotpBackupCode, where: bc.user_id == ^user.id) |> Repo.delete_all()
            revoke_active_sessions(user, remote_ip)
            :ok
          end)

        record_log(
          true,
          admin.id,
          nil,
          user.id,
          user.username,
          "users",
          "DELETE",
          "#Accounts.admin_disable_totp/3 - TOTP force-disabled for user '#{user.id}' by admin '#{admin.id}' ('#{admin.username}') from IP '#{remote_ip}'",
          remote_ip,
          %{}
        )

        {:ok, :disabled}

      _no_confirmed_row ->
        {:error, :no_totp_enabled}
    end
  end

  @doc """
  Invalidate the user's entire backup-code set and mint a fresh one.
  Requires the current `password` **and** a valid TOTP or backup code
  (Decision 8: regenerating is a security-state change — it must not be
  reachable with a bearer token alone). Plaintexts are returned once.

  Returns:

      {:ok, [backup_code_plaintexts]}
      {:error, :unauthorized | :invalid_mfa_code | :no_totp_enabled | :too_many_requests}
  """
  def regenerate_totp_backup_codes(%User{} = user, password, code_or_backup, remote_ip) do
    with {:totp, %UserTotp{confirmed_at: %DateTime{}} = totp} <- {:totp, get_user_totp(user.id)},
         :ok <- check_totp_rate(user.id),
         :ok <- check_totp_password(user, password),
         {:ok, _method} <- verify_totp_or_backup(user, totp, code_or_backup, remote_ip) do
      {:ok, codes} = Repo.transaction(fn -> generate_totp_backup_codes(user.id) end)
      clear_totp_rate(user.id)

      record_totp_log(
        true,
        user,
        nil,
        "POST",
        "#Accounts.regenerate_totp_backup_codes/4 - Regenerated TOTP backup codes for user '#{user.id}' from IP '#{remote_ip}'",
        remote_ip
      )

      {:ok, codes}
    else
      {:totp, _no_confirmed_row} ->
        {:error, :no_totp_enabled}

      {:error, :too_many_requests} = err ->
        err

      {:error, reason} = err when reason in [:unauthorized, :invalid_mfa_code] ->
        record_totp_log(
          false,
          user,
          nil,
          "POST",
          "#Accounts.regenerate_totp_backup_codes/4 - Rejected TOTP backup code regeneration for user '#{user.id}' from IP '#{remote_ip}': #{totp_rejection_reason(reason)}",
          remote_ip
        )

        err
    end
  end

  @doc false
  # Public only so tests can pin the CAS semantics; not part of the context API.
  #
  # `accepted_ts` must be the accepted step's START (`div(t, 30) * 30`), not
  # the raw second: the guard's `<` is then step-granular, so two requests
  # carrying the same code at different seconds of one step cannot both win.
  # Nil-safe so replay protection cannot silently disengage if the confirm
  # seed were ever missed.
  def cas_totp_last_used_ts(%UserTotp{} = totp, accepted_ts) do
    {count, _} =
      from(t in UserTotp,
        where: t.id == ^totp.id and (is_nil(t.last_used_ts) or t.last_used_ts < ^accepted_ts)
      )
      |> Repo.update_all(
        set: [last_used_ts: accepted_ts, updated_at: Utils.DateTime.utc_now_trunc()]
      )

    # Zero rows updated ⇒ a concurrent request already spent this step;
    # the CAS loser must NOT be handed a session.
    if count == 1, do: :ok, else: {:error, :invalid_mfa_code}
  end

  # Verify a client-supplied TOTP or backup code (already-confirmed
  # enrollments only). Disambiguates on normalized length: 6 -> TOTP,
  # 12 -> backup code, anything else is invalid without consulting either
  # verifier. Returns {:ok, :totp | :backup_code} | {:error, :invalid_mfa_code}.
  defp verify_totp_or_backup(%User{} = user, %UserTotp{} = totp, input, remote_ip),
    do: verify_totp_or_backup(user.id, user.username, totp, input, remote_ip)

  # Arity-5 variant for the login path, which has only the id and the
  # client-supplied username (no %User{} loaded).
  defp verify_totp_or_backup(user_id, username, %UserTotp{} = totp, input, remote_ip) do
    code = normalize_code(input)

    cond do
      byte_size(code) == 6 ->
        verify_totp_code(totp, code)

      byte_size(code) == @totp_backup_code_length ->
        spend_totp_backup_code(user_id, username, code, remote_ip)

      true ->
        {:error, :invalid_mfa_code}
    end
  end

  defp verify_totp_code(%UserTotp{} = totp, code) do
    with {:ok, secret} <- decrypt_totp_secret(totp),
         {:ok, accepted_ts} <- find_valid_totp_step(secret, code, totp.last_used_ts) do
      cas_totp_last_used_ts(totp, accepted_ts)
      |> case do
        :ok -> {:ok, :totp}
        {:error, :invalid_mfa_code} = err -> err
      end
    else
      _ -> {:error, :invalid_mfa_code}
    end
  end

  # Accept the current or previous 30s step (clock-drift tolerance;
  # NimbleTOTP.valid?/3 checks a single period, so the grace period is two
  # calls). `since:` rejects any step at or below the stored one, which
  # covers sequential replay including walking the drift window backwards.
  # Returns the accepted step's START, which the CAS stores.
  defp find_valid_totp_step(secret, code, since) do
    now = System.os_time(:second)

    [now, now - @totp_period]
    |> Enum.find_value(fn t -> NimbleTOTP.valid?(secret, code, time: t, since: since) && t end)
    |> case do
      nil -> {:error, :invalid_mfa_code}
      t -> {:ok, div(t, @totp_period) * @totp_period}
    end
  end

  # Constant-time match of the normalized input against the user's unused
  # backup codes, then single-use spend with the same zero-rows-means-fail
  # shape as the TOTP CAS (two concurrent logins must not each spend the
  # same code once).
  defp spend_totp_backup_code(user_id, username, code, remote_ip) do
    hash = Utils.Crypto.hash_token(code)
    now = Utils.DateTime.utc_now_trunc()

    matched =
      from(bc in TotpBackupCode, where: bc.user_id == ^user_id and is_nil(bc.used_at))
      |> Repo.all()
      |> Enum.find(fn bc -> Utils.Crypto.secure_compare(bc.code_hash, hash) end)

    with %TotpBackupCode{} = backup_code <- matched,
         {1, _} <-
           from(bc in TotpBackupCode, where: bc.id == ^backup_code.id and is_nil(bc.used_at))
           |> Repo.update_all(set: [used_at: now, updated_at: now]) do
      remaining = count_unused_totp_backup_codes(user_id)

      record_totp_log(
        true,
        user_id,
        username,
        nil,
        "POST",
        "#Accounts.spend_totp_backup_code/4 - TOTP backup code consumed for user '#{user_id}' from IP '#{remote_ip}' (#{remaining} unused codes remain)",
        remote_ip
      )

      {:ok, :backup_code}
    else
      # nil: no unused code matches. {0, _}: concurrent spend of this code.
      _ -> {:error, :invalid_mfa_code}
    end
  end

  # Delete any existing codes and mint a fresh set. Hashes the *normalized*
  # plaintext so generation and verification cannot drift (Decision 6).
  defp generate_totp_backup_codes(user_id) do
    from(bc in TotpBackupCode, where: bc.user_id == ^user_id) |> Repo.delete_all()

    now = Utils.DateTime.utc_now_trunc()

    codes =
      for _ <- 1..@totp_backup_code_count do
        Utils.Crypto.strong_random_string(@totp_backup_code_length)
      end

    rows =
      Enum.map(codes, fn code ->
        %{
          id: Ecto.UUID.generate(),
          user_id: user_id,
          code_hash: Utils.Crypto.hash_token(normalize_code(code)),
          used_at: nil,
          inserted_at: now,
          updated_at: now
        }
      end)

    {@totp_backup_code_count, _} = Repo.insert_all(TotpBackupCode, rows)

    codes
  end

  defp decrypt_totp_secret(%UserTotp{} = totp) do
    case TotpCipher.decrypt(totp.secret, totp.key_id) do
      {:ok, secret} ->
        {:ok, secret}

      :error ->
        # Fail closed: MFA cannot be satisfied until the keyring is fixed or
        # the user re-enrolls. Loud because it is an operator problem
        # (TOTP_ENCRYPTION_KEYS lost a still-referenced key), not a user one.
        Logger.error(
          "Cannot decrypt TOTP secret for user_totps row #{totp.id}: key_id #{totp.key_id} failed to decrypt (missing from TOTP_ENCRYPTION_KEYS?)"
        )

        {:error, :invalid_mfa_code}
    end
  end

  # Decision 6: strip whitespace and hyphens only, before the length
  # disambiguation — never case-fold (backup codes are mixed-case, and
  # downcasing would shed ~10 bits of entropy). Integers are accepted
  # because JSON clients may send `totp_code` as a number; anything else
  # normalizes to "" and reads as absent.
  defp normalize_code(input) when is_binary(input), do: String.replace(input, ~r/[\s-]/, "")

  defp normalize_code(input) when is_integer(input),
    do: input |> Integer.to_string() |> normalize_code()

  defp normalize_code(_other), do: ""

  defp get_user_totp(user_id), do: Repo.get_by(UserTotp, user_id: user_id)

  defp get_confirmed_user_totp(user_id) do
    Repo.one(from(t in UserTotp, where: t.user_id == ^user_id and not is_nil(t.confirmed_at)))
  end

  defp count_unused_totp_backup_codes(user_id) do
    from(bc in TotpBackupCode, where: bc.user_id == ^user_id and is_nil(bc.used_at))
    |> Repo.aggregate(:count)
  end

  defp check_totp_email_verified(%User{email_verified: %DateTime{}}), do: :ok
  defp check_totp_email_verified(%User{}), do: {:error, :email_not_verified}

  defp check_no_confirmed_totp(user_id) do
    case get_user_totp(user_id) do
      %UserTotp{confirmed_at: %DateTime{}} -> {:error, :totp_already_enabled}
      _nil_or_pending -> :ok
    end
  end

  defp check_totp_password(%User{password_hash: hash}, password)
       when is_binary(password) and is_binary(hash) do
    if Utils.Crypto.verify_password(password, hash) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp check_totp_password(%User{}, _password), do: fake_pass_verify(:unauthorized)

  # One shared per-user budget for every attempt to prove yourself at a
  # TOTP endpoint, password or code (see Malan.RateLimits.TotpVerify).
  # Fail-open on limiter errors, matching the login limiters: passing
  # still requires a correct password/code.
  defp check_totp_rate(user_id) do
    case Malan.RateLimits.TotpVerify.check_rate(user_id) do
      {:deny, _limit} -> {:error, :too_many_requests}
      _allow_or_error -> :ok
    end
  end

  # A correct password/code should not leave the user throttled by their
  # own earlier typos; only success clears.
  defp clear_totp_rate(user_id) do
    Malan.RateLimits.TotpVerify.clear(user_id)
    :ok
  end

  defp totp_rejection_reason(:unauthorized), do: "bad password"
  defp totp_rejection_reason(:invalid_mfa_code), do: "invalid code"

  defp record_totp_log(success?, %User{} = user, session_id, verb, what, remote_ip),
    do: record_totp_log(success?, user.id, user.username, session_id, verb, what, remote_ip)

  defp record_totp_log(success?, user_id, username, session_id, verb, what, remote_ip) do
    record_log(
      success?,
      user_id,
      session_id,
      user_id,
      username,
      "users",
      verb,
      what,
      remote_ip,
      %{}
    )
  end

  @doc """
  Re-encrypt every `user_totps.secret` stored under a non-primary
  `TotpCipher` key onto the primary (first) `TOTP_ENCRYPTION_KEYS` entry.

  Key-rotation step 3: add the new key as the first entry (keeping the
  old), deploy, run this via `Malan.Release.reencrypt_totp_secrets/0`,
  then remove the old key. Idempotent and resumable: rows already on the
  primary key are never touched, and each row is re-keyed with a
  compare-and-set on its old `key_id`, so a concurrent run cannot
  double-write.

  Returns `%{reencrypted: n, skipped: n, failed: n}`. `:skipped` rows were
  re-keyed by another writer between read and update; `:failed` rows have a
  `key_id` absent from the keyring (undecryptable — see MFA_PLAN.md on key
  loss) and are left in place and logged.
  """
  def reencrypt_totp_secrets do
    primary_key_id = TotpCipher.primary_key_id()

    from(t in UserTotp, where: t.key_id != ^primary_key_id)
    |> Repo.all()
    |> Enum.reduce(%{reencrypted: 0, skipped: 0, failed: 0}, fn totp, acc ->
      key = reencrypt_totp_row(totp)
      Map.update!(acc, key, &(&1 + 1))
    end)
  end

  defp reencrypt_totp_row(%UserTotp{} = totp) do
    case TotpCipher.decrypt(totp.secret, totp.key_id) do
      {:ok, plaintext} ->
        {new_key_id, ciphertext} = TotpCipher.encrypt(plaintext)

        {count, _} =
          from(t in UserTotp, where: t.id == ^totp.id and t.key_id == ^totp.key_id)
          |> Repo.update_all(
            set: [
              secret: ciphertext,
              key_id: new_key_id,
              updated_at: Utils.DateTime.utc_now_trunc()
            ]
          )

        if count == 1, do: :reencrypted, else: :skipped

      :error ->
        Logger.warning(
          "reencrypt_totp_secrets: user_totps row #{totp.id} has key_id #{totp.key_id} " <>
            "which is not in TOTP_ENCRYPTION_KEYS; row left unchanged"
        )

        :failed
    end
  end
end
