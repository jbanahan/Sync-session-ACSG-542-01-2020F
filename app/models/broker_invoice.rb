class BrokerInvoice < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :entry
  belongs_to :bill_to_country, :class_name=>'Country'
  has_many :broker_invoice_lines, :dependent => :destroy, :inverse_of=>:broker_invoice
  
  before_validation {self.currency = "USD" if self.currency.blank?}
  validates_uniqueness_of :suffix, {:scope => :entry_id}

  accepts_nested_attributes_for :broker_invoice_lines, :allow_destroy=>true, :reject_if => lambda {|q|
    q[:charge_description].blank? || q[:charge_amount].blank?
  }
  
  #finalize the invoice by applying HST and saving
  def complete!
    hst_code = ChargeCode.find_or_create_by_code("HST",:description=>"HST (ON)",:apply_hst=>false) 
    hst_charge = nil
    self.broker_invoice_lines.each {|line| hst_charge = line if line.charge_code == hst_code.code}
    hst_amount = self.hst_amount
    if hst_amount == 0 && hst_charge
      hst_charge.destroy?
    elsif hst_charge
      hst_charge.charge_amount = hst_amount
    elsif hst_amount > 0
      self.broker_invoice_lines.build(:charge_code=>hst_code.code,:charge_description=>hst_code.description,:charge_amount=>hst_amount)
    end
    self.invoice_total = self.broker_invoice_lines.inject(0) {|sum,line| sum + line.charge_amount}
    self.save!
  end
  #calculate HST by looking up all included charge codes and calculating HST amount at 13% fixed rate for Ontario
  def hst_amount
    r = 0
    self.broker_invoice_lines.each do |ln|
      if ln.charge_code && ln.charge_amount
        cc = ChargeCode.find_by_code ln.charge_code
        r += (ln.charge_amount * BigDecimal("0.13")) if cc && cc.apply_hst?
      end
    end
    r
  end

  def can_view? user
    user.view_broker_invoices? && (user.company.master? || (self.entry && ( self.entry.importer_id==user.company_id || user.company.linked_companies.include?(self.entry.importer))))
  end
  
  def can_edit? user
    !self.locked? && can_view?(user) && user.edit_broker_invoices?
  end

  def self.search_secure user, base_object
    Entry.search_secure user, base_object.includes(:entry)
  end
end
