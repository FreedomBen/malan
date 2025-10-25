defmodule MalanWeb.ErrorJSONTest do
  use MalanWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 400.json" do
    assert render(MalanWeb.ErrorJSON, "400.json", []) == %{
             ok: false,
             code: 400,
             detail: "Bad Request",
             message: "The request was very very bad"
           }
  end

  test "renders 401.json" do
    assert render(MalanWeb.ErrorJSON, "401.json", []) == %{
             ok: false,
             code: 401,
             detail: "Unauthorized",
             message:
               "You are authenticated but do not have access to this method on this object."
           }
  end

  test "renders 403.json" do
    assert render(MalanWeb.ErrorJSON, "403.json", []) == %{
             ok: false,
             code: 403,
             detail: "Forbidden",
             message:
               "Anonymous access to this method on this object is not allowed.  You must authenticate and pass a valid token."
           }
  end

  test "renders 404.json" do
    assert render(MalanWeb.ErrorJSON, "404.json", []) == %{
             ok: false,
             code: 404,
             detail: "Not Found",
             message: "The requested object was not found."
           }
  end

  test "renders 422.json" do
    errors = %{
      dean: "winchester",
      sam: "winchester"
    }

    assert render(MalanWeb.ErrorJSON, "422.json", pagination_error: nil, errors: errors) == %{
             ok: false,
             code: 422,
             detail: "Unprocessable Entity",
             message:
               "The request was syntactically correct, but some or all of the parameters failed validation.  See errors key for details",
             errors: errors
           }

    assert render(MalanWeb.ErrorJSON, "422.json", pagination_error: nil, errors: errors) == %{
             ok: false,
             code: 422,
             detail: "Unprocessable Entity",
             message:
               "The request was syntactically correct, but some or all of the parameters failed validation.  See errors key for details",
             errors: errors
           }
  end

  test "renders 423.json" do
    assert render(MalanWeb.ErrorJSON, "423.json", []) == %{
             ok: false,
             code: 423,
             detail: "Locked",
             message: "The requested resource is locked.  Please contact an administrator"
           }
  end

  test "renders 429.json" do
    assert render(MalanWeb.ErrorJSON, "429.json", []) == %{
             ok: false,
             code: 429,
             detail: "Too Many Requests",
             message:
               "You have exceeded the allowed number of requests.  Please cool off and try again later."
           }
  end

  test "renders 461.json" do
    assert render(MalanWeb.ErrorJSON, "461.json", []) == %{
             ok: false,
             code: 461,
             detail: "Terms of Service Required",
             message:
               "You have not yet accepted the Terms of Service.  Acceptance is required to use this API."
           }
  end

  test "renders 462.json" do
    assert render(MalanWeb.ErrorJSON, "462.json", []) == %{
             ok: false,
             code: 462,
             detail: "Privacy Policy Required",
             message:
               "You have not yet accepted the Privacy Policy.  Acceptance is required to use this API."
           }
  end

  test "renders 500.json" do
    assert render(MalanWeb.ErrorJSON, "500.json", []) ==
             %{
               ok: false,
               code: 500,
               detail: "Internal Server Error",
               message: "Internal Server Error"
             }
  end
end
