require 'spec_helper'

describe OpenChain::AllianceImagingClient do
  describe :bulk_request_images do
    before :each do
      @e1 = Factory(:entry,:broker_reference=>'123456',:source_system=>'Alliance')
      @e2 = Factory(:entry,:broker_reference=>'654321',:source_system=>'Alliance')
      @e3 = Factory(:entry,:broker_reference=>'777777',:source_system=>'Fenix')
    end
    it 'should request based on primary keys' do
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('123456')
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('654321')
      OpenChain::AllianceImagingClient.bulk_request_images nil, [@e1.id,@e2.id]
    end
    it 'should request based on search_run_id' do
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('123456')
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('654321')
      ss = Factory(:search_setup,:module_type=>"Entry",:user=>Factory(:master_user))
      ss.search_runs.create!
      OpenChain::AllianceImagingClient.bulk_request_images ss.search_runs.first.id, nil
    end
    it 'should not request for non-alliance entries' do
      OpenChain::AllianceImagingClient.should_not_receive(:request_images)
      OpenChain::AllianceImagingClient.bulk_request_images nil, [@e3.id]
    end
  end

  describe :process_image_file do
    before :each do
      @e1 = Factory(:entry,:broker_reference=>'123456',:source_system=>'Alliance')
      @tempfile = Tempfile.new ["file", ".pdf"]
      @hash = {"file_name"=>"file.pdf", "file_number"=>"123456", "doc_desc"=>"Testing", 
                "suffix"=>"123456", "doc_date"=>Time.now}
    end

    after :each do
      @tempfile.close!
    end

    it 'should load an attachment into the entry with the proper content type' do
      OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

      entry = Entry.find(@e1.id)
      entry.attachments.size.should == 1
      entry.attachments[0].attached_content_type.should == "application/pdf"
      entry.attachments[0].attachment_type.should == @hash["doc_desc"]
      entry.attachments[0].source_system_timestamp.should_not be_nil
      entry.attachments[0].alliance_suffix = @hash["suffix"][2, 3]
      entry.attachments[0].alliance_suffix = @hash["suffix"][0, 2]
    end

    it 'should look for source_system in the message hash and use entry number to lookup for Fenix source system' do
      @hash["source_system"] = 'Fenix'
      @e1.update_attributes :source_system => 'Fenix', :entry_number => "#{@hash['file_number']}", :broker_reference => '654321'

      OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash

      entry = Entry.find(@e1.id)
      entry.attachments.size.should == 1
      entry.attachments[0].attached_content_type.should == "application/pdf"
      entry.attachments[0].attachment_type.should == @hash["doc_desc"]
      entry.attachments[0].source_system_timestamp.should_not be_nil
    end

    it 'should generate shell entry records when an entry is missing and the source system is Fenix' do
      # These are the only hash values we should currently expect from the Fenix imaging monitoring process
      @hash = {"source_system" => "Fenix", "file_number" => "123456", "doc_date" => Time.now, "file_name"=>"file.pdf", "doc_desc" => "Source Testing"}
      OpenChain::AllianceImagingClient.process_image_file @tempfile, @hash
      
      entry = Entry.find_by_entry_number_and_source_system @hash["file_number"], 'Fenix'
      entry.should_not be_nil
      entry.entry_number.should == @hash["file_number"]
      entry.source_system.should == 'Fenix'
      entry.file_logged_date.should >= (Time.zone.now - 1.minute)

      entry.attachments.size.should == 1
      entry.attachments[0].attached_content_type.should == "application/pdf"
      entry.attachments[0].attached_file_name.should == "file.pdf"
      entry.attachments[0].attachment_type.should == @hash["doc_desc"]
      entry.attachments[0].source_system_timestamp.should_not be_nil
    end
  end

  describe :consume_images do
    it "should use SQS queue to download messages and use the S3 client with tempfile to download the file" do
      # This is mostly just mocks, but I wanted to ensure the expected calls are actualy happening
      hash = {"file_name" => "file.txt", "s3_bucket" => "bucket", "s3_key" => "key"}
      t = double
      OpenChain::SQS.should_receive(:retrieve_messages_as_hash).with("https://queue.amazonaws.com/468302385899/alliance-img-doc-test").and_yield hash
      OpenChain::S3.should_receive(:download_to_tempfile).with(hash["s3_bucket"], hash["s3_key"]).and_return(t)
      OpenChain::AllianceImagingClient.should_receive(:process_image_file).with(t, hash)

      OpenChain::AllianceImagingClient.consume_images
    end
  end
end
