class AddLogoImageToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :logo_image, :string
  end

  def self.down
    remove_column :master_setups, :logo_image
  end
end
