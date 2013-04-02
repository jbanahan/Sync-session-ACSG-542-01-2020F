#Set delayed job worker timeout
Delayed::Worker.max_run_time = 12.hours

#reference any classes that will be sent to delayed job here to make sure the environment is aware of them

require 'open_chain/bulk_update'
require 'open_chain/custom_handler/generic_alliance_product_generator'

OpenChain::BulkUpdateClassification
OpenChain::CustomHandler::GenericAllianceProductGenerator
