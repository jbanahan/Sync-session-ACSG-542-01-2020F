require 'open_chain/custom_handler/vfitrack_custom_definition_support'

class InitializeCustomFieldsFor1793 < ActiveRecord::Migration
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def up
    # Only run this migration on WWW system
    if MasterSetup.get.custom_feature?("WWW")
      self.class.prep_custom_definitions([:prod_fda_container_type, :prod_fda_items_per_inner_container, :prod_fda_contact_title, :prod_fda_model_number,
                                          :prod_fda_manufacture_date, :prod_fda_exclusion_reason, :prod_fda_unknown_reason, :prod_fda_accession_number,
                                          :prod_fda_manufacturer_name, :prod_fda_warning_accepted, :prod_lacey_component_of_article, :prod_lacey_genus_1,
                                          :prod_lacey_species_1, :prod_lacey_genus_2, :prod_lacey_species_2, :prod_lacey_country_of_harvest, :prod_lacey_quantity,
                                          :prod_lacey_quantity_uom, :prod_lacey_percent_recycled, :prod_lacey_preparer_name, :prod_lacey_preparer_email, 
                                          :prod_lacey_preparer_phone])
    end
  end

  def down
    # Don't do anything here - just let the migration rollback - this allows us to possibly run it again if necessary.
    # In this case, that won't harm anything (and make it easier on us in dev if need to re-run)
  end
end
