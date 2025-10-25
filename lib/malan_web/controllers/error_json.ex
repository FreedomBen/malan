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
      token_expired: true,
      errors: [%{token: ["expired"]}]
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
