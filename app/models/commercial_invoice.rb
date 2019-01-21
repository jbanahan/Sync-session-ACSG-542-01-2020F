# == Schema Information
#
# Table name: commercial_invoices
#
#  consignee_id           :integer
#  country_origin_code    :string(255)
#  created_at             :datetime         not null
#  currency               :string(255)
#  destination_code       :string(255)
#  docs_ok_date           :date
#  docs_received_date     :date
#  entered_value_7501     :integer
#  entry_id               :integer
#  exchange_rate          :decimal(8, 6)
#  gross_weight           :integer
#  house_bills_of_lading  :text
#  id                     :integer          not null, primary key
#  importer_id            :integer
#  invoice_date           :date
#  invoice_number         :string(255)
#  invoice_value          :decimal(13, 2)
#  invoice_value_foreign  :decimal(13, 2)
#  issue_codes            :string(255)
#  master_bills_of_lading :text
#  mfid                   :string(255)
#  non_dutiable_amount    :decimal(13, 2)
#  rater_comments         :text
#  total_charges          :decimal(11, 2)
#  total_quantity         :decimal(12, 5)
#  total_quantity_uom     :string(255)
#  updated_at             :datetime         not null
#  vendor_id              :integer
#  vendor_name            :string(255)
#
# Indexes
#
#  index_commercial_invoices_on_entry_id        (entry_id)
#  index_commercial_invoices_on_importer_id     (importer_id)
#  index_commercial_invoices_on_invoice_date    (invoice_date)
#  index_commercial_invoices_on_invoice_number  (invoice_number)
#

class CommercialInvoice < ActiveRecord::Base
  include CoreObjectSupport
  has_many :commercial_invoice_lines, dependent: :destroy, autosave: true, inverse_of: :commercial_invoice
  belongs_to :entry, inverse_of: :commercial_invoices
  belongs_to :vendor, :class_name => "Company"
  belongs_to :importer, :class_name => "Company"
  belongs_to :consignee, :class_name => "Company"

  def can_view? user
    return false unless user.view_entries?
    return user.company.master? || user.company_id == self.importer_id ||
          user.company_id == self.vendor_id
  end

  def value_for_tax
    values = self.commercial_invoice_lines.map(&:value_for_tax).compact
    values.length == 0 ? nil : values.sum
  end

  def can_edit? user
    return false unless user.edit_entries?
    return user.company.master? || 
      user.company == self.importer ||
      user.company == self.vendor ||
      user.company.linked_companies.find {|c| c == self.importer || c == self.vendor}
  end

  # This overrides the EntitySnapshotSupport's implementation because we need to destroy snapshots for
  # commercial invoices that are stand-alone, but not for those that are linked to entries.
  def destroys_snapshots?
    # This is just to ensure if for any reason we do turn off snapshots on commercial invoices in core module definitions that 
    # it takes effect here, even if we forget to delete this method
    return false unless super

    # If the entry id is blank, then it's a standalone commercial invoice and we should make sure to clean up any snapshots
    # Otherwise, if the invoice is connected to an entry, the snapshot for that structure is associated with the entry, not the invoice.
    self.entry_id.blank?
  end

  def self.search_secure user, base_object
    base_object.where(self.search_where(user))
  end

  # where clause for search secure
  def self.search_where user
    cid = user.company_id
    user.company.master? ? "1=1" : "(commercial_invoices.importer_id = #{cid} OR commercial_invoices.vendor_id = #{cid} OR commercial_invoices.importer_id IN (select child_id from linked_companies where parent_id = #{cid}) OR commercial_invoices.vendor_id IN (select child_id from linked_companies where parent_id = #{cid}))"
  end
end
