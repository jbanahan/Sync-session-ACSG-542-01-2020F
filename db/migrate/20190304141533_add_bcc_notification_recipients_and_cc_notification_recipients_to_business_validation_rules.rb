class AddBccNotificationRecipientsAndCcNotificationRecipientsToBusinessValidationRules < ActiveRecord::Migration
  def change
    change_table :business_validation_rules, bulk: true do |t|
      t.text :bcc_notification_recipients
      t.text :cc_notification_recipients
    end
  end
end
