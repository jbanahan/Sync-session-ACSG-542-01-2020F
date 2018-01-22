# == Schema Information
#
# Table name: vfi_invoice_lines
#
#  id                 :integer          not null, primary key
#  vfi_invoice_id     :integer          not null
#  line_number        :integer
#  charge_description :string(255)
#  charge_amount      :decimal(11, 2)
#  charge_code        :string(255)
#  quantity           :decimal(11, 2)
#  unit               :string(255)
#  unit_price         :decimal(11, 2)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_vfi_invoice_lines_on_vfi_invoice_id  (vfi_invoice_id)
#

class VfiInvoiceLine < ActiveRecord::Base
  include DefaultLineNumberSupport
  belongs_to :vfi_invoice, :inverse_of => :vfi_invoice_lines, :touch => true
  has_many :invoiced_events

  before_validation :default_line_number
  before_save :set_charge_amount
  validates :vfi_invoice_id, :presence => true
  validates :charge_description, :presence => true
  validates :quantity, :presence => true
  validates :unit_price, :presence => true

  def get_charge_amount
    self.quantity * self.unit_price
  end

  def set_charge_amount # assumes that before_save will persist the update
    self.charge_amount = get_charge_amount
  end

  private
  
  def parent_obj #supporting method for LinesSupport
    self.vfi_invoice
  end
  
  def parent_id_where #supporting method for LinesSupport
    return :vfi_invoice_id => self.vfi_invoice.id
  end

end
