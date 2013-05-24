class BrokerInvoiceLine < ActiveRecord::Base
  include CustomFieldSupport
  belongs_to :broker_invoice, :touch=>true
  has_one :entry, :through=>:broker_invoice

  validates_presence_of :charge_description
  validates_presence_of :charge_amount

  def duty_charge_type? 
    charge_type && charge_type.upcase == "D"
  end

  def hst_gst_charge_code?
    ["250", "251", "252", "253", "254", "255", "256", "257", "258", "259", "260"].include? charge_code
  end
end
