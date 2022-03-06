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

    def password_reset_period_secs do
      Application.get_env(:malan, Malan.Accounts.User)[
        :password_reset_period_secs
      ]
    end

    def password_reset_limit do
      {password_reset_period_secs(), password_reset_limit_count()}
    end
  end
end
