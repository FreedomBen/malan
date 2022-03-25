defmodule Malan.Config do
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
