# == Schema Information
#
# Table name: automated_billing_setups
#
#  id              :integer          not null, primary key
#  customer_number :string(255)
#  enabled         :boolean
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

# This is essentially a setup for automated 210 XML docs to be sent out from Entry Broker Invoices.
class AutomatedBillingSetup < ActiveRecord::Base
  has_many :search_criterions, dependent: :destroy, autosave: true
  validates :customer_number, presence: true

  def sendable? entry
    return false unless self.enabled?
    return false if self.customer_number.blank? || (entry.customer_number.to_s.strip.upcase != self.customer_number.strip.upcase)

    tests = self.search_criterions.map {|sc| sc.test? entry}.uniq.compact

    # If there were no criterions, then we send...otherwise, the tests result should 
    # all have been true, in which case after uniq'ing the results the only value should be true
    tests.length == 0 || (tests.length == 1 && tests[0] == true)
  end
end
