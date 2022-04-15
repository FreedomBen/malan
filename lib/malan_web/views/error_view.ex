defmodule MalanWeb.ErrorView do
  use MalanWeb, :view

  def render("400.json", _assigns) do
    %{
      errors: %{
        code: 400,
        detail: "Bad Request"
      }
    }
  end

  def render("401.json", _assigns) do
    %{
      errors: %{
        code: 401,
        detail: "Unauthorized",
        message: "You are authenticated but do not have access to this method on this object."
      }
    }
  end

  def render("403.json", %{invalid_credentials: true}) do
    %{
      errors: %{
        code: 403,
        detail: "Forbidden",
        message:
          "Username, password and/or location were invalid.  Please verify credentials and try again."
      }
    }
  end

  def render("403.json", _assigns) do
    %{
      errors: %{
        code: 403,
        detail: "Forbidden",
        message:
          "Anonymous access to this method on this object is not allowed.  You must authenticate and pass a valid token."
      }
    }
  end

  def render("404.json", _assigns) do
    %{
      errors: %{
        code: 404,
        detail: "Not Found",
        message: "The requested object was not found."
      }
    }
  end

  def render("422.json", assigns) do
    msg =
      case assigns.pagination_error do
        nil ->
          "The request was syntactically correct, but some or all of the parameters failed validation"

        _ ->
          "One or both of the pagination parameters failed validation."
      end

    %{
      errors: %{
        code: 422,
        detail: "Unprocessable Entity",
        message: msg
      }
    }
  end

  def render("423.json", _assigns) do
    %{
      errors: %{
        code: 423,
        detail: "Locked",
        message: "The requested resource is locked.  Please contact an administrator"
      }
    }
  end

  def render("429.json", _assigns) do
    %{
      errors: %{
        code: 429,
        detail: "Too Many Requests",
        message:
          "You have exceeded the allowed number of requests.  Please cool off and try again later."
      }
    }
  end

  def render("461.json", _assigns) do
    %{
      errors: %{
        code: 461,
        detail: "Terms of Service Required",
        message:
          "You have not yet accepted the Terms of Service.  Acceptance is required to use this API."
      }
    }
  end

  def render("462.json", _assigns) do
    %{
      errors: %{
        code: 462,
        detail: "Privacy Policy Required",
        message:
          "You have not yet accepted the Privacy Policy.  Acceptance is required to use this API."
      }
    }
  end

  def render("500.json", _assigns) do
    %{
      errors: %{
        code: 500,
        detail: "Internal Server Error"
      }
    }
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    %{
      errors: %{
        # TODO: Can get this code from template?
        code: 404,
        detail: Phoenix.Controller.status_message_from_template(template)
      }
    }
  end
end
