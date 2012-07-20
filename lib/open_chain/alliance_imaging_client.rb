require 'open_chain/sqs'
#not unit tested since it'll all be mocks
class OpenChain::AllianceImagingClient 
  def self.request_images file_number
    OpenChain::SQS.send_json "https://queue.amazonaws.com/468302385899/alliance-img-req-#{get_env}", {"file_number"=>file_number}
  end
  def self.consume_images
    OpenChain::SQS.retrieve_messages_as_hash "https://queue.amazonaws.com/468302385899/alliance-img-doc-#{get_env}" do |hsh|
      t = OpenChain::S3.download_to_tempfile hsh["s3_bucket"], hsh["s3_key"]
      def t.original_filename=(fn); @fn = fn; end
      def t.original_filename; @fn; end
      begin
        t.original_filename= hsh["file_name"]
        entry = Entry.find_by_broker_reference_and_source_system hsh["file_number"], OpenChain::AllianceParser::SOURCE_CODE
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
