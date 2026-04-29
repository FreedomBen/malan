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

    @doc """
    Get a link like "https://malan.dev:4000/path
    """
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

    def default_max_extension_time_secs do
      Application.get_env(:malan, Malan.Accounts.Session)[
        :default_max_extension_time_secs
      ]
    end

    def default_max_extension_secs do
      Application.get_env(:malan, Malan.Accounts.Session)[
        :default_max_extension_secs
      ]
    end

    def max_max_extension_secs do
      Application.get_env(:malan, Malan.Accounts.Session)[
        :max_max_extension_secs
      ]
    end
  end

  defmodule User do
    def default_password_reset_token_expiration_secs do
      Application.get_env(:malan, Malan.Accounts.User)[
        :default_password_reset_token_expiration_secs
      ]
    end

    def default_email_verification_token_expiration_secs do
      Application.get_env(:malan, Malan.Accounts.User)[
        :default_email_verification_token_expiration_secs
      ] || 1800
    end

    def email_verification_auto_send? do
      Application.get_env(:malan, :email_verification_auto_send, true)
    end

    def email_verification_skip_domains do
      Application.get_env(:malan, :email_verification_skip_domains, [
        "example.com",
        "example.org",
        "example.net",
        ".test",
        ".example",
        ".invalid",
        ".localhost"
      ])
    end

    def min_password_length do
      Application.get_env(:malan, Malan.Accounts.User)[:min_password_length]
    end

    def admin_set_user_min_password_length do
      Application.get_env(:malan, Malan.Accounts.User)[:admin_set_user_min_password_length]
    end

    def admin_account_min_password_length do
      Application.get_env(:malan, Malan.Accounts.User)[:admin_account_min_password_length]
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

    def password_reset_ip_lower_limit_msecs do
      Application.get_env(:malan, Malan.Config.RateLimits)[
        :password_reset_ip_lower_limit_msecs
      ]
    end

    def password_reset_ip_lower_limit_count do
      Application.get_env(:malan, Malan.Config.RateLimits)[
        :password_reset_ip_lower_limit_count
      ]
    end

    def password_reset_ip_upper_limit_msecs do
      Application.get_env(:malan, Malan.Config.RateLimits)[
        :password_reset_ip_upper_limit_msecs
      ]
    end

    def password_reset_ip_upper_limit_count do
      Application.get_env(:malan, Malan.Config.RateLimits)[
        :password_reset_ip_upper_limit_count
      ]
    end

    def password_reset_ip_lower_limit do
      {password_reset_ip_lower_limit_msecs(), password_reset_ip_lower_limit_count()}
    end

    def password_reset_ip_upper_limit do
      {password_reset_ip_upper_limit_msecs(), password_reset_ip_upper_limit_count()}
    end

    def session_extension_limit_msecs do
      Application.get_env(:malan, Malan.Config.RateLimits)[:session_extension_limit_msecs]
    end

    def session_extension_limit_count do
      Application.get_env(:malan, Malan.Config.RateLimits)[:session_extension_limit_count]
    end

    def session_extension_limit do
      {session_extension_limit_msecs(), session_extension_limit_count()}
    end

    def login_limit_msecs do
      Application.get_env(:malan, Malan.Config.RateLimits)[:login_limit_msecs]
    end

    def login_limit_count do
      Application.get_env(:malan, Malan.Config.RateLimits)[:login_limit_count]
    end

    def login_limit do
      {login_limit_msecs(), login_limit_count()}
    end

    def email_verify_lower_limit_msecs do
      Application.get_env(:malan, Malan.Config.RateLimits)[:email_verify_lower_limit_msecs] ||
        1_800_000
    end

    def email_verify_lower_limit_count do
      Application.get_env(:malan, Malan.Config.RateLimits)[:email_verify_lower_limit_count] || 1
    end

    def email_verify_upper_limit_msecs do
      Application.get_env(:malan, Malan.Config.RateLimits)[:email_verify_upper_limit_msecs] ||
        86_400_000
    end

    def email_verify_upper_limit_count do
      Application.get_env(:malan, Malan.Config.RateLimits)[:email_verify_upper_limit_count] || 3
    end

    def email_verify_lower_limit do
      {email_verify_lower_limit_msecs(), email_verify_lower_limit_count()}
    end

    def email_verify_upper_limit do
      {email_verify_upper_limit_msecs(), email_verify_upper_limit_count()}
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
