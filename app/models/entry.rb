class Entry < ActiveRecord::Base
  include CoreObjectSupport
  has_many :broker_invoices, :dependent => :destroy
  has_many :broker_invoice_lines, :through => :broker_invoices
  has_many :commercial_invoices, :dependent => :destroy

  def can_view? user
    user.company.view_entries?
  end

  def self.search_secure user, base_object
    return base_object.where("1=1")
  end
end
