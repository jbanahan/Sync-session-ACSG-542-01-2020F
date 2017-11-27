class AddFriendlyNameToMasterSetups < ActiveRecord::Migration
  def change
    add_column :master_setups, :friendly_name, :string
  end
end
