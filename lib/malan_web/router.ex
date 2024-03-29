defmodule MalanWeb.Router do
  use MalanWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {MalanWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :validate_token
    plug :retrieve_user
  end

  pipeline :unauthed_api do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  pipeline :authed_api_no_tos_pp do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
  end

  pipeline :authed_owner_api_no_tos_pp do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
    plug :is_owner_or_admin # Ensures user is the owner of the item or an admin
  end

  pipeline :authed_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
    plug :has_accepted_tos  # Ensures latest ToS have been accepted
    plug :has_accepted_privacy_policy # Ensures latest PP has been accepted
  end

  pipeline :owner_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
    plug :is_owner_or_admin # Ensures user is the owner of the item or an admin
    plug :has_accepted_tos  # Ensures latest ToS have been accepted
    plug :has_accepted_privacy_policy # Ensures latest PP has been accepted
  end

  pipeline :moderator_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
    plug :is_moderator      # Ensures user is a moderator or admin
    plug :has_accepted_tos  # Ensures latest ToS have been accepted
    plug :has_accepted_privacy_policy # Ensures latest PP has been accepted
  end

  pipeline :admin_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
    plug :is_admin          # Ensures user is admin
    #plug :has_accepted_tos  # Ensures latest ToS have been accepted
    #plug :has_accepted_privacy_policy # Ensures latest PP has been accepted
  end

  scope "/", MalanWeb do
    pipe_through :browser

    live "/users/reset_password", UserLive.ResetPassword
    live "/users/reset_password/:token", UserLive.ResetPasswordToken

    get "/password/reset", RedirectController, :reset_password
    get "/password/forgot", RedirectController, :reset_password
  end

  scope "/health_check", MalanWeb, log: false do
    get "/liveness", HealthCheckController, :liveness
    get "/readiness", HealthCheckController, :readiness
  end

  scope "/api", MalanWeb do
    pipe_through :unauthed_api

    post "/users", UserController, :create
    post "/sessions", SessionController, :create
    get "/users/whoami", UserController, :whoami

    post "/users/:id/reset_password", UserController, :reset_password
    put "/users/:id/reset_password/:token", UserController, :reset_password_token_user
    put "/users/reset_password/:token", UserController, :reset_password_token
  end

  scope "/api", MalanWeb do
    pipe_through :authed_api_no_tos_pp

    get "/users/me", UserController, :me # Deprecated in favor of /users/current
    get "/users/current", UserController, :current

    # is_self_or_admin in UserController will prevent non-owners from accessing
    resources "/users", UserController, only: [:show, :update, :delete]

    # Get or Delete the current session (the one belonging to the api_token in use)
    # Not piped through "owner" because no User ID is passed and it will only delete the current session
    get "/sessions/active", SessionController, :index_active
    get "/sessions/current", SessionController, :show_current
    put "/sessions/current/extend", SessionController, :extend_current
    delete "/sessions/current", SessionController, :delete_current

    get "/session_extensions/:id", SessionExtensionController, :show
    get "/sessions/:session_id/extensions", SessionExtensionController, :index

    get "/logs", LogController, :user_index
    get "/logs/:id", LogController, :show
  end

  scope "/api", MalanWeb do
    pipe_through :authed_owner_api_no_tos_pp

    resources "/users", UserController, only: [] do
      # Delete all active sessions for this user
      get "/sessions/active", SessionController, :user_index_active
      put "/sessions/current/extend", SessionController, :extend_current
      put "/sessions/:id/extend", SessionController, :extend
      delete "/sessions", SessionController, :delete_all
      resources "/sessions", SessionController, only: [:index, :show, :delete]

      resources "/phone_numbers", PhoneNumberController,
        only: [:index, :show, :create, :update, :delete]

      resources "/addresses", AddressController, only: [:index, :show, :create, :update, :delete]

      get "/logs", LogController, :user_index
    end
  end

  scope "/api", MalanWeb do
    pipe_through :authed_api

    # resources "/teams", TeamController, only: [:index, :show, :create, :update, :delete]
  end

  scope "/api", MalanWeb do
    pipe_through :owner_api

    # resources "/users", UserController, only: [] do
    #   get "/objects", ObjectController, :user_index
    # end
  end

  scope "/api/moderator", MalanWeb do
    pipe_through :moderator_api

    # resources "/users", UserController, only: [] do
    #   get "/objects", ObjectController, :user_index
    # end
  end

  # scope "/api/admin", MalanWeb, as: :admin do
  scope "/api/admin", MalanWeb do
    pipe_through :admin_api

    resources "/users", UserController, only: [:index]
    put "/users/:id", UserController, :admin_update

    get "/sessions", SessionController, :admin_index
    delete "/sessions/:id", SessionController, :admin_delete

    # These password reset endpoints are currently restricted to admins,
    # but once Malan can send the reset token via email and also serve the landing
    # page, these can be moved to unauthenticated so that users can reset their
    # own passwords
    post "/users/:id/reset_password", UserController, :admin_reset_password
    put "/users/:id/reset_password/:token", UserController, :admin_reset_password_token_user
    put "/users/reset_password/:token", UserController, :admin_reset_password_token

    put "/users/:id/lock", UserController, :lock
    put "/users/:id/unlock", UserController, :unlock

    # Logs can only be retreived (not created, updated, or deleted)
    # they are created as side effects of user/session operations and are immutable
    # Careful, returns a lot of records!
    get "/logs", LogController, :admin_index
    get "/logs/:id", LogController, :show, as: :admin_log
    get "/logs/users/:user_id", LogController, :users
    get "/logs/sessions/:session_id", LogController, :sessions
    get "/logs/who/:user_id", LogController, :who
  end

  # Other scopes may use custom stacks.
  # scope "/api", MalanWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: MalanWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
