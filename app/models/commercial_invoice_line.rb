class CommercialInvoiceLine < ActiveRecord::Base
  belongs_to :commercial_invoice, :inverse_of=>:commercial_invoice_lines
  has_many :commercial_invoice_tariffs, :dependent=>:destroy
  has_many :change_records, :as => :recordable
  include CustomFieldSupport
  include LinesSupport
end
