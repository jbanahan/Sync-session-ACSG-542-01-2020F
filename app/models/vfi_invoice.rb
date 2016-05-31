class VfiInvoice < ActiveRecord::Base
  belongs_to :customer, :class_name => "Company"
  has_many :vfi_invoice_lines, :dependent => :destroy, :inverse_of => :vfi_invoice

  validates :customer, presence: true

  def can_view? user
    user.view_vfi_invoices?
  end
  
  def self.search_where(user)
    "customer_id in (#{user.available_importers.pluck(:id).join(', ')})"
  end

  def self.next_invoice_number
    Lock.acquire("next-inv") { yield "VFI-#{last ? (last.id + 1) : 1}" }
  end

end