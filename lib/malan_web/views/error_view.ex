defmodule MalanWeb.ErrorView do
  use MalanWeb, :view

  def render("400.json", _assigns) do
    %{
      errors: %{
        detail: "Bad Request"
      }
    }
  end

  def render("401.json", _assigns) do
    %{
      errors: %{
        detail: "Unauthorized",
        message: "You are authenticated but do not have access to this method on this object."
      }
    }
  end

  def render("403.json", _assigns) do
    %{
      errors: %{
        detail: "Forbidden",
        message:
          "Anonymous access to this method on this object is not allowed.  You must authenticate and pass a valid token."
      }
    }
  end

  def render("404.json", _assigns) do
    %{
      errors: %{
        detail: "Not Found",
        message: "The requested object was not found."
      }
    }
  end

  def render("429.json", _assigns) do
    %{
      errors: %{
        detail: "Too Many Requests",
        message:
          "You have exceeded the allowed number of requests.  Please cool off and try again later."
      }
    }
  end

  def render("461.json", _assigns) do
    %{
      errors: %{
        detail: "Terms of Service Required",
        message:
          "You have not yet accepted the Terms of Service.  Acceptance is required to use this API."
      }
    }
  end

  def render("462.json", _assigns) do
    %{
      errors: %{
        detail: "Privacy Policy Required",
        message:
          "You have not yet accepted the Privacy Policy.  Acceptance is required to use this API."
      }
    }
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal Server Error"}}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
