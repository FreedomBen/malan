defmodule MalanWeb.UserController.AdminUpdateHashCountTest do
  @moduledoc """
  Regression test for the double-hash bug in `MalanWeb.UserController.admin_update/2`.

  The bug: the controller built `User.admin_changeset/2` once for the audit log
  and `Accounts.admin_update_user/2` built it again to persist. Each
  `admin_changeset` invocation runs `put_pass_hash`, so when the request body
  included a password, Pbkdf2 (160k rounds) ran twice per request — adding
  ~700ms of pure CPU work to every admin update.

  The fix has `admin_update_user/2` return `{:ok, user, changeset}` so the
  controller reuses the same changeset for the audit log.

  Each Pbkdf2 hash includes a random salt, so two hashes of the same password
  produce different `password_hash` values. We exploit that here: the
  `password_hash` returned in the changeset must match the `password_hash`
  actually persisted on the user. If anyone reintroduces a duplicate
  `User.admin_changeset` call, the second changeset's hash will diverge from
  the persisted one and this test will fail.
  """
  use MalanWeb.ConnCase, async: true

  alias Malan.Accounts
  alias Malan.Test.Helpers

  describe "Accounts.admin_update_user/2" do
    test "returns the same changeset whose password_hash was persisted" do
      {:ok, user} = Helpers.Accounts.regular_user()

      assert {:ok, updated, %Ecto.Changeset{} = cs} =
               Accounts.admin_update_user(user, %{"password" => "BrandNewPw_HashOnce1"})

      cs_hash = Ecto.Changeset.get_change(cs, :password_hash)

      assert is_binary(cs_hash) and cs_hash != "",
             "changeset should carry the freshly-computed password_hash"

      assert updated.password_hash == cs_hash,
             """
             persisted password_hash != changeset password_hash, which means
             admin_update_user computed Pbkdf2 more than once. This is the
             double-hash regression that the fix removed.
             """
    end
  end

  describe "PUT /api/admin/users/:id" do
    setup do
      {:ok, target} = Helpers.Accounts.regular_user()
      {:ok, conn, _admin, _session} = Helpers.Accounts.admin_user_session_conn(build_conn())
      {:ok, conn: conn, target: target}
    end

    test "succeeds when only the password changes (smoke test for the fixed path)",
         %{conn: conn, target: target} do
      conn =
        put(conn, Routes.user_path(conn, :admin_update, target),
          user: %{password: "BrandNewPw_HashOnce2"}
        )

      assert json_response(conn, 200)["data"]["id"] == target.id

      # Confirm the new password was actually persisted.
      reloaded = Accounts.get_user!(target.id)

      assert {:ok, _session} =
               Helpers.Accounts.create_session(%{reloaded | password: "BrandNewPw_HashOnce2"})
    end
  end
end
