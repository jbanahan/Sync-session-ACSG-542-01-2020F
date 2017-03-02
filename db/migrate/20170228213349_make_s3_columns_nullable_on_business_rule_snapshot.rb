class MakeS3ColumnsNullableOnBusinessRuleSnapshot < ActiveRecord::Migration
  def up
    change_table(:business_rule_snapshots, bulk: true) do |t|
      t.change :bucket, :string, null: true
      t.change :doc_path, :string, null: true
    end
  end

  def down
    # This migration is not reversible due to the probability that there are now nulls in the table
  end
end
