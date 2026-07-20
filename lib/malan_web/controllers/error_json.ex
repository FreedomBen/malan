defmodule MalanWeb.ErrorJSON do
  use MalanWeb, :view

  import MalanWeb.ChangesetJSON, only: [translate_errors: 1]

  def render("400.json", _assigns) do
    %{
      ok: false,
      code: 400,
      detail: "Bad Request",
      message: "The request was very very bad"
    }
  end

  def render("401.json", _assigns) do
    %{
      ok: false,
      code: 401,
      detail: "Unauthorized",
      message: "You are authenticated but do not have access to this method on this object."
    }
  end

  def render("403.json", %{invalid_credentials: true}) do
    %{
      ok: false,
      code: 403,
      detail: "Forbidden",
      message:
        "Username, password and/or location were invalid.  Please verify credentials and try again."
    }
  end

  def render("403.json", %{token_expired: true}) do
    %{
      ok: false,
      code: 403,
      detail: "Forbidden",
      message: "API token is expired or revoked",
      token_expired: true,
      errors: [%{token: ["expired"]}]
    }
  end

  def render("403.json", %{token_revoked: true}) do
    %{
      ok: false,
      code: 403,
      detail: "Forbidden",
      message: "API token is expired or revoked",
      token_revoked: true,
      errors: [%{token: ["revoked"]}]
    }
  end

  def render("403.json", %{session_revoked_or_expired: true}) do
    %{
      ok: false,
      code: 403,
      detail: "Forbidden",
      message: "Session cannot be extended.  It is expired or revoked",
      errors: [%{session: ["revoked_or_expired: true"]}]
    }
  end

  # A code was supplied but rejected. Carries mfa_required/mfa_types as
  # well (the full shape, not a subset) so clients can branch on one key
  # for "needs a code" and read invalid_mfa_code only to distinguish "and
  # the one you sent was wrong". Worded without "credentials" because the
  # authed TOTP endpoints (confirm/disable/regenerate) reuse this body.
  def render("403.json", %{invalid_mfa_code: true}) do
    %{
      ok: false,
      code: 403,
      detail: "Forbidden",
      message:
        "The multi-factor authentication code was invalid or expired.  Re-submit with a current totp_code.",
      mfa_required: true,
      invalid_mfa_code: true,
      mfa_types: ["totp"],
      errors: [%{totp_code: ["invalid"]}]
    }
  end

  # MFA is enabled for the user and no code was supplied. `totp_code`
  # accepts a 6-digit TOTP code or a 12-char backup code; `mfa_types`
  # names the enrolled method (room to add methods without breaking
  # clients). Follows the token_expired precedent: flag repeated in the
  # body plus an errors list.
  def render("403.json", %{mfa_required: true}) do
    %{
      ok: false,
      code: 403,
      detail: "Forbidden",
      message:
        "Multi-factor authentication is required.  Re-submit credentials with a valid totp_code.",
      mfa_required: true,
      mfa_types: ["totp"],
      errors: [%{totp_code: ["required"]}]
    }
  end

  # Generic 403 with a caller-supplied message (e.g. the TOTP endpoints'
  # email-not-verified and bad-password re-auth responses)
  def render("403.json", %{message: message}) do
    %{
      ok: false,
      code: 403,
      detail: "Forbidden",
      message: message
    }
  end

  def render("403.json", _assigns) do
    %{
      ok: false,
      code: 403,
      detail: "Forbidden",
      message:
        "Anonymous access to this method on this object is not allowed.  You must authenticate and pass a valid token."
    }
  end

  def render("404.json", _assigns) do
    %{
      ok: false,
      code: 404,
      detail: "Not Found",
      message: "The requested object was not found."
    }
  end

  # A real clause, not template_not_found/2 — that fallback hardcodes
  # code: 404 in the body, which would contradict a 409 response status.
  def render("409.json", _assigns) do
    %{
      ok: false,
      code: 409,
      detail: "Conflict",
      message: "The request conflicts with the current state of the resource."
    }
  end

  def render("422.json", assigns) do
    {errors, msg} =
      cond do
        Map.has_key?(assigns, :pagination_error) && not is_nil(assigns.pagination_error) ->
          {translate_errors(assigns.pagination_error),
           "One or both of the pagination parameters failed validation.  See errors key for details"}

        true ->
          {assigns.errors,
           "The request was syntactically correct, but some or all of the parameters failed validation.  See errors key for details"}
      end

    %{
      ok: false,
      code: 422,
      detail: "Unprocessable Entity",
      message: msg,
      errors: errors
    }
  end

  def render("423.json", _assigns) do
    %{
      ok: false,
      code: 423,
      detail: "Locked",
      message: "The requested resource is locked.  Please contact an administrator"
    }
  end

  def render("429.json", _assigns) do
    %{
      ok: false,
      code: 429,
      detail: "Too Many Requests",
      message:
        "You have exceeded the allowed number of requests.  Please cool off and try again later."
    }
  end

  def render("461.json", _assigns) do
    %{
      ok: false,
      code: 461,
      detail: "Terms of Service Required",
      message:
        "You have not yet accepted the Terms of Service.  Acceptance is required to use this API."
    }
  end

  def render("462.json", _assigns) do
    %{
      ok: false,
      code: 462,
      detail: "Privacy Policy Required",
      message:
        "You have not yet accepted the Privacy Policy.  Acceptance is required to use this API."
    }
  end

  def render("500.json", _assigns) do
    %{
      ok: false,
      code: 500,
      detail: "Internal Server Error",
      message: "Internal Server Error"
    }
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    %{
      ok: false,
      # TODO: Can get this code from template?
      code: 404,
      detail: Phoenix.Controller.status_message_from_template(template),
      message: "Template not found"
    }
  end
end
