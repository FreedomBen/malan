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

    def password_reset_limit_count do
      Application.get_env(:malan, Malan.Accounts.User)[
        :password_reset_limit_count
      ]
    end

    def password_reset_period_msecs do
      Application.get_env(:malan, Malan.Accounts.User)[
        :password_reset_period_msecs
      ]
    end

    def password_reset_limit do
      {password_reset_period_msecs(), password_reset_limit_count()}
    end

    @doc "Bucket name for Hammer rate limiting tracking"
    @spec pw_reset_rl_bucket(String.t()) :: String.t()
    def pw_reset_rl_bucket(user_id) do
      "generate_password_reset:#{user_id}"
    end
  end
end
