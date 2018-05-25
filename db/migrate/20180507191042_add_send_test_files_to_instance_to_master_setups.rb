class AddSendTestFilesToInstanceToMasterSetups < ActiveRecord::Migration
  def up
    add_column :master_setups, :send_test_files_to_instance, :string, :default=>'vfi-test'
  end

  def down
    remove_column :master_setups, :send_test_files_to_instance
  end
end
