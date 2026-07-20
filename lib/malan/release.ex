defmodule Malan.Release do
  @moduledoc """
  Release tasks invoked from a built `mix release` where `mix` itself is
  not available in the runtime image.

  Expected usage from inside the container:

      bin/malan eval "Malan.Release.migrate()"
      bin/malan eval "Malan.Release.setup()"
      bin/malan eval "Malan.Release.seed()"
      bin/malan eval "Malan.Release.rollback(Malan.Repo, 20240101120000)"
      bin/malan eval "Malan.Release.reencrypt_totp_secrets()"

  `setup/0` is the release equivalent of `mix ecto.setup`: it creates
  storage if absent, runs migrations, then evaluates
  `priv/repo/seeds.exs`.
  """

  @app :malan

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def create_and_migrate do
    load_app()
    create_storage()
    migrate()
  end

  def rollback(repo, version) do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def setup do
    load_app()
    create_storage()
    migrate()
    seed()
  end

  def seed do
    load_app()

    seed_script = Path.join([:code.priv_dir(@app), "repo", "seeds.exs"])

    if File.exists?(seed_script) do
      for repo <- repos() do
        {:ok, _, _} =
          Ecto.Migrator.with_repo(repo, fn _repo ->
            Code.eval_file(seed_script)
          end)
      end
    end
  end

  @doc """
  Re-encrypt `user_totps.secret` rows onto the primary `TOTP_ENCRYPTION_KEYS`
  entry. Key-rotation step 3 — see `Malan.Accounts.reencrypt_totp_secrets/0`
  for the procedure and return shape.
  """
  def reencrypt_totp_secrets do
    load_app()

    for repo <- repos() do
      {:ok, result, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          Malan.Accounts.reencrypt_totp_secrets()
        end)

      IO.puts("reencrypt_totp_secrets: #{inspect(result)}")
    end
  end

  defp create_storage do
    for repo <- repos() do
      case repo.__adapter__().storage_up(repo.config()) do
        :ok -> :ok
        {:error, :already_up} -> :ok
        {:error, reason} -> raise "Could not create storage: #{inspect(reason)}"
      end
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
