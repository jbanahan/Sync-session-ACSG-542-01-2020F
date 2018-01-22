# == Schema Information
#
# Table name: broker_invoice_lines
#
#  id                 :integer          not null, primary key
#  broker_invoice_id  :integer
#  charge_code        :string(255)
#  charge_description :string(255)
#  charge_amount      :decimal(11, 2)
#  vendor_name        :string(255)
#  vendor_reference   :string(255)
#  charge_type        :string(255)
#  created_at         :datetime
#  updated_at         :datetime
#  hst_percent        :decimal(4, 3)
#
# Indexes
#
#  index_broker_invoice_lines_on_broker_invoice_id  (broker_invoice_id)
#  index_broker_invoice_lines_on_charge_code        (charge_code)
#

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
