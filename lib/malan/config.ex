defmodule Malan.Config do
  defmodule App do
    def host do
      Application.get_env(:malan, MalanWeb.Endpoint)[:url][:host]
    end

    def port do
      Application.get_env(:malan, MalanWeb.Endpoint)[:url][:port]
    end

    def external_scheme do
      Application.get_env(:malan, MalanWeb.Config.App)[:external_scheme]
    end

    def external_port do
      Application.get_env(:malan, MalanWeb.Config.App)[:external_port]
    end

    def external_port_str do
      case external_port() do
        "80" -> ""
        "443" -> ""
        port -> ":" <> port
      end
    end

    def external_host do
      Application.get_env(:malan, MalanWeb.Config.App)[:external_host]
    end

    def external_link(path) do
      external_scheme() <> "://" <> external_host() <> external_port_str() <> path
    end
  end

  defmodule Session do
    def default_token_expiration_secs do
      Application.get_env(:malan, Malan.Accounts.Session)[
        :default_token_expiration_secs
      ]
    end
  end

  defmodule User do
    def default_password_reset_token_expiration_secs do
      Application.get_env(:malan, Malan.Accounts.User)[
        :default_password_reset_token_expiration_secs
      ]
    end
  end

  defmodule RateLimit do
    def password_reset_lower_limit_msecs do
      Application.get_env(:malan, Malan.Config.RateLimits)[
        :password_reset_lower_limit_msecs
      ]
    end

    def password_reset_lower_limit_count do
      Application.get_env(:malan, Malan.Config.RateLimits)[
        :password_reset_lower_limit_count
      ]
    end

    def password_reset_upper_limit_msecs do
      Application.get_env(:malan, Malan.Config.RateLimits)[
        :password_reset_upper_limit_msecs
      ]
    end

    def password_reset_upper_limit_count do
      Application.get_env(:malan, Malan.Config.RateLimits)[
        :password_reset_upper_limit_count
      ]
    end

    def password_reset_lower_limit do
      {password_reset_lower_limit_msecs(), password_reset_lower_limit_count()}
    end

    def password_reset_upper_limit do
      {password_reset_upper_limit_msecs(), password_reset_upper_limit_count()}
    end
  end

  defmodule Sentry do
    def enabled? do
      Application.get_env(:malan, :sentry)[:enabled]
    end

    def dsn do
      Application.get_env(:sentry, :dsn)
    end
  end
end
