require 'zip/zip'
module OpenChain
  module CustomHandler
    #responsible for loading zip files of Amscan product images from their CDs which are loaded to S3 as zip files
    class AmscanZipLoader
      def self.process_s3 s3_bucket, s3_key
        t = nil
        begin
          t = OpenChain::S3.download_to_tempfile(s3_bucket, s3_key)
          process_zip t.path
        ensure
          t.unlink if t
        end
      end

      def self.process_zip local_zip_path
        Zip::ZipFile.foreach(local_zip_path) {|z| process_zip_entry z}
      end
      
      def self.process_zip_entry zip_entry
        r = nil
        entry_name = zip_entry.name
        if entry_name.downcase.ends_with?('.jpg')
          name = entry_name.split("/").last.split("\\").last
          ext_file_path = "tmp/#{name}"
          begin
            zip_entry.extract ext_file_path
            r = LinkableAttachmentImportRule.import(ext_file_path,name,"/AMSCAN-ZIP",match_value(name))
          ensure
            File.delete ext_file_path if File.exists? ext_file_path
          end
        end
        r
      end

      private 
      def self.match_value(original_name)
        #remove file extension
        x = original_name.split(".")
        x.pop
        x = x.join(".")
        elements = x.split("_")
        r = elements[0]
        if elements[1] && elements[1].match(/^[0-9]*$/)
          r << ".#{elements[1]}"
        end
        "AMSCAN-#{r}"
      end

    end
  end
end

