require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/uncancelled_shipment_comparator'
require 'open_chain/ftp_file_support'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberIsfShipmentComparator
  extend OpenChain::EntityCompare::UncancelledShipmentComparator
  include OpenChain::FtpFileSupport
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def self.accept? snapshot
    super(snapshot) && snapshot.recordable.try(:isf_sent_at).present?
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    self.new.compare(id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
  end

  def initialize
    @cdefs = self.class.prep_custom_definitions([:shp_isf_revised_date])
  end

  def compare id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    old_json = get_json_hash(old_bucket, old_path, old_version)
    isf_revised_date = @cdefs[:shp_isf_revised_date]
    old_isf_revised_date = mf(old_json, isf_revised_date.model_field_uid)
    old_isf_sent_date = mf(old_json, 'shp_isf_sent_at')

    new_json = get_json_hash(new_bucket, new_path, new_version)
    new_isf_sent_date = mf(new_json, 'shp_isf_sent_at')
    new_isf_revised_date = mf(new_json, isf_revised_date.model_field_uid)

    if (old_isf_sent_date != new_isf_sent_date || old_isf_revised_date != new_isf_revised_date)
      shipment = Shipment.where(id: id).first
      if shipment
        Lock.with_lock_retry(shipment) do
          send_isf_xml shipment
        end
      end
    end
  end

  private
    def send_isf_xml shipment
      doc = OpenChain::CustomHandler::LumberLiquidators::LumberIsfShipmentXmlGenerator.generate_xml shipment
      sr = shipment.sync_records.where(trading_partner: 'ISF').first_or_initialize

      Tempfile.open(["isf_#{shipment.reference}_",'.xml']) do |tf|
        doc.write tf
        tf.flush
        current_time = Time.zone.now
        Attachment.add_original_filename_method tf, "ISF_#{shipment.reference}_#{current_time.strftime('%Y%m%d%H%M%S')}.xml"

        ftp_sync_file tf, sr, connect_vfitrack_net(ftp_directory)

        sr.update_attributes! sent_at: current_time, confirmed_at: (current_time + 1.minute)
      end
    end

    def ftp_directory
      folder = "to_ecs/lumber_isf#{MasterSetup.get.production? ? '' : '_test'}"
      folder
    end

end; end; end; end;