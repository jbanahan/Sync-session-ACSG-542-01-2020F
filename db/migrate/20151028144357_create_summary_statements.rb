class CreateSummaryStatements < ActiveRecord::Migration
  def self.up
    create_table :summary_statements do |t|
      t.string :statement_number
      t.integer :customer_id, null: false
      t.timestamps
    end
  end

  def self.down
    drop_table :summary_statements
  end
end