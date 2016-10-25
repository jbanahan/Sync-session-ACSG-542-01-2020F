require 'open_chain/entity_compare/comparator_helper'

module OpenChain; module EntityCompare; module ProductComparator
  extend ActiveSupport::Concern
  include OpenChain::EntityCompare::ComparatorHelper

  def accept? snapshot
    return snapshot.recordable_type == "Product"
  end

  def get_hts classi_hsh
    json_child_entities(classi_hsh, "TariffRecord").first.try(:[], "model_fields").try(:[],"hts_hts_1")
  end

end; end; end