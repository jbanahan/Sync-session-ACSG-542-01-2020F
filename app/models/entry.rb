class Entry < ActiveRecord::Base
  include CoreObjectSupport
  has_many :broker_invoices
  has_many :broker_invoice_lines, :through => :broker_invoices

  def can_view? user
    user.company.view_entries?
  end
end
