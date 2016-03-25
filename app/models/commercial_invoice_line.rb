class CommercialInvoiceLine < ActiveRecord::Base
  belongs_to :commercial_invoice, :inverse_of=>:commercial_invoice_lines, :touch=>true
  has_one :entry, :through => :commercial_invoice
  has_many :commercial_invoice_tariffs, :dependent=>:destroy, :autosave=>true
  has_many :change_records, :as => :recordable
  belongs_to :container
  
  include CustomFieldSupport
  include LinesSupport

  def duty_plus_fees_amount
    BigDecimal.new([self.total_duty, self.total_fees].compact.sum)
  end

  def total_duty
    BigDecimal.new(self.commercial_invoice_tariffs.map(&:duty_amount).compact.sum)
  end

  def total_fees
    [prorated_mpf, hmf, cotton_fee].compact.sum
  end

  def total_entered_value
    BigDecimal.new(self.commercial_invoice_tariffs.map(&:entered_value).compact.sum)
  end

  def duty_plus_fees_add_cvd_amounts
    self.duty_plus_fees_amount + ([add_duty_amount, cvd_duty_amount]).compact.sum
  end
end
