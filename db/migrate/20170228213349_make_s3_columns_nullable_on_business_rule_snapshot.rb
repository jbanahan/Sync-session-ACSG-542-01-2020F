class MakeS3ColumnsNullableOnBusinessRuleSnapshot < ActiveRecord::Migration
  def up
    change_column :business_rule_snapshots, :bucket, :string, :null => true
    change_column :business_rule_snapshots, :doc_path, :string, :null => true
  end

  def down
    change_column :business_rule_snapshots, :bucket, :string, :null => false
    change_column :business_rule_snapshots, :doc_path, :string, :null => false
  end
end
