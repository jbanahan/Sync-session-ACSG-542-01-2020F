class VfiInvoice < ActiveRecord::Base
  belongs_to :customer, :class_name => "Company"
  has_many :vfi_invoice_lines, :dependent => :destroy, :inverse_of => :vfi_invoice

  validates :customer, presence: true
  validates :invoice_number, uniqueness: true

  def can_view? user
    user.view_vfi_invoices? && (user.company.master? || user.company_id == self.customer_id || user.company.linked_companies.include?(self.customer))
  end
  
  def self.search_where(user)
    c = Company.find(user.company_id)
    c.master? ? "1=1" : "customer_id in (#{user.available_importers.pluck(:id).join(', ')})"
  end

  def self.next_invoice_number
    Lock.acquire("next-inv") do
      last_id = self.order('id desc').limit(1).pluck(:id).first
      last_id = 0 if last_id.nil?
      yield "VFI-#{last_id + 1}" 
    end
  end

end