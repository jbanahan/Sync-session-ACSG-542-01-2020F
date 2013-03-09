class CommercialInvoice < ActiveRecord::Base
  include CoreObjectSupport
  has_many :commercial_invoice_lines, :dependent => :destroy
  belongs_to :entry, :touch=>true
  belongs_to :vendor, :class_name => "Company"
  belongs_to :importer, :class_name => "Company"

  def can_view? user
    return false unless user.view_commercial_invoices?
    return user.company.master? || user.company_id == self.importer_id ||
          user.company_id == self.vendor_id
  end
end
