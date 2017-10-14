class AddForgotPasswordToUsers < ActiveRecord::Migration
  def change
    add_column :users, :forgot_password, :boolean
  end
end
