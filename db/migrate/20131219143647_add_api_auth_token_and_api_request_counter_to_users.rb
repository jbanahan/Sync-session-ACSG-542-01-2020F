class AddApiAuthTokenAndApiRequestCounterToUsers < ActiveRecord::Migration
  def change
    add_column :users, :api_auth_token, :string
    add_column :users, :api_request_counter, :int
  end
end
