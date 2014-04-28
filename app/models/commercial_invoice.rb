class CommercialInvoice < ActiveRecord::Base
  include CoreObjectSupport
  has_many :commercial_invoice_lines, :dependent => :destroy
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
