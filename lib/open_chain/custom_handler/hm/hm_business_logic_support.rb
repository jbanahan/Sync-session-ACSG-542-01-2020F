module OpenChain; module CustomHandler; module Hm; module HmBusinessLogicSupport
  extend ActiveSupport::Concern

  def extract_style_number_from_sku sku_number
    # H&M's sku number break down is as follows (SKU will be padded with leading zeroes to 18 digits)
    # We need to trim any leading zeros until the value is 16 chars and only then extract an article number

    # The first 7 digits of SKU is style number
    # Next 3 digits are color
    # Next 3 digits are season
    # Last 3 are size
    part = sku_number.to_s

    # Strip leading zeros until the part number is 16 digits long
    while(part.length > 16 && part[0] == "0")
      part = part.slice(1, part.length)
    end

    # All we care about is the Style Number, which is what is sent on the entry.  Nothing else.
    part[0..6]
  end

end; end; end; end;