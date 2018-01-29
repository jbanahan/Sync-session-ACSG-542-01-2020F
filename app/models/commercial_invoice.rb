# == Schema Information
#
# Table name: commercial_invoices
#
#  id                    :integer          not null, primary key
#  invoice_number        :string(255)
#  vendor_name           :string(255)
#  entry_id              :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  currency              :string(255)
#  exchange_rate         :decimal(8, 6)
#  invoice_value_foreign :decimal(13, 2)
#  invoice_value         :decimal(13, 2)
#  country_origin_code   :string(255)
#  gross_weight          :integer
#  total_charges         :decimal(11, 2)
#  invoice_date          :date
#  mfid                  :string(255)
#  vendor_id             :integer
#  importer_id           :integer
#  consignee_id          :integer
#  total_quantity        :decimal(12, 5)
#  total_quantity_uom    :string(255)
#  docs_received_date    :date
#  docs_ok_date          :date
#  issue_codes           :string(255)
#  rater_comments        :text
#  destination_code      :string(255)
#  non_dutiable_amount   :decimal(13, 2)
#
# Indexes
#
#  index_commercial_invoices_on_entry_id        (entry_id)
#  index_commercial_invoices_on_invoice_date    (invoice_date)
#  index_commercial_invoices_on_invoice_number  (invoice_number)
#

class CommercialInvoice < ActiveRecord::Base
  include CoreObjectSupport
  has_many :commercial_invoice_lines, dependent: :destroy, autosave: true, inverse_of: :commercial_invoice
  belongs_to :entry, :touch=>true, :inverse_of=>:commercial_invoices
  belongs_to :vendor, :class_name => "Company"
  belongs_to :importer, :class_name => "Company"
  belongs_to :consignee, :class_name => "Company"

  def can_view? user
    return false unless user.view_commercial_invoices?
    return user.company.master? || user.company_id == self.importer_id ||
          user.company_id == self.vendor_id
  end

  def can_edit? user
    return false unless user.edit_commercial_invoices?
    return user.company.master? || 
      user.company == self.importer ||
      user.company == self.vendor ||
      user.company.linked_companies.find {|c| c == self.importer || c == self.vendor}
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
