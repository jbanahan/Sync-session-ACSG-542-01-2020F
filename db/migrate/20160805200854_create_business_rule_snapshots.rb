class CreateBusinessRuleSnapshots < ActiveRecord::Migration
  def up
    create_table :business_rule_snapshots do |t|
      t.references :recordable, polymorphic: true, null: false
      t.string :bucket, null: false
      t.string :doc_path, null: false
      t.string :version

      t.timestamps null: false
    end

    add_index :business_rule_snapshots, [:recordable_id, :recordable_type], name: "business_rule_snapshots_on_recordable_id_and_recordable_type"
  end

  def down
    drop_table :business_rule_snapshots
  end
end
