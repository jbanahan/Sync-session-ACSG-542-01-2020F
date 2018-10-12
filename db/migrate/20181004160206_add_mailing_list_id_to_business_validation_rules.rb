class AddMailingListIdToBusinessValidationRules < ActiveRecord::Migration
  def change
    add_column :business_validation_rules, :mailing_list_id, :integer
  end
end
