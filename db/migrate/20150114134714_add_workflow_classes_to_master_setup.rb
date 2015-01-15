class AddWorkflowClassesToMasterSetup < ActiveRecord::Migration
  def change
    add_column :master_setups, :workflow_classes, :text
  end
end
