require 'open_chain/custom_handler/generator_315/shared_315_support'
require 'open_chain/custom_handler/generator_315/tradelens/tradelens_client'
require 'open_chain/custom_handler/generator_315/tradelens/request_data_extractor'
require 'open_chain/custom_handler/generator_315/tradelens/data_315_filler'

# Subclasses should also be required in Entry315TradelensGenerator
# The inheritor of this class must implement
#  endpoint
# And can optionally implement
#  create_315_data

module OpenChain; module CustomHandler; module Generator315; module Tradelens; class EntryFieldHandler
  include OpenChain::CustomHandler::Generator315::Shared315Support

  SUBCLASSES ||= {customs_release: "OpenChain::CustomHandler::Generator315::Tradelens::CustomsReleaseHandler",
                  customs_hold: "OpenChain::CustomHandler::Generator315::Tradelens::CustomsHoldHandler"}.freeze

  def self.endpoint_labels
    SUBCLASSES.keys.map { |k| [k, k.to_s.titleize] }.to_h
  end

  def self.handler field
    # xref keys are model-field UIDs for milestone UI. Remove the prefixes.
    xrefs = DataCrossReference.get_all_pairs("tradelens_entry_milestone_fields")
                              .transform_keys { |k| k.sub(/^ent_/, '') }
    handler_type = xrefs[field].to_sym
    SUBCLASSES[handler_type].constantize.new
  end

  def endpoint
    raise NotImplementedError
  end

  def create_315_data entry, data, milestone
    filler = data_315_filler(entry, data, milestone)
    filler.data_315
  end

  def send_milestone data_315
    request_hsh = request_data(data_315)
    clt = client
    session = ApiSession.new class_name: self.class.name, endpoint: clt.url, retry_count: 0

    Tempfile.open(["#{session.short_class_name}_request_", ".json"]) do |t|
      t.binmode
      t << request_hsh.to_json
      t.flush
      att = Attachment.new(attachment_type: "request", attached_file_name: File.basename(t), attached: t, uploaded_by: User.integration)
      session.request_file = att
    end

    session.save!
    clt.send_milestone(request_hsh, session.id, delay: true)

    session
  end

  def data_315_filler entry, data, milestone
    filler = Data315Filler.new(entry, data, milestone)
    filler.create_315_data
  end

  def request_data data_315
    RequestDataExtractor.new(data_315).request
  end

  def client
    OpenChain::CustomHandler::Generator315::Tradelens::TradelensClient.new endpoint
  end

  end; end; end; end; end
