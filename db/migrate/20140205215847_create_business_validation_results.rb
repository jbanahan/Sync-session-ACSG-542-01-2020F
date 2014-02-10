class CreateBusinessValidationResults < ActiveRecord::Migration
  def change
    create_table :business_validation_results do |t|
      t.references :business_validation_template
      t.references :validatable, polymorphic: true
      t.string :state

      t.timestamps
    end
    add_index :business_validation_results, :business_validation_template_id, name: 'business_validation_template'
    add_index :business_validation_results, [:validatable_id, :validatable_type], name: 'validatable'
  end
end
