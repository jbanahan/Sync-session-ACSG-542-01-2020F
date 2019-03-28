require 'open_chain/entity_compare/product_comparator'

module OpenChain; module CustomHandler; module Polo; class PoloNonTextileProductComparator
  extend OpenChain::EntityCompare::ProductComparator
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    self.new.compare(id)
  end

  def compare id
    product = Product.where(id: id).first
    if product
      Lock.db_lock(product) do
        knit_woven = product.custom_value(cdefs[:knit_woven])
        new_non_textile_value = ["KNIT", "WOVEN"].include?(knit_woven.to_s.strip.upcase) ? "N" : "Y"

        non_textile = product.custom_value(cdefs[:non_textile])

        if new_non_textile_value != non_textile
          product.update_custom_value! cdefs[:non_textile], new_non_textile_value
          product.create_snapshot User.integration, nil, "Non Textile Product Comparator"
        end
      end
    end
  end

  def cdefs
    self.class.prep_custom_definitions([:knit_woven, :non_textile])
  end

end; end; end; end;