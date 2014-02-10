class CreateBusinessValidationRuleResults < ActiveRecord::Migration
  def change
    create_table :business_validation_rule_results do |t|
      t.references :business_validation_result
      t.references :business_validation_rule
      t.string :state
      t.string :message
      t.text :note
      t.references :overridden_by
      t.datetime :overridden_at

      t.timestamps
    end
    add_index :business_validation_rule_results, :business_validation_result_id, name: 'business_validation_result'
    add_index :business_validation_rule_results, :business_validation_rule_id, name: 'business_validation_rule'
    add_index :business_validation_rule_results, :overridden_by_id
  end
end
