class AddTargetExceptionDatesToEntries < ActiveRecord::Migration
  def up
    change_table(:entries, bulk: true) do |t|
      t.datetime :customs_detention_exception_opened_date
      t.datetime :customs_detention_exception_resolved_date
      t.datetime :classification_inquiry_exception_opened_date
      t.datetime :classification_inquiry_exception_resolved_date
      t.datetime :customer_requested_hold_exception_opened_date
      t.datetime :customer_requested_hold_exception_resolved_date
      t.datetime :customs_exam_exception_opened_date
      t.datetime :customs_exam_exception_resolved_date
      t.datetime :document_discrepancy_exception_opened_date
      t.datetime :document_discrepancy_exception_resolved_date
      t.datetime :fda_issue_exception_opened_date
      t.datetime :fda_issue_exception_resolved_date
      t.datetime :fish_and_wildlife_exception_opened_date
      t.datetime :fish_and_wildlife_exception_resolved_date
      t.datetime :lacey_act_exception_opened_date
      t.datetime :lacey_act_exception_resolved_date
      t.datetime :late_documents_exception_opened_date
      t.datetime :late_documents_exception_resolved_date
      t.datetime :manifest_hold_exception_opened_date
      t.datetime :manifest_hold_exception_resolved_date
      t.datetime :missing_document_exception_opened_date
      t.datetime :missing_document_exception_resolved_date
      t.datetime :pending_customs_review_exception_opened_date
      t.datetime :pending_customs_review_exception_resolved_date
      t.datetime :price_inquiry_exception_opened_date
      t.datetime :price_inquiry_exception_resolved_date
      t.datetime :usda_hold_exception_opened_date
      t.datetime :usda_hold_exception_resolved_date
    end
  end

  def down
    change_table(:entries, bulk: true) do |t|
      t.remove :customs_detention_exception_opened_date
      t.remove :customs_detention_exception_resolved_date
      t.remove :classification_inquiry_exception_opened_date
      t.remove :classification_inquiry_exception_resolved_date
      t.remove :customer_requested_hold_exception_opened_date
      t.remove :customer_requested_hold_exception_resolved_date
      t.remove :customs_exam_exception_opened_date
      t.remove :customs_exam_exception_resolved_date
      t.remove :document_discrepancy_exception_opened_date
      t.remove :document_discrepancy_exception_resolved_date
      t.remove :fda_issue_exception_opened_date
      t.remove :fda_issue_exception_resolved_date
      t.remove :fish_and_wildlife_exception_opened_date
      t.remove :fish_and_wildlife_exception_resolved_date
      t.remove :lacey_act_exception_opened_date
      t.remove :lacey_act_exception_resolved_date
      t.remove :late_documents_exception_opened_date
      t.remove :late_documents_exception_resolved_date
      t.remove :manifest_hold_exception_opened_date
      t.remove :manifest_hold_exception_resolved_date
      t.remove :missing_document_exception_opened_date
      t.remove :missing_document_exception_resolved_date
      t.remove :pending_customs_review_exception_opened_date
      t.remove :pending_customs_review_exception_resolved_date
      t.remove :price_inquiry_exception_opened_date
      t.remove :price_inquiry_exception_resolved_date
      t.remove :usda_hold_exception_opened_date
      t.remove :usda_hold_exception_resolved_date
    end
  end
end
