require 'open_chain/sqs'
require 'open_chain/field_logic'

class OpenChain::AllianceImagingClient 

  # takes request for either search results or a set of primary keys and requests images for all entries
  def self.bulk_request_images search_run_id, primary_keys
    OpenChain::CoreModuleProcessor.bulk_objects(CoreModule::ENTRY,search_run_id,primary_keys) do |good_count, entry|
      OpenChain::AllianceImagingClient.request_images entry.broker_reference if entry.source_system=='Alliance'
    end
  end
  
  #not unit tested since it'll all be mocks
  def self.request_images file_number
    OpenChain::SQS.send_json "https://queue.amazonaws.com/468302385899/alliance-img-req-#{get_env}", {"file_number"=>file_number}
  end
  
  #not unit tested since it'll all be mocks
  def self.consume_images
    OpenChain::SQS.retrieve_messages_as_hash "https://queue.amazonaws.com/468302385899/alliance-img-doc-#{get_env}" do |hsh|
      t = OpenChain::S3.download_to_tempfile hsh["s3_bucket"], hsh["s3_key"]
      OpenChain::AllianceImagingClient.process_image_file t, hsh
    end
  end

  # The file passed in here must have the correct file extension for content type discovery or
  # it will likely be saved with the wrong content type.  ie. If you're saving a pdf, the file
  # it points to should have a .pdf extension on it.
  def self.process_image_file t, hsh
      def t.original_filename=(fn); @fn = fn; end
      def t.original_filename; @fn; end
      begin
        t.original_filename= hsh["file_name"]
        source_system = hsh["source_system"].nil? ? OpenChain::AllianceParser::SOURCE_CODE : hsh["source_system"]

        if source_system == OpenChain::FenixParser::SOURCE_CODE
          # The Fenix imaging client sends the entry number as "file_number" and not the broker ref

          # Create a shell entry record if there wasn't one, so we can actually attach the image.
          # We don't do this for Alliance files because Chain initiates the imaging extracts for it, so
          # there's no real valid scenario where an entry doesn't already exist in Chain.

          entry = Entry.where(:entry_number=>hsh['file_number'], :source_system=>source_system).first_or_create!(:file_logged_date => Time.zone.now)
        else
          entry = Entry.find_by_broker_reference_and_source_system hsh["file_number"], source_system
        end

        if entry
          att = entry.attachments.build
          att.attached = t
          att.attachment_type = hsh["doc_desc"]
          unless hsh["suffix"].blank?
            att.alliance_suffix = hsh["suffix"][2,3]
            att.alliance_revision = hsh["suffix"][0,2]
          end
          att.source_system_timestamp = hsh["doc_date"]
          att.save!
          att.attachable.attachments.where("NOT attachments.id = ?",att.id).where(:attachment_type=>att.attachment_type,:alliance_suffix=>att.alliance_suffix).where("alliance_revision <= ?",att.alliance_revision).destroy_all
        end
      rescue
        $!.log_me ["Alliance imaging client hash: #{hsh}"], [t]
      end

  end

  private 
  def self.get_env
    en = "dev"
    case Rails.env
      when "production"
        en = "prod"
      when "test"
        en = "test"
    end
    en
  end
end
