module OpenChain; module CustomHandler; module Target; module TargetSupport
  extend ActiveSupport::Concern

  # Builds the unique part identifier we're going to use for Target parts
  #
  # dpci is basically the unique item number for Target (DPCI = DePartment / Class / Item)
  # Vendor Order Point is essentially a code for the Factory.  Because some tariff data
  # differs between factories, we're having to concatenate the two together to make a fully
  # unique part number in CM.
  def build_part_number dpci, vendor_order_point
    dpci + "-" + vendor_order_point
  end

  def split_part_number part_number
    split = part_number.split("-")

    if split.length > 0
      [split[0..-2].join("-"), split[-1]]
    else
      [part_number, nil]
    end
  end

end; end; end; end