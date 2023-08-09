defmodule MalanWeb.SessionController do
  use MalanWeb, :controller

  require Logger

  import MalanWeb.PaginationController, only: [require_pagination: 2, pagination_info: 1]
  import Malan.Utils.Phoenix.Controller, only: [remote_ip_s: 1]

  alias Malan.{Accounts, Utils}
  alias Malan.Accounts.{Session, SessionExtension}

  alias MalanWeb.ErrorView

  action_fallback MalanWeb.FallbackController

  plug :require_pagination,
       [default_page_size: 10, max_page_size: 100]
       when action in [:admin_index, :index, :index_active, :user_index_active]

  def admin_index(conn, _params) do
    {page_num, page_size} = pagination_info(conn)
    sessions = Accounts.list_sessions(page_num, page_size)

    render(conn, "index.json",
      code: 200,
      sessions: sessions,
      page_num: page_num,
      page_size: page_size
    )
  end

  def admin_delete(conn, %{"id" => id}) do
    session = Accounts.get_session!(id)

    log_changeset =
      Session.revoke_changeset(session, %{
        revoked_at: DateTime.add(DateTime.utc_now(), -1, :second)
      })

    with {:ok, %Session{} = session} <- Accounts.delete_session(session) do
      record_log(
        conn,
        true,
        session.user_id,
        "DELETE",
        "#SessionController.admin_delete/2",
        log_changeset
      )

      render(conn, "show.json", code: 200, session: session)
    else
      {:error, err_cs} ->
        err_str = Utils.Ecto.Changeset.errors_to_str(err_cs)

        record_log(
          conn,
          false,
          session.user_id,
          "DELETE",
          "#SessionController.admin_delete/2 - Session admin deletion failed: #{err_str}",
          err_cs
        )

        {:error, err_cs}
    end
  end

  def index(conn, %{"user_id" => user_id}) do
    {page_num, page_size} = pagination_info(conn)
    sessions = Accounts.list_sessions(user_id, page_num, page_size)

    render(conn, "index.json",
      code: 200,
      sessions: sessions,
      page_num: page_num,
      page_size: page_size
    )
  end

  def index_active(conn, params) do
    user_index_active(conn, Map.merge(params, %{"user_id" => conn.assigns.authed_user_id}))
  end

  def user_index_active(conn, %{"user_id" => "current"}),
    do: user_index_active(conn, %{"user_id" => conn.assigns.authed_user_id})

  def user_index_active(conn, %{"user_id" => user_id}) do
    {page_num, page_size} = pagination_info(conn)
    sessions = Accounts.list_active_sessions(user_id, page_num, page_size)

    render(conn, "index.json",
      code: 200,
      sessions: sessions,
      page_num: page_num,
      page_size: page_size
    )
  end

  def create(conn, %{
        "session" => %{"username" => username, "password" => password} = session_opts
      }) do
    with {:ok, %Session{} = session} <-
           Accounts.create_session(
             username,
             password,
             remote_ip_s(conn),
             put_ip_addr(session_opts, conn)
           ) do
      record_log(
        Map.update(conn, :assigns, %{}, fn a ->
          Map.merge(a, %{authed_user_id: session.user_id, authed_session_id: session.id})
        end),
        true,
        session.user_id,
        "POST",
        "#SessionController.create/2",
        nil
      )

      conn
      |> put_status(:created)
      |> render("show.json", code: 201, session: session)
    else
      # Logging of failed login attemps (aka session creation) currently happens
      # in accounts.ex
      {:error, :user_locked} ->
        conn
        |> put_status(423)
        |> put_view(ErrorView)
        |> render("423.json")

      # {:error, :not_a_user} ->
      # {:error, :unauthorized} ->
      _err ->
        conn
        |> put_status(403)
        |> put_view(ErrorView)
        |> render("403.json", invalid_credentials: true)
    end
  end

  def show(conn, %{"id" => id}) do
    session = Accounts.get_session!(id)
    render(conn, "show.json", code: 200, session: session)
  end

  def show_current(conn, %{}), do: show(conn, %{"id" => conn.assigns.authed_session_id})

  def extend(conn, attrs = %{"id" => id}) do
    session = Accounts.get_session!(id)

    # Make sure the session being extended isn't revoked or expired
    case Accounts.session_revoked_or_expired?(session) do
      true ->
        conn
        |> put_status(403)
        |> put_view(ErrorView)
        |> render("403.json", session_revoked_or_expired: true)

      false ->
        extend_session(conn, session, attrs)
    end
  end

  def extend_current(conn, attrs),
    do: extend(conn, Map.merge(attrs, %{"id" => conn.assigns.authed_session_id}))

  defp extend_session(conn, session, attrs) do
    authed_ids = %{
      authed_user_id: conn.assigns.authed_user_id,
      authed_session_id: conn.assigns.authed_session_id
    }

    changeset =
      Session.extend_changeset(
        session,
        %{expire_in_seconds: attrs["expire_in_seconds"]}
      )

    with {:ok, {%Session{} = session, %SessionExtension{} = _session_extension}} <- Accounts.extend_session(session, attrs, authed_ids) do
      record_log(
        conn,
        true,
        session.user_id,
        "PUT",
        "#SessionController.extend/2",
        changeset
      )

      render(conn, "show.json", code: 200, session: session)
    else
      {:error, err} ->
        err_str = Utils.Ecto.Changeset.errors_to_str(err)

        record_log(
          conn,
          false,
          session.user_id,
          "PUT",
          "#SessionController.extend/2 - Session extension failed: #{err_str}",
          changeset
        )

        {:error, err}
    end
  end

  def delete(conn, %{"id" => id}) do
    session = Accounts.get_session!(id)

    changeset =
      Session.revoke_changeset(session, %{
        revoked_at: DateTime.add(DateTime.utc_now(), -1, :second)
      })

    with {:ok, %Session{} = session} <- Accounts.delete_session(session) do
      record_log(
        conn,
        true,
        session.user_id,
        "DELETE",
        "#SessionController.delete/2",
        changeset
      )

      render(conn, "show.json", code: 200, session: session)
    else
      {:error, err} ->
        err_str = Utils.Ecto.Changeset.errors_to_str(err)

        record_log(
          conn,
          false,
          session.user_id,
          "DELETE",
          "#SessionController.delete/2 - Session deletion failed: #{err_str}",
          changeset
        )

        {:error, err}
    end
  end

  def delete_current(conn, %{}), do: delete(conn, %{"id" => conn.assigns.authed_session_id})

  def delete_all(conn, %{"user_id" => user_id}) do
    with {:ok, num_revoked} <- Accounts.revoke_active_sessions(user_id) do
      record_log(conn, true, user_id, "DELETE", "#SessionController.delete_all/2", %{
        num_revoked: num_revoked
      })

      render(conn, "delete_all.json", code: 200, num_revoked: num_revoked)
    else
      {:error, err} ->
        err_str = Utils.Ecto.Changeset.errors_to_str(err)

        record_log(
          conn,
          false,
          user_id,
          "DELETE",
          "#SessionController.delete_all/2 - Session delete all active failed: #{err_str}",
          err
        )

        {:error, err}
    end
  end

  defp record_log(conn, success?, who, verb, what, changeset) do
    {user_id, session_id} = authed_user_and_session(conn)

    Accounts.record_log(
      success?,
      user_id,
      session_id,
      who,
      nil,
      "sessions",
      verb,
      what,
      remote_ip_s(conn),
      changeset
    )

    conn
  end

  # # Get Cloudflare Real IP from request header: https://developers.cloudflare.com/fundamentals/get-started/http-request-headers
  # defp get_cf_real_ip_addr(conn) do
  #   case get_req_header(conn, "cf-connecting-ip") do
  #     [real_ip] when is_binary(real_ip) -> real_ip
  #     _ -> nil
  #   end
  # end

  defp put_ip_addr(session_params, conn) do
    session_params
    |> Map.put("ip_address", Utils.IPv4.to_s(conn))

    # |> Map.put("real_ip_address", get_cf_real_ip_addr(conn))
  end
end
