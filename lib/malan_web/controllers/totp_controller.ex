defmodule MalanWeb.TotpController do
  @moduledoc """
  Owner + admin endpoints for TOTP multi-factor authentication.

  TOTP is a per-user singleton addressed only by the path's `user_id`
  (UUID, username, or `current`), so `is_owner_or_admin` in the pipeline is
  sufficient and the `EnsureOwnerOrAdmin` record-loader is deliberately
  skipped — the record is fetched *by* `user_id`, so the record's owner and
  the path's user are the same value by construction. Any future TOTP
  sub-resource addressed by its own id must add the loader back (see the
  warning in `MalanWeb.Router`).

  Re-auth (MFA_PLAN.md Decision 3): enroll start requires `password`;
  disable and backup-code regeneration require `password` + a valid TOTP or
  backup code; confirm requires only the code (enroll start demanded the
  password moments earlier); admin force-disable requires neither (recovery
  path, heavily audit-logged).
  """

  use MalanWeb, {:controller, formats: [:json], layouts: []}

  import Malan.Utils.Phoenix.Controller, only: [remote_ip_s: 1]
  import Malan.AuthController, only: [authed_session_id: 1]

  alias Malan.Accounts
  alias Malan.Accounts.User

  alias MalanWeb.ErrorJSON

  action_fallback MalanWeb.FallbackController

  # GET /api/users/:user_id/totp
  #
  # Status only — never the secret, otpauth URI, or QR code. Only the
  # password-gated POST may disclose those; re-reading them here would let
  # a stolen bearer token bypass the password gate on enrollment.
  def show(conn, %{"user_id" => user_id}) do
    with_path_user(conn, user_id, fn conn, user ->
      render(conn, :show, code: 200, status: Accounts.totp_status(user))
    end)
  end

  # POST /api/users/:user_id/totp  (body: password)
  def create(conn, %{"user_id" => user_id} = params) do
    with_path_user(conn, user_id, fn conn, user ->
      case Accounts.start_totp_enrollment(user, params["password"], remote_ip_s(conn)) do
        {:ok, enrollment} ->
          conn
          |> put_status(:created)
          |> render(:enrollment, code: 201, enrollment: enrollment)

        {:error, reason} ->
          totp_error(conn, reason)
      end
    end)
  end

  # PUT /api/users/:user_id/totp/confirm  (body: code)
  def confirm(conn, %{"user_id" => user_id} = params) do
    with_path_user(conn, user_id, fn conn, user ->
      case Accounts.confirm_totp_enrollment(
             user,
             params["code"],
             remote_ip_s(conn),
             authed_session_id(conn)
           ) do
        {:ok, backup_codes} ->
          render(conn, :backup_codes, code: 200, backup_codes: backup_codes)

        {:error, reason} ->
          totp_error(conn, reason)
      end
    end)
  end

  # POST /api/users/:user_id/totp/disable  (body: password, code)
  #
  # POST rather than DELETE because it needs a request body and DELETE
  # bodies are dropped by several HTTP clients and intermediaries.
  def disable(conn, %{"user_id" => user_id} = params) do
    with_path_user(conn, user_id, fn conn, user ->
      case Accounts.disable_totp(
             user,
             params["password"],
             params["code"],
             remote_ip_s(conn),
             authed_session_id(conn)
           ) do
        {:ok, :disabled} ->
          render(conn, :show, code: 200, status: Accounts.totp_status(user))

        {:error, reason} ->
          totp_error(conn, reason)
      end
    end)
  end

  # POST /api/users/:user_id/totp/backup_codes  (body: password, code)
  def regenerate_backup_codes(conn, %{"user_id" => user_id} = params) do
    with_path_user(conn, user_id, fn conn, user ->
      case Accounts.regenerate_totp_backup_codes(
             user,
             params["password"],
             params["code"],
             remote_ip_s(conn)
           ) do
        {:ok, backup_codes} ->
          render(conn, :backup_codes, code: 200, backup_codes: backup_codes)

        {:error, reason} ->
          totp_error(conn, reason)
      end
    end)
  end

  # DELETE /api/admin/users/:id/totp — admin recovery path (:admin_api)
  def admin_delete(conn, %{"id" => user_id}) do
    admin = Accounts.get_user(conn.assigns.authed_user_id)

    with_path_user(conn, user_id, fn conn, user ->
      case Accounts.admin_disable_totp(admin, user, remote_ip_s(conn)) do
        {:ok, :disabled} ->
          render(conn, :show, code: 200, status: Accounts.totp_status(user))

        {:error, reason} ->
          totp_error(conn, reason)
      end
    end)
  end

  defp with_path_user(conn, user_id, fun) do
    case resolve_path_user(conn, user_id) do
      %User{} = user -> fun.(conn, user)
      nil -> render_error(conn, 404, :"404", [])
    end
  end

  defp resolve_path_user(conn, "current"), do: Accounts.get_user(conn.assigns.authed_user_id)

  defp resolve_path_user(_conn, id_or_username),
    do: Accounts.get_user_by_id_or_username(id_or_username)

  defp totp_error(conn, :too_many_requests), do: render_error(conn, 429, :"429", [])

  defp totp_error(conn, :email_not_verified) do
    render_error(conn, 403, :"403",
      message:
        "Your email address must be verified before multi-factor authentication can be enabled."
    )
  end

  # Bad password re-auth: generic 403 (distinct from the invalid_mfa_code
  # body so a legitimate client knows which field to fix; both guess types
  # are bounded by the shared TotpVerify budget)
  defp totp_error(conn, :unauthorized) do
    render_error(conn, 403, :"403", message: "The supplied password was incorrect.")
  end

  # :invalid_code (confirm) and :invalid_mfa_code (disable/regenerate) are
  # one wire response; the atoms only record which context raised it
  defp totp_error(conn, invalid) when invalid in [:invalid_code, :invalid_mfa_code] do
    render_error(conn, 403, :"403", invalid_mfa_code: true)
  end

  defp totp_error(conn, no_totp) when no_totp in [:no_pending_enrollment, :no_totp_enabled] do
    render_error(conn, 404, :"404", [])
  end

  defp totp_error(conn, :totp_already_enabled), do: render_error(conn, 409, :"409", [])

  defp render_error(conn, status, template, assigns) do
    conn
    |> put_status(status)
    |> put_view(ErrorJSON)
    |> render(template, assigns)
  end
end
