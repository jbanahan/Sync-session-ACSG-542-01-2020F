class CreateUserPasswordHistories < ActiveRecord::Migration
  def up
    create_table :user_password_histories do |t|
      t.integer :user_id
      t.string :hashed_password
      t.string :password_salt
      t.timestamps null: false
    end

    add_index :user_password_histories, [:user_id, :created_at]
  end

  def down
    drop_table :user_password_histories
  end
end
