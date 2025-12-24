defmodule Malan.Repo.Migrations.DowncaseEmailAndUsernamesChangeTypeToString do
  use Ecto.Migration

  #
  # This migration was needed to bring an existing database up
  # to new state, but for new databases it will fail.  hence
  # why it is commented out but still committed
  #
  def up do
    # First downcase all usernames and emails
    # Enum.each(Repo.all(User), fn user ->
    #  user
    #  |> User.admin_changeset(%{
    #    email: String.downcase(user.email),
    #    username: String.downcase(user.username)
    #  })
    #  |> Repo.update()
    # end)

    # Now change the column type to string instead of citext
    # alter table("users") do
    #   modify :email, :string, null: false
    #   modify :username, :string, null: false
    # end
  end

  def down do
    # Nothing needs to be done
  end
end
