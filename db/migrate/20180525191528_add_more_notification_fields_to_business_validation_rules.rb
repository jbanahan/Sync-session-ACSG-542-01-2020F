class AddMoreNotificationFieldsToBusinessValidationRules < ActiveRecord::Migration
  def self.up
    change_table(:business_validation_rules, bulk: true) do |t|
      t.boolean :suppress_pass_notice
      t.boolean :suppress_review_fail_notice
      t.boolean :suppress_skipped_notice
      t.string  :subject_pass
      t.string  :subject_review_fail
      t.string  :subject_skipped
      t.string  :message_pass
      t.string  :message_review_fail
      t.string  :message_skipped
    end
  end

  def self.down
    change_table(:business_validation_rules, bulk: true) do |t|
      t.remove :suppress_pass_notice
      t.remove :suppress_review_fail_notice
      t.remove :suppress_skipped_notice
      t.remove :subject_pass
      t.remove :subject_review_fail
      t.remove :subject_skipped
      t.remove :message_pass
      t.remove :message_review_fail
      t.remove :message_skipped
    end
  end
end
