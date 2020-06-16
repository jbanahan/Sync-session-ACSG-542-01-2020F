describe DownloadS3ObjectSupport do

  class FakeDownloadS3ObjectSupportController < ApplicationController
    include DownloadS3ObjectSupport
  end

  subject { FakeDownloadS3ObjectSupportController.new }

  let(:ms) { stub_master_setup }

  describe "download_attachment" do
    let(:attachment) do
      a = instance_double(Attachment)
      allow(a).to receive(:attached_file_name).and_return "file.txt"
      a
    end

    it "downloads an attachment with disposition defaulted" do
      expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return false
      url = double("redirect")
      expect(attachment).to receive(:secure_url).with(90.seconds, response_content_disposition: "inline; filename=\"file.txt\"; filename*=UTF-8''file.txt").and_return url
      expect(subject).to receive(:redirect_to).with url

      subject.download_attachment attachment
    end

    it "downloads an attachment with disposition provided" do
      expect(ms).to receive(:custom_feature?).with("Attachment Mask").and_return false
      url = double("redirect")
      expect(attachment).to receive(:secure_url).with(90.seconds, response_content_disposition: "attachment; filename=\"file.txt\"; filename*=UTF-8''file.txt").and_return url
      expect(subject).to receive(:redirect_to).with url

      subject.download_attachment attachment, disposition:"attachment"
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
      expect(subject).to receive(:send_data).with("ABCDE", stream: true, buffer_size: 4096, disposition: "attachment", filename: "arf.txt", type: "onomatopoeia")

      subject.download_attachment attachment, disposition:"attachment"
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
      expect(OpenChain::S3).to receive(:url_for).with(bucket, path, 2.minutes, { response_content_disposition: "attachment; filename=\"arf.txt\"; filename*=UTF-8''arf.txt", response_content_type: "onomatopoeia" }).and_return url
      expect(subject).to receive(:redirect_to).with url

      # filename isn't actually used here.
      subject.download_s3_object bucket, path, expires_in: 2.minutes, filename: "arf.txt", content_type: "onomatopoeia", disposition: "attachment"
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
      expect(subject).to receive(:send_data).with("ABCDE", stream: true, buffer_size: 4096, disposition: "attachment", filename: "arf.txt", type: "onomatopoeia")

      # expires_in isn't actually used here.
      subject.download_s3_object bucket, path, expires_in: 2.minutes, filename: "arf.txt", content_type: "onomatopoeia", disposition: "attachment"
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

  describe "content_disposition" do

    it "defaults to inline" do
      expect(subject.content_disposition(nil, nil)).to eq "inline"
    end

    it "generates standard inline content disposition with filename" do
      expect(subject.content_disposition("inline", "file.txt")).to eq "inline; filename=\"file.txt\"; filename*=UTF-8''file.txt"
    end

    it "generates standard attachment content disposition with filename" do
      expect(subject.content_disposition("attachment", "file.txt")).to eq "attachment; filename=\"file.txt\"; filename*=UTF-8''file.txt"
    end

    it "echoes back any other non-standard content disposition" do
      expect(subject.content_disposition('attachment; filename', nil)).to eq "attachment; filename"
    end

    it 'transliterates ASCII portion of filename from UTF-8' do
      expect(subject.content_disposition("inline", "råcëçâr.jpg")).to eq "inline; filename=\"racecar.jpg\"; filename*=UTF-8''r%C3%A5c%C3%AB%C3%A7%C3%A2r.jpg"
    end
  end
end