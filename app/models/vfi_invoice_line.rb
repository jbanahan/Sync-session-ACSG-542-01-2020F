class VfiInvoiceLine < ActiveRecord::Base
  include DefaultLineNumberSupport
  belongs_to :vfi_invoice, :inverse_of => :vfi_invoice_lines, :touch => true
  has_many :invoiced_events

  before_validation :default_line_number
  validates :vfi_invoice_id, :presence => true
  validates :charge_description, :presence => true
  validates :charge_amount, :presence => true

  private
  
  def parent_obj #supporting method for LinesSupport
    self.vfi_invoice
  end
  
  def parent_id_where #supporting method for LinesSupport
    return :vfi_invoice_id => self.vfi_invoice.id
  end

end
