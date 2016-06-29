module OpenChain; module CustomHandler; module LandsEnd; class LeCanadaPlusProcessor
   
  def self.process_from_s3 bucket, key
    OpenChain::S3.download_to_tempfile(bucket, key) do |tempfile|
      process_zip tempfile
    end
  end

  def self.process_zip file
    Zip::File.open(file.path) do |zip_file|
      zip_file.each do |z|
        if File.extname(z.name) == ".txt"
          Tempfile.open(["le_drawback", ".txt"]) do |t|
            z.extract(t.path) {true}
            att_name = "#{File.basename(z.name, ".*")}_#{Time.now.strftime('%Y%m%d')}#{File.extname(z.name)}"
            Attachment.add_original_filename_method(t, att_name)
            create_upload t
          end
        end
      end
    end
  end

  private

  def self.create_upload file
    att = Attachment.new(attached: file)
    duf = DrawbackUploadFile.create!(processor: "lands_end_exports", start_at: 0.seconds.ago, attachment: att)
    duf.process User.integration
  end

end; end; end; end;