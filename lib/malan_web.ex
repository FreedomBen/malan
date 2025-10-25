defmodule MalanWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use MalanWeb, :controller
      use MalanWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt .well-known)

  def controller(opts \\ []) do
    # For tweaking log output in production:
    # https://www.verypossible.com/insights/thoughtful-logging-in-elixir-a-phoenix-story
    opts =
      opts
      |> Keyword.put_new(:log, :info)
      |> Keyword.put_new(:layouts, [html: MalanWeb.LayoutView])

    quote do
      use Phoenix.Controller, unquote(Macro.escape(opts))

      use Gettext, backend: MalanWeb.Gettext

      import Plug.Conn
      import Malan.AuthController

      unquote(verified_routes())
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/malan_web/templates",
        namespace: MalanWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {MalanWeb.LayoutView, :live}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
      import Malan.AuthController
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      use Gettext, backend: MalanWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      import Phoenix.HTML
      import Phoenix.HTML.Form
      use PhoenixHTMLHelpers

      # Import LiveView and .heex helpers (live_render, live_patch, <.form>, etc)
      #import Phoenix.LiveView.Helpers
      import MalanWeb.LiveHelpers
      import Phoenix.Component

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import MalanWeb.ErrorHelpers
      use Gettext, backend: MalanWeb.Gettext
      import Malan.Utils.Phoenix.View.Helpers

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: MalanWeb.Endpoint,
        router: MalanWeb.Router,
        statics: MalanWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which)

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  defmacro __using__({which, opts}) when is_atom(which) and is_list(opts) do
    apply(__MODULE__, which, [opts])
  end
end
