defmodule MalanWeb.Router do
  use MalanWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {EhrmanBlogWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :unauthed_api do
    plug :accepts, ["json"]
  end

  pipeline :authed_api_no_tos_pp do
    plug :accepts, ["json"]
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
  end

  pipeline :authed_owner_api_no_tos_pp do
    plug :accepts, ["json"]
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
    plug :is_owner_or_admin # Ensures user is the owner of the item or an admin
  end

  pipeline :authed_api do
    plug :accepts, ["json"]
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
    plug :has_accepted_tos  # Ensures latest ToS have been accepted
    plug :has_accepted_privacy_policy # Ensures latest PP has been accepted
  end

  pipeline :owner_api do
    plug :accepts, ["json"]
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
    plug :is_owner_or_admin # Ensures user is the owner of the item or an admin
    plug :has_accepted_tos  # Ensures latest ToS have been accepted
    plug :has_accepted_privacy_policy # Ensures latest PP has been accepted
  end

  pipeline :moderator_api do
    plug :accepts, ["json"]
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
    plug :is_moderator      # Ensures user is a moderator or admin
    plug :has_accepted_tos  # Ensures latest ToS have been accepted
    plug :has_accepted_privacy_policy # Ensures latest PP has been accepted
  end

  pipeline :admin_api do
    plug :accepts, ["json"]
    plug :validate_token    # Adds token and auth info to conn.assigns
    plug :is_authenticated  # Ensures user is authenticated
    plug :is_admin          # Ensures user is admin
    #plug :has_accepted_tos  # Ensures latest ToS have been accepted
    #plug :has_accepted_privacy_policy # Ensures latest PP has been accepted
  end

  scope "/health_check", MalanWeb, log: false do
    get "/liveness", HealthCheckController, :liveness
    get "/readiness", HealthCheckController, :readiness
  end

  scope "/", EhrmanBlogWeb do
    pipe_through :browser

    #live "/", PageLive.Index, :index

    # Predefined pages
    live "/dashboard", PageLive.Dashboard, :dashboard
  end

  scope "/api", MalanWeb do
    pipe_through :unauthed_api

    post "/users", UserController, :create
    post "/sessions", SessionController, :create
    get "/users/whoami", UserController, :whoami
  end

  scope "/api", MalanWeb do
    pipe_through :authed_api_no_tos_pp

    get "/users/me", UserController, :me # Deprecated in favor of /users/current
    get "/users/current", UserController, :current

    # is_self_or_admin in UserController will prevent non-owners from accessing
    resources "/users", UserController, only: [:show, :update, :delete]

    # Get or Delete the current session (the one belonging to the api_token in use)
    # Not piped through "owner" because no User ID is passed and it will only delete the current session
    get "/sessions/current", SessionController, :show_current
    delete "/sessions/current", SessionController, :delete_current

    resources "/users", UserController, only: [] do
      get "/transactions", TransactionController, :user_index
    end
  end

  scope "/api", MalanWeb do
    pipe_through :authed_owner_api_no_tos_pp

    resources "/users", UserController, only: [] do
      delete "/sessions", SessionController, :delete_all  # Delete all active sessions for this user
      resources "/sessions", SessionController, only: [:index, :show, :delete]
      resources "/phone_numbers", PhoneNumberController, only: [:index, :show, :create, :update, :delete]
      resources "/addresses", AddressController, only: [:index, :show, :create, :update, :delete]
    end
  end

  scope "/api", MalanWeb do
    pipe_through :authed_api

    #resources "/teams", TeamController, only: [:index, :show, :create, :update, :delete]
  end

  scope "/api", MalanWeb do
    pipe_through :owner_api

    #resources "/users", UserController, only: [] do
    #  get "/objects", ObjectController, :user_index
    #end
  end

  scope "/api/moderator", MalanWeb do
    pipe_through :moderator_api

    #resources "/users", UserController, only: [] do
    #  get "/objects", ObjectController, :user_index
    #end
  end

  #scope "/api/admin", MalanWeb, as: :admin do
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

    # Transactions can only be retreived (not created, updated, or deleted)
    # they are created as side effects of user/session operations and are immutable
    get "/transactions", TransactionController, :admin_index # Careful, returns a lot of records!
    get "/transactions/:id", TransactionController, :show
    get "/transactions/users/:user_id", TransactionController, :users
    get "/transactions/sessions/:session_id", TransactionController, :sessions
    get "/transactions/who/:user_id", TransactionController, :who

  end
end
