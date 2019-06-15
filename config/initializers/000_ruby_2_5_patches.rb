# The following is required to patch issues related to upgrading to Ruby 2.5.
# Once we're on Rails 4 (perhaps 5) this can likely be removed since they support 2.5 officially.

if RUBY_VERSION =~ /^2\.[456789]/

  ## This Monkey Patches BigDecimal to restore how it worked prior to Ruby 2.4 
  ## There's too many spots in our code at the moment that need fixing and other gems 
  ## that are not updated for 2.4 behavior (rails specifically) that I don't want to deal
  ## with the ArgumentError it raises for something like BigDecimal("notanumber"), rather than returning "0".

  class BigDecimal < Numeric
    alias :old_initialize :initialize

    def initialize digits, *args
      begin
        old_initialize(digits, *args)
      rescue ArgumentError => e
        raise e unless e.message =~ /invalid value for BigDecimal\(\)/
        old_initialize("0", *args)
      end
    end
  end

  module Kernel
    def BigDecimal *args
      BigDecimal.new(*args)
    end
  end

  ### End BigDecimal patch ###
end