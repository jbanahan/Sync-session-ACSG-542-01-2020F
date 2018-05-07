require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/uncancelled_shipment_comparator'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberFactoryPackShipmentComparator
  extend OpenChain::EntityCompare::UncancelledShipmentComparator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::FtpFileSupport

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    self.new.compare(id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
  end

  def initialize
    @cdefs = self.class.prep_custom_definitions([:shp_factory_pack_revised_date])
  end

  def compare id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    old_json = get_json_hash(old_bucket, old_path, old_version)
    factory_pack_revised_date = @cdefs[:shp_factory_pack_revised_date]
    old_factory_pack_revised_date = mf(old_json, factory_pack_revised_date.model_field_uid)
    old_packing_list_sent_date = mf(old_json, 'shp_packing_list_sent_date')

    new_json = get_json_hash(new_bucket, new_path, new_version)
    new_factory_pack_revised_date = mf(new_json, factory_pack_revised_date.model_field_uid)
    new_packing_list_sent_date = mf(new_json, 'shp_packing_list_sent_date')

    if (old_factory_pack_revised_date != new_factory_pack_revised_date || old_packing_list_sent_date != new_packing_list_sent_date)
      shipment = Shipment.where(id: id).first
      if shipment
        Lock.with_lock_retry(shipment) do
          send_factory_pack_csv shipment
        end
      end
    end
  end

  private
    def send_factory_pack_csv shipment
      csv = OpenChain::CustomHandler::LumberLiquidators::LumberFactoryPackCsvGenerator.generate_csv shipment
      sr = shipment.sync_records.where(trading_partner: 'Factory Pack Declaration').first_or_initialize

      Tempfile.open(["factory_pack_#{shipment.reference}_",'.csv']) do |tf|
        tf.write csv
        tf.flush
        current_time = Time.zone.now
        Attachment.add_original_filename_method tf, "FP_#{shipment.reference}_#{current_time.strftime('%Y%m%d%H%M%S')}.csv"

        ftp_sync_file tf, sr, connect_vfitrack_net(ftp_directory)

        sr.update_attributes! sent_at: current_time, confirmed_at: (current_time + 1.minute)
      end
    end

    def ftp_directory
      folder = "to_ecs/lumber_factory_pack#{MasterSetup.get.production? ? '' : '_test'}"
      folder
    end

end; end; end; end;