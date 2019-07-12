class AddUserEmailIndex < ActiveRecord::Migration
  def change
    # prevent non-unique emails from happening and aid search speed on email addresses
    add_index(:users, :email, unique: true)
  end
end
