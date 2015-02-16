class AddNameRoleToInstanceInformations < ActiveRecord::Migration
  def change
    add_column :instance_informations, :name, :string
    add_column :instance_informations, :role, :string
  end
end
