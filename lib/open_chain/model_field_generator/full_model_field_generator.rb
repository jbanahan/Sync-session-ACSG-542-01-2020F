require 'open_chain/model_field_generator/address_generator'
require 'open_chain/model_field_generator/attachment_generator'
require 'open_chain/model_field_generator/broker_invoice_entry_field_generator'
require 'open_chain/model_field_generator/comment_generator'
require 'open_chain/model_field_generator/company_generator'
require 'open_chain/model_field_generator/country_generator'
require 'open_chain/model_field_generator/division_generator'
require 'open_chain/model_field_generator/hts_generator'
require 'open_chain/model_field_generator/last_changed_by_generator'
require 'open_chain/model_field_generator/master_setup_generator'
require 'open_chain/model_field_generator/port_generator'
require 'open_chain/model_field_generator/product_generator'
require 'open_chain/model_field_generator/sync_record_generator'

module OpenChain; module ModelFieldGenerator; module FullModelFieldGenerator
  include OpenChain::ModelFieldGenerator::AddressGenerator
  include OpenChain::ModelFieldGenerator::AttachmentGenerator
  include OpenChain::ModelFieldGenerator::BrokerInvoiceEntryFieldGenerator
  include OpenChain::ModelFieldGenerator::CommentGenerator
  include OpenChain::ModelFieldGenerator::CompanyGenerator
  include OpenChain::ModelFieldGenerator::CountryGenerator
  include OpenChain::ModelFieldGenerator::DivisionGenerator
  include OpenChain::ModelFieldGenerator::HtsGenerator
  include OpenChain::ModelFieldGenerator::LastChangedByGenerator
  include OpenChain::ModelFieldGenerator::MasterSetupGenerator
  include OpenChain::ModelFieldGenerator::PortGenerator
  include OpenChain::ModelFieldGenerator::ProductGenerator
  include OpenChain::ModelFieldGenerator::SyncRecordGenerator
end; end; end
