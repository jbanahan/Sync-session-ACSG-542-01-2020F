# We'll probably need of these, eventually
require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/entity_compare/order_comparator'
require 'open_chain/entity_compare/product_comparator'
require 'open_chain/entity_compare/shipment_comparator'

module OpenChain; module EntityCompare; module MultiClassComparator
  extend ActiveSupport::Concern

  # Returns a module that calls #accept? on the comparators for all specified core modules, returning
  # `true` if any of them do.
  def self.includes *modules
    Module.new do
      comparators = Array.wrap(modules).map do |m|
        comp = "OpenChain::EntityCompare::#{m}Comparator".constantize
        Class.new { extend comp }
      end

      define_method(:accept?) do |snapshot|
        comparators.any? { |m| m.accept? snapshot }
      end
    end
  end
end; end; end
