class AddCustomsStatementsEnabledToMasterSetups < ActiveRecord::Migration
  def change
    add_column :master_setups, :customs_statements_enabled, :boolean
  end
end
