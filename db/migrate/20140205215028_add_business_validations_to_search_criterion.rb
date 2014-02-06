class AddBusinessValidationsToSearchCriterion < ActiveRecord::Migration
  def change
    add_column :search_criterions, :business_validation_template_id, :integer
    add_column :search_criterions, :business_validation_rule_id, :integer
    add_index :search_criterions, :business_validation_template_id, name: 'business_validation_template'
    add_index :search_criterions, :business_validation_rule_id, name:'business_validation_rule'
  end
end
