require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module Generic; module GenericCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    ordln_country_of_harvest: {cdef_uid: 'ordln_country_of_harvest', label: 'Country of Harvest', data_type: :string, module_type: 'OrderLine'},
    prod_genus: {cdef_uid: 'prod_genus', label: 'Genus', data_type: :string, module_type: 'Product'},
    prod_species: {cdef_uid: 'prod_species', label: 'Species', data_type: :string, module_type: 'Product'},
    prod_cites: {cdef_uid: 'prod_cities', label: 'CITIES', data_type: :boolean, module_type: 'Product'}
  }

  def self.included(base)
    base.extend(::OpenChain::CustomHandler::CustomDefinitionSupport)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def prep_custom_definitions fields
      prep_custom_defs fields, CUSTOM_DEFINITION_INSTRUCTIONS
    end
  end
end; end; end; end
