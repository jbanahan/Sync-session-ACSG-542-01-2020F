# == Schema Information
#
# Table name: intacct_receivable_lines
#
#  id                    :integer          not null, primary key
#  intacct_receivable_id :integer
#  amount                :decimal(10, 2)
#  charge_code           :string(255)
#  charge_description    :string(255)
#  location              :string(255)
#  line_of_business      :string(255)
#  freight_file          :string(255)
#  broker_file           :string(255)
#  vendor_number         :string(255)
#  vendor_reference      :string(255)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_intacct_receivable_lines_on_intacct_receivable_id  (intacct_receivable_id)
#

class IntacctReceivableLine < ActiveRecord::Base
  belongs_to :intacct_receivable, :inverse_of => :intacct_receivable_lines
end
