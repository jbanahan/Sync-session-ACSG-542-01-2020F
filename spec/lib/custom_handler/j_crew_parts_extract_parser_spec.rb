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
      expect(File).to receive(:open).with(path, "r:Windows-1252:UTF-8").and_yield io
      expect_any_instance_of(OpenChain::CustomHandler::JCrewPartsExtractParser).to receive(:generate_and_send).with(io)

      OpenChain::CustomHandler::JCrewPartsExtractParser.process_file path
    end
  end

  context :process_s3 do
    it "should use s3 to process a file" do
      path = "/path/to/file.txt"
      file = double("file")
      expect(OpenChain::S3).to receive(:bucket_name).and_return("bucket")
      expect(OpenChain::S3).to receive(:download_to_tempfile).and_yield(file)
      expect(file).to receive(:path).and_return path
      io = double("IO")
      expect(File).to receive(:open).with(path, "r:Windows-1252:UTF-8").and_yield io

      expect_any_instance_of(OpenChain::CustomHandler::JCrewPartsExtractParser).to receive(:generate_and_send).with(io)
      OpenChain::CustomHandler::JCrewPartsExtractParser.process_s3 path
    end
  end

  context :process do
    it "should implement process by utilizing the s3 process" do
      custom_file = double("custom_file")
      attachment = double("attachment")
      user = double("user")
      messages = double("messages")

      allow(custom_file).to receive(:attached).and_return attachment
      allow(attachment).to receive(:path).and_return 'path/to/file.txt'
      allow(custom_file).to receive(:attached_file_name).and_return "file.txt"

      expect(OpenChain::CustomHandler::JCrewPartsExtractParser).to receive(:process_s3).with 'path/to/file.txt', OpenChain::S3.bucket_name(:production)


      expect(user).to receive(:messages).and_return messages
      expect(messages).to receive(:create).with({:subject => "J Crew Parts Extract File Complete", :body => "J Crew Parts Extract File 'file.txt' has finished processing."})

      OpenChain::CustomHandler::JCrewPartsExtractParser.new(custom_file).process user
    end

    it "should not process if custom file is missing" do
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.process double("user")
    end

    it "should not process if custom file has no attachment" do
      custom_file = double("custom_file")
      expect(custom_file).to receive(:attached).and_return nil
      OpenChain::CustomHandler::JCrewPartsExtractParser.new(custom_file).process double("user")
    end

    it "should not process if custom file has no path" do
      custom_file = double("custom_file")
      attachment = double("attachment")
      allow(custom_file).to receive(:attached).and_return attachment
      expect(attachment).to receive(:path).and_return nil
      OpenChain::CustomHandler::JCrewPartsExtractParser.new(custom_file).process double("user")
    end
  end

  context :generate_and_send do
    it "should generate extract data to a temp file and then ftp it" do
      @p = OpenChain::CustomHandler::JCrewPartsExtractParser.new nil

      io = double("io")
      tempfile = nil
      expect(@p).to receive(:generate_product_file) { |input, output|  
        expect(input).to eq(io)
        expect(output.binmode?).to be_truthy
        expect(File.basename(output.path)).to match(/^JCrewPartsExtract.+\.DAT$/)
        expect(output.class).to eq(Tempfile)
        tempfile = output
      }

      expect(@p).to receive(:ftp_file) {|file, opts|
        file.path == tempfile.path
        expect(opts[:keep_local]).to be_truthy

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
      expect(p.remote_file_name).to match(/^JPART.DAT$/)
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
      expect(line1[0, 20]).to eq("1620194".ljust(20))
      # Season
      expect(line1[20, 10]).to eq("SU1".ljust(10))
      # Article #
      expect(line1[30, 30]).to eq("23953".ljust(30))
      # HTS #
      expect(line1[60, 10]).to eq("6204624020")
      # Description (Trim'ed at 40 chars) (There's a hardcoded space between HTS and description)
      expect(line1[71, 40]).to eq("women's knit swim neon cali halter 82% p")
      # Cost (Also a hardcoded space between description and Cost)
      expect(line1[112, 10]).to eq(sprintf("%0.2f", BigDecimal.new("0.10")).ljust(10))
      # Country of Origin
      expect(line1[122, 2]).to eq("CN")

      # PO
      expect(line2[0, 20]).to eq("1632448".ljust(20))
      # Season
      expect(line2[20, 10]).to eq("HOL1".ljust(10))
      # Article #
      expect(line2[30, 30]).to eq("23346".ljust(30))
      # HTS # (should have been translated)
      expect(line2[60, 10]).to eq("1234567890")
      # The quote is here to verify we've worked around a parsing issue with quotation marks in the data
      expect(line2[71, 40]).to eq("womens knit swim cali hipster 82% polyes".ljust(40))
      # Cost (Also a hardcoded space between description and Cost)
      expect(line2[112, 10]).to eq(sprintf("%0.2f", BigDecimal.new("41.40")).ljust(10))
      # Country of Origin
      expect(line2[122, 2]).to eq("CN")
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
      expect(line1[20, 10]).to eq("SP34567891")
      # HTS Numbers that aren't 10 characters are stripped
      expect(line1[60, 10]).to eq("          ")
      expect(line1[71, 40]).to eq("women's knit swim neon cali halter 82% p")
      # Cost (Also a hardcoded space between description and Cost)
      expect(line1[112, 10]).to eq("1000000000")
      # Country of Origin
      expect(line1[122, 2]).to eq("  ")
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
      expect(line1[71, 40]).to eq("women's knit swim neon cali halter 82% p")
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

    it "should use a custom file to retrieve data from S3, process it, create a new temp file, and ftp the temp file", paperclip: true, s3: true do
    	p = OpenChain::CustomHandler::JCrewPartsExtractParser.new(@custom_file)
    	output = nil
    	# Underneath the covers, we generate a new instance of the 
    	# parser after downloading the S3 file (which is done statically)
    	expect_any_instance_of(OpenChain::CustomHandler::JCrewPartsExtractParser).to receive(:ftp_file) {|instance, file|
    		file.rewind
    		output = file.read
    	}
    	p.process(@user)
    	expect(output[0,20]).to eq("1620194".ljust(20))
    	@user.reload
    	message = @user.messages.first
    	expect(message.subject).to eq("J Crew Parts Extract File Complete")
    	expect(message.body).to eq("J Crew Parts Extract File '#{@custom_file.attached_file_name}' has finished processing.")
    end
  end

  context :can_view? do
    it "should allow master users to view" do
      user = Factory(:master_user)
      expect(OpenChain::CustomHandler::JCrewPartsExtractParser.new.can_view?(user)).to be_truthy
    end

    it "should prevent non-master users from viewing" do
      user = Factory(:user)
      expect(OpenChain::CustomHandler::JCrewPartsExtractParser.new.can_view?(user)).to be_falsey
    end
  end
end
