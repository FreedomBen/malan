defmodule MalanWeb.ErrorViewTest do
  use MalanWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 400.json" do
    assert render(MalanWeb.ErrorView, "400.json", []) == %{
             errors: %{
               code: 400,
               detail: "Bad Request"
             }
           }
  end

  test "renders 401.json" do
    assert render(MalanWeb.ErrorView, "401.json", []) == %{
             errors: %{
               code: 401,
               detail: "Unauthorized",
               message:
                 "You are authenticated but do not have access to this method on this object."
             }
           }
  end

  test "renders 403.json" do
    assert render(MalanWeb.ErrorView, "403.json", []) == %{
             errors: %{
               code: 403,
               detail: "Forbidden",
               message:
                 "Anonymous access to this method on this object is not allowed.  You must authenticate and pass a valid token."
             }
           }
  end

  test "renders 404.json" do
    assert render(MalanWeb.ErrorView, "404.json", []) == %{
             errors: %{
               code: 404,
               detail: "Not Found",
               message: "The requested object was not found."
             }
           }
  end

  test "renders 461.json" do
    assert render(MalanWeb.ErrorView, "461.json", []) == %{
             errors: %{
               code: 461,
               detail: "Terms of Service Required",
               message:
                 "You have not yet accepted the Terms of Service.  Acceptance is required to use this API."
             }
           }
  end

  test "renders 462.json" do
    assert render(MalanWeb.ErrorView, "462.json", []) == %{
             errors: %{
               code: 462,
               detail: "Privacy Policy Required",
               message:
                 "You have not yet accepted the Privacy Policy.  Acceptance is required to use this API."
             }
           }
  end

  test "renders 500.json" do
    assert render(MalanWeb.ErrorView, "500.json", []) ==
             %{
               errors: %{
                 code: 500,
                 detail: "Internal Server Error"
               }
             }
  end
end
