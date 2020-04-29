require 'open_chain/custom_handler/polo/polo_abstract_product_xml_generator'

module OpenChain; module CustomHandler; module Polo; class PoloLogisticaProductXmlGenerator < OpenChain::CustomHandler::Polo::PoloAbstractProductXmlGenerator

  def sync_code
    'logistica'
  end

  def ftp_credentials
    folder = "to_ecs/rl_logistica_product"
    folder += "_test" unless MasterSetup.get.production?

    connect_vfitrack_net folder
  end

end; end; end; end