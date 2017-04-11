class AddCategoryToUserManual < ActiveRecord::Migration
  def change
    add_column :user_manuals, :category, :string
  end
end
