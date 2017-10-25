class AddNotificationFieldsToBusinessValidationRules < ActiveRecord::Migration
  def change
    add_column :business_validation_rules, :notification_type, :string
    add_column :business_validation_rules, :notification_recipients, :text
  end
end
