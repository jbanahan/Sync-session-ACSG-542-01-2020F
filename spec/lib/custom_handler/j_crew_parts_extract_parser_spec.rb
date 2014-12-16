require 'spec_helper'

describe 'JCrewPartsExtractParser' do

  before :each do 
    # Create a J Crew company record (otherwise the process blows up).
    @j_crew = Factory(:company, :alliance_customer_number => "J0000")
  end
  
  context :process_file do
    it "should open a file and call generate and send" do
      path = "/path/to/file.txt"
      io = double("IO")
      File.should_receive(:open).with(path, "r:Windows-1252:UTF-8").and_yield io
      OpenChain::CustomHandler::JCrewPartsExtractParser.any_instance.should_receive(:generate_and_send).with(io)

      OpenChain::CustomHandler::JCrewPartsExtractParser.process_file path
    end
  end

  context :process_s3 do
    it "should use s3 to process a file" do
      path = "/path/to/file.txt"
      file = double("file")
      OpenChain::S3.should_receive(:bucket_name).and_return("bucket")
      OpenChain::S3.should_receive(:download_to_tempfile).and_yield(file)
      file.should_receive(:path).and_return path
      io = double("IO")
      File.should_receive(:open).with(path, "r:Windows-1252:UTF-8").and_yield io

      OpenChain::CustomHandler::JCrewPartsExtractParser.any_instance.should_receive(:generate_and_send).with(io)
      OpenChain::CustomHandler::JCrewPartsExtractParser.process_s3 path
    end
  end

  context :process do
    it "should implement process by utilizing the s3 process" do
      custom_file = double("custom_file")
      attachment = double("attachment")
      user = double("user")
      messages = double("messages")

      custom_file.stub(:attached).and_return attachment
      attachment.stub(:path).and_return 'path/to/file.txt'
      custom_file.stub(:attached_file_name).and_return "file.txt"

      OpenChain::CustomHandler::JCrewPartsExtractParser.should_receive(:process_s3).with 'path/to/file.txt', OpenChain::S3.bucket_name(:production)


      user.should_receive(:messages).and_return messages
      messages.should_receive(:create).with({:subject => "J Crew Parts Extract File Complete", :body => "J Crew Parts Extract File 'file.txt' has finished processing."})

      OpenChain::CustomHandler::JCrewPartsExtractParser.new(custom_file).process user
    end

    it "should not process if custom file is missing" do
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.process double("user")
    end

    it "should not process if custom file has no attachment" do
      custom_file = double("custom_file")
      custom_file.should_receive(:attached).and_return nil
      OpenChain::CustomHandler::JCrewPartsExtractParser.new(custom_file).process double("user")
    end

    it "should not process if custom file has no path" do
      custom_file = double("custom_file")
      attachment = double("attachment")
      custom_file.stub(:attached).and_return attachment
      attachment.should_receive(:path).and_return nil
      OpenChain::CustomHandler::JCrewPartsExtractParser.new(custom_file).process double("user")
    end
  end

  context :generate_and_send do
    it "should generate extract data to a temp file and then ftp it" do
      @p = OpenChain::CustomHandler::JCrewPartsExtractParser.new nil

      io = double("io")
      tempfile = nil
      @p.should_receive(:generate_product_file) { |input, output|  
        input.should == io
        output.binmode?.should be_true
        File.basename(output.path).should =~ /^JCrewPartsExtract.+\.DAT$/
        output.class.should == Tempfile
        tempfile = output
      }

      @p.should_receive(:ftp_file) {|file, opts|
        file.path == tempfile.path
        opts[:keep_local].should be_true

        # simulate closing the file reference like ftp'ing does so we make sure
        # we're handling this case
        file.close
      }

      @p.generate_and_send io
    end
  end

  context :remote_file_name do 
    it "should use JCrew customer numbers" do
    	p = OpenChain::CustomHandler::JCrewPartsExtractParser.new
      p.remote_file_name.should =~ /^JPART.DAT$/
    end
  end

  context :generate_product_file do
    it "should read product data and translate it into the output format" do
    	us = Factory(:country, :iso_code=>"US")
    	HtsTranslation.create :company_id => @j_crew.id, :country_id => us.id, :hts_number => "6204312010", :translated_hts_number => "1234567890"

    	# This data was copied from an actual J Crew file
    	# The data looks like it's a screen-print from a legacy type system
    	# Hence all the header data that is repeated every "page"
      file = <<FILE
      J.Crew Group                                                                                                                                      Print Date: 03/10/2014
      Report:  /JCREW/CUSTOMS_BROKER_REPORT                                                                                                             Print Time: 09:35:37
      User:     DJIANG                                                                                                                                  Page:                1
      Transaction Code: ZM18



      PO #              Season        Article        HS #                     Quota            Duty %               COO        FOB          PO Cost             Binding Ruling
                                      Description



      1620194           SU1           23953          6204624020               348              16.60                CN         HK           0.10
                                      women's knit swim neon cali halter 82% polyester 18% elastane

      1632448           HOL1          23346          6204312010               435              17.50                CN         HK           41.40
                                      womens knit swim cali hipster 82% polyester 18% elastane

