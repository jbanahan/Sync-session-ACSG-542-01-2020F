class AddPortalModeToUser < ActiveRecord::Migration
  def change
    add_column :users, :portal_mode, :string
  end
end
