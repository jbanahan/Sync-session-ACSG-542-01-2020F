describe DownloadS3ObjectSupport do

  subject { Class.new { extend DownloadS3ObjectSupport } }

  let(:ms) { stub_master_setup }

  describe "download_attachment" do
    let(:attachment) { double("attach") }

    it "downloads an attachment with disposition defaulted" do
      expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return false
      url = double("redirect")
      expect(attachment).to receive(:secure_url).with(90.seconds, response_content_disposition: "inline").and_return url
      expect(subject).to receive(:redirect_to).with url

      subject.download_attachment attachment
    end

    it "downloads an attachment with disposition provided" do
      expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return false
      url = double("redirect")
      expect(attachment).to receive(:secure_url).with(90.seconds, response_content_disposition: "Something That Isn't Inline").and_return url
      expect(subject).to receive(:redirect_to).with url

      subject.download_attachment attachment, disposition:"Something That Isn't Inline"
    end

    it "downloads an attachment using proxy with disposition defaulted" do
      expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return true
      tf = double("tempfile")
      expect(attachment).to receive(:download_to_tempfile).and_yield tf
      expect(tf).to receive(:read).and_return "ABCDE"
      expect(attachment).to receive(:attached_file_name).and_return "arf.txt"
      expect(attachment).to receive(:attached_content_type).and_return "onomatopoeia"
      expect(subject).to receive(:send_data).with("ABCDE", stream: true, buffer_size: 4096, disposition: "attachment", filename: "arf.txt", type: "onomatopoeia")

      subject.download_attachment attachment
    end

    it "downloads an attachment using proxy with disposition provided" do
      expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return true
      tf = double("tempfile")
      expect(attachment).to receive(:download_to_tempfile).and_yield tf
      expect(tf).to receive(:read).and_return "ABCDE"
      expect(attachment).to receive(:attached_file_name).and_return "arf.txt"
      expect(attachment).to receive(:attached_content_type).and_return "onomatopoeia"
      expect(subject).to receive(:send_data).with("ABCDE", stream: true, buffer_size: 4096, disposition: "Something Else", filename: "arf.txt", type: "onomatopoeia")

      subject.download_attachment attachment, disposition:"Something Else"
    end

    it "downloads an attachment with proxy download option specified" do
      expect(ms).not_to receive(:custom_feature?)

      tf = double("tempfile")
      expect(attachment).to receive(:download_to_tempfile).and_yield tf
      expect(tf).to receive(:read).and_return "ABCDE"
      expect(attachment).to receive(:attached_file_name).and_return "arf.txt"
      expect(attachment).to receive(:attached_content_type).and_return "onomatopoeia"
      expect(subject).to receive(:send_data).with("ABCDE", stream: true, buffer_size: 4096, disposition: "attachment", filename: "arf.txt", type: "onomatopoeia")

      subject.download_attachment attachment, proxy_download:true
    end
  end

  describe "download_s3_object" do
    let(:bucket) { "the_bucket" }
    let(:path) { "the_path/the_file.txt" }

    it "downloads a file from S3 with args defaulted" do
      expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return false
      url = double("redirect")
      expect(OpenChain::S3).to receive(:url_for).with(bucket, path, 1.minute, { response_content_disposition: "inline" }).and_return url
      expect(subject).to receive(:redirect_to).with url

      subject.download_s3_object bucket, path
    end

    it "downloads a file from S3 with args provided" do
      expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return false
      url = double("redirect")
      expect(OpenChain::S3).to receive(:url_for).with(bucket, path, 2.minutes, { response_content_disposition: "Something That Isn't Inline", response_content_type: "onomatopoeia" }).and_return url
      expect(subject).to receive(:redirect_to).with url

      # filename isn't actually used here.
      subject.download_s3_object bucket, path, expires_in: 2.minutes, filename: "arf.txt", content_type: "onomatopoeia", disposition: "Something That Isn't Inline"
    end

    it "downloads a file using proxy with args defaulted" do
      expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return true
      tf = double("tempfile")
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(bucket, path).and_yield tf
      expect(tf).to receive(:read).and_return "ABCDE"
      expect(subject).to receive(:send_data).with("ABCDE", stream: true, buffer_size: 4096, disposition: "attachment", filename: "the_file.txt")

      subject.download_s3_object bucket, path
    end

    it "downloads an a file using proxy with args provided" do
      expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return true
      tf = double("tempfile")
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(bucket, path).and_yield tf
      expect(tf).to receive(:read).and_return "ABCDE"
      expect(subject).to receive(:send_data).with("ABCDE", stream: true, buffer_size: 4096, disposition: "Something Else", filename: "arf.txt", type: "onomatopoeia")

      # expires_in isn't actually used here.
      subject.download_s3_object bucket, path, expires_in: 2.minutes, filename: "arf.txt", content_type: "onomatopoeia", disposition: "Something Else"
    end

    it "downloads a file with proxy download option specified" do
      expect(ms).not_to receive(:custom_feature?)

      tf = double("tempfile")
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(bucket, path).and_yield tf
      expect(tf).to receive(:read).and_return "ABCDE"
      expect(subject).to receive(:send_data).with("ABCDE", stream: true, buffer_size: 4096, disposition: "attachment", filename: "the_file.txt")

      subject.download_s3_object bucket, path, proxy_download:true
    end
  end

end