FILE
      output = StringIO.new ""
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.generate_product_file(StringIO.new(file.gsub("\n", "\r\n")), output)
      output.rewind
      line1, line2 = output.read.split("\r\n")
      # PO
      line1[0, 20].should == "1620194".ljust(20)
      # Season
      line1[20, 10].should == "SU1".ljust(10)
      # Article #
      line1[30, 30].should == "23953".ljust(30)
      # HTS #
      line1[60, 10].should == "6204624020"
      # Description (Trim'ed at 40 chars) (There's a hardcoded space between HTS and description)
      line1[71, 40].should == "women's knit swim neon cali halter 82% p"
      # Cost (Also a hardcoded space between description and Cost)
      line1[112, 10].should == sprintf("%0.2f", BigDecimal.new("0.10")).ljust(10)
      # Country of Origin
      line1[122, 2].should == "CN"

      # PO
      line2[0, 20].should == "1632448".ljust(20)
      # Season
      line2[20, 10].should == "HOL1".ljust(10)
      # Article #
      line2[30, 30].should == "23346".ljust(30)
      # HTS # (should have been translated)
      line2[60, 10].should == "1234567890"
      # The quote is here to verify we've worked around a parsing issue with quotation marks in the data
      line2[71, 40].should == "womens knit swim cali hipster 82% polyes".ljust(40)
      # Cost (Also a hardcoded space between description and Cost)
      line2[112, 10].should == sprintf("%0.2f", BigDecimal.new("41.40")).ljust(10)
      # Country of Origin
      line2[122, 2].should == "CN"
    end

    it "should trim data to the correct lengths and exclude incorrect length values" do
      file = <<FILE
	1620194           SP3456789123  23953          62046240                 348              16.60                CNT        HK           10000000000        
                                  women's knit swim neon cali halter 82% polyester 18% elastane
FILE
      output = StringIO.new ""
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.generate_product_file(StringIO.new(file.gsub("\n", "\r\n")), output)
      output.rewind
      line1 = output.read

      # Season
      line1[20, 10].should == "SP34567891"
      # HTS Numbers that aren't 10 characters are stripped
      line1[60, 10].should == "          "
      line1[71, 40].should == "women's knit swim neon cali halter 82% p"
      # Cost (Also a hardcoded space between description and Cost)
      line1[112, 10].should == "1000000000"
      # Country of Origin
      line1[122, 2].should == "  "
    end

    it "transliterates UTF-8 chars" do
      # NOTE: the description has one of those non-ascii angled apostrophes for this test (JCREW does send us these)
      file = <<FILE
      1620194            SU1           23953          6204624020               348              16.60                CN         HK           0.10
                                      women‘s knit swim neon cali halter 82% polyester 18% elastane
FILE
      output = StringIO.new ""
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.generate_product_file(StringIO.new(file.gsub("\n", "\r\n")), output)
      output.rewind
      line1 = output.read
      line1[71, 40].should == "women's knit swim neon cali halter 82% p"
    end

    it "should raise an error if J Crew company doesn't exist" do
      @j_crew.destroy

      expect {
        OpenChain::CustomHandler::JCrewPartsExtractParser.new.generate_product_file nil, nil
      }.to raise_error "Unable to process J Crew Parts Extract file because no company record could be found with Alliance Customer number 'J0000'."
    end
  end

  context :integration_test do
    before :each do
      file = <<FILE
      1620194           SU1           23953          6204624020               348              16.60                CN         HK           0.10
                                      women's knit swim neon cali halter 82% polyester 18% elastane
FILE
      file.gsub! "\n", "\r\n"
			@user = Factory(:master_user)
			@custom_file = nil
			Tempfile.open(['JcrewTest', '.DAT']) do |t|
				t.binmode
				t.write file
				t.flush
				t.rewind
				@custom_file = CustomFile.create!
				@custom_file.attached = t
				@custom_file.save!
			end
    end

    after :each do
    	@custom_file.delete if @custom_file
    end

    it "should use a custom file to retrieve data from S3, process it, create a new temp file, and ftp the temp file" do
    	p = OpenChain::CustomHandler::JCrewPartsExtractParser.new(@custom_file)
    	output = nil
    	# Underneath the covers, we generate a new instance of the 
    	# parser after downloading the S3 file (which is done statically)
    	OpenChain::CustomHandler::JCrewPartsExtractParser.any_instance.should_receive(:ftp_file) {|file|
    		file.rewind
    		output = file.read
    	}
    	p.process(@user)
    	output[0,20].should == "1620194".ljust(20)
    	@user.reload
    	message = @user.messages.first
    	message.subject.should == "J Crew Parts Extract File Complete"
    	message.body.should == "J Crew Parts Extract File '#{@custom_file.attached_file_name}' has finished processing."
    end
  end

  context :can_view? do
    it "should allow master users to view" do
      user = Factory(:master_user)
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.can_view?(user).should be_true
    end

    it "should prevent non-master users from viewing" do
      user = Factory(:user)
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.can_view?(user).should be_false
    end
  end
end
