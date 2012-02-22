class CommercialInvoice < ActiveRecord::Base
  include CoreObjectSupport
  has_many :commercial_invoice_lines, :dependent => :destroy
  belongs_to :entry
end
