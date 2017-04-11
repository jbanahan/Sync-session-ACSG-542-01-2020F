class AddWistiaCodeToUserManual < ActiveRecord::Migration
  def change
    add_column :user_manuals, :wistia_code, :string
  end
end
