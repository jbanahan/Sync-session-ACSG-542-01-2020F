class AddXmlTagNameToFieldValidatorRule < ActiveRecord::Migration
  def change
    add_column :field_validator_rules, :xml_tag_name, :string
  end
end
