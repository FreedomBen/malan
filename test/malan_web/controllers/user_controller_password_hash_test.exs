defmodule MalanWeb.UserController.PasswordHashCountTest do
  @moduledoc """
  Regression tests for the double-hash bug across the user-password endpoints.

  The original bug: `MalanWeb.UserController.admin_update/2` built
  `User.admin_changeset/2` once for the audit log and `Accounts.admin_update_user/2`
  built it again to persist. Each `*_changeset` invocation that contains a
  password runs `put_pass_hash`, so when the request body included a password,
  Pbkdf2 (160k rounds) ran twice per request. The same anti-pattern existed
  in `create/2`, `update/2`, and `reset_password_token`.

  Each Pbkdf2 hash includes a random salt, so two hashes of the same password
  produce different `password_hash` values. The Accounts-level tests below
  exploit that property: the `password_hash` returned in the changeset must
  equal the `password_hash` actually persisted on the user. Reintroducing a
  duplicate `*_changeset` build inside any of these Accounts functions would
  diverge the two and fail the test.

  The reset_password_token controller path is covered by a static assertion
  on the controller source, since that fix removed the audit-log changeset
  entirely (no useful changeset survives that path to compare).
  """
  use MalanWeb.ConnCase, async: true

  alias Malan.Accounts
  alias Malan.Test.Helpers

  describe "Accounts.register_user/1" do
    test "returns the same changeset whose password_hash was persisted" do
      ui = System.unique_integer([:positive])

      attrs = %{
        "username" => "hashonce_register#{ui}",
        "email" => "hashonce_register#{ui}@email.com",
        "first_name" => "Hash",
        "last_name" => "Once",
        "nick_name" => "ho",
        "password" => "BrandNewPw_RegisterOnce1",
        "preferences" => %{"theme" => "light"}
      }

      assert {:ok, user, %Ecto.Changeset{} = cs} = Accounts.register_user(attrs)

      cs_hash = Ecto.Changeset.get_change(cs, :password_hash)

      assert is_binary(cs_hash) and cs_hash != "",
             "changeset should carry the freshly-computed password_hash"

      assert user.password_hash == cs_hash,
             "register_user computed Pbkdf2 more than once (changeset hash != persisted hash)"
    end
  end

  describe "Accounts.update_user/2" do
    test "returns the same changeset whose password_hash was persisted" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, updated, %Ecto.Changeset{} = cs} =
               Accounts.update_user(user, %{"password" => "BrandNewPw_UpdateOnce1"})

      cs_hash = Ecto.Changeset.get_change(cs, :password_hash)

      assert is_binary(cs_hash) and cs_hash != "",
             "changeset should carry the freshly-computed password_hash"

      assert updated.password_hash == cs_hash,
             "update_user computed Pbkdf2 more than once (changeset hash != persisted hash)"
    end

    test "returns 3-tuple with no password_hash change when attrs omit password" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, updated, %Ecto.Changeset{} = cs} =
               Accounts.update_user(user, %{"nick_name" => "renamed"})

      assert is_nil(Ecto.Changeset.get_change(cs, :password_hash))
      assert updated.nick_name == "renamed"
      assert updated.password_hash == user.password_hash
    end
  end

  describe "Accounts.admin_update_user/2" do
    test "returns the same changeset whose password_hash was persisted" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, updated, %Ecto.Changeset{} = cs} =
               Accounts.admin_update_user(user, %{"password" => "BrandNewPw_AdminOnce1"})

      cs_hash = Ecto.Changeset.get_change(cs, :password_hash)

      assert is_binary(cs_hash) and cs_hash != "",
             "changeset should carry the freshly-computed password_hash"

      assert updated.password_hash == cs_hash,
             "admin_update_user computed Pbkdf2 more than once (changeset hash != persisted hash)"
    end
  end

  describe "controller smoke tests for the fixed paths" do
    setup do
      {:ok, target} = Helpers.Accounts.regular_user()
      {:ok, conn, _admin, _session} = Helpers.Accounts.admin_user_session_conn(build_conn())
      {:ok, conn: conn, target: target}
    end

    test "PUT /api/admin/users/:id with password succeeds and password actually changes",
         %{conn: conn, target: target} do
      conn =
        put(conn, Routes.user_path(conn, :admin_update, target),
          user: %{password: "BrandNewPw_AdminOnce2"}
        )

      assert json_response(conn, 200)["data"]["id"] == target.id

      reloaded = Accounts.get_user!(target.id)

      assert {:ok, _session} =
               Helpers.Accounts.create_session(%{reloaded | password: "BrandNewPw_AdminOnce2"})
    end
  end

  describe "reset_password_token_p — controller no longer builds a changeset" do
    @controller_path "lib/malan_web/controllers/user_controller.ex"

    test "the function body contains no User.update_changeset / User.admin_changeset call" do
      src = File.read!(@controller_path)

      [_, after_head] =
        String.split(
          src,
          "defp reset_password_token_p(conn, %User{} = user, token, new_password, mode) do",
          parts: 2
        )

      [body, _] = String.split(after_head, "\n  defp ", parts: 2)

      # Strip line-level Elixir comments so explanatory comments that reference
      # the forbidden calls don't trip the check.
      code_only =
        body
        |> String.split("\n")
        |> Enum.map(fn line ->
          case Regex.run(~r/^(.*?)#/, line) do
            [_, before_hash] -> before_hash
            _ -> line
          end
        end)
        |> Enum.join("\n")

      refute code_only =~ "User.update_changeset",
             """
             reset_password_token_p reintroduced a User.update_changeset call.
             That changeset is purely for the audit log and double-hashes the
             password (Pbkdf2 ~700ms). Use a plain map for the audit-log payload
             instead.
             """

      refute code_only =~ "User.admin_changeset",
             "reset_password_token_p reintroduced a User.admin_changeset call (same double-hash hazard)."
    end
  end
end
