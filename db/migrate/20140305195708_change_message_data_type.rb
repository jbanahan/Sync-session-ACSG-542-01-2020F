class ChangeMessageDataType < ActiveRecord::Migration
  def up
    change_column :business_validation_rule_results, :message, :text
  end

  def down
    change_column :business_validation_rule_results, :message, :string
  end
end
