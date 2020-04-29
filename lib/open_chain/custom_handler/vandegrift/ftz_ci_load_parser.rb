require 'open_chain/custom_handler/vandegrift/standard_ci_load_parser'

module OpenChain; module CustomHandler; module Vandegrift; class FtzCiLoadParser < OpenChain::CustomHandler::Vandegrift::StandardCiLoadParser
  def parse_invoice_line entry, invoice, row
    l = super entry, invoice, row

    l.ftz_quantity = decimal_value row[23]
    l.ftz_zone_status = text_value row[24]
    l.ftz_priv_status_date = date_value row[25]

    l
  end


end; end; end; end
