# If "name" for Swoosh Recipient can be "first_name", then we could just use:
# the @derive in the User struct above:
# https://hexdocs.pm/swoosh/Swoosh.Email.Recipient.html

# defimpl Swoosh.Email.Recipient, for: Malan.Accounts.User do
#  alias Malan.Accounts.User
#
#  def format(%User{first_name: first_name, last_name: last_name, email: address} = value) do
#    {"#{first_name} #{last_name}", address}
#  end
# end
