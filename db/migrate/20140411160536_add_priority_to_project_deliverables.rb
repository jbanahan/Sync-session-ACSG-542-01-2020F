class AddPriorityToProjectDeliverables < ActiveRecord::Migration
  def change
    add_column :project_deliverables, :priority, :string
  end
end
