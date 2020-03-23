# == Schema Information
#
# Table name: intacct_receivable_lines
#
#  amount                :decimal(12, 2)
#  broker_file           :string(255)
#  charge_code           :string(255)
#  charge_description    :string(255)
#  created_at            :datetime         not null
#  freight_file          :string(255)
#  id                    :integer          not null, primary key
#  intacct_receivable_id :integer
#  line_of_business      :string(255)
#  location              :string(255)
#  updated_at            :datetime         not null
#  vendor_number         :string(255)
#  vendor_reference      :string(255)
#
# Indexes
#
#  index_intacct_receivable_lines_on_intacct_receivable_id  (intacct_receivable_id)
#

class IntacctReceivableLine < ActiveRecord::Base
  attr_accessible :amount, :broker_file, :charge_code, :charge_description, 
    :freight_file, :intacct_receivable_id, :intacct_receivable, :line_of_business, :location, 
    :vendor_number, :vendor_reference
  
  belongs_to :intacct_receivable, :inverse_of => :intacct_receivable_lines
end
