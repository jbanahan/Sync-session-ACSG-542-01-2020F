require 'spec_helper'

describe 'JCrewPartsExtractParser' do
  
  context :process_file do
    it "should open a file and call generate and send" do
      path = "/path/to/file.txt"
      io = double("IO")
      File.should_receive(:open).with(path, "rb").and_yield io
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

      OpenChain::CustomHandler::JCrewPartsExtractParser.any_instance.should_receive(:generate_and_send).with(file)
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

      @p.should_receive(:ftp_file) {|file|
        file.should == tempfile
      }

      @p.generate_and_send io
    end
  end

  context :remote_file_name do 
    it "should use current time + JCrew customer number" do
      file = OpenChain::CustomHandler::JCrewPartsExtractParser.new.remote_file_name
      file.should =~ /J0000.DAT$/
      #Make sure the time component of the file name is current
      (Time.now.to_i - (file.split("-")[0].to_i)).should <= 2
    end
  end

  context :generate_product_file do
    it "should read product data and translate it into the output format" do
    	# Tab-delimited data all copied from an actual J Crew file
    	# The data looks like it's a screen-print from a legacy type system
    	# Hence all the header data that is repeated every "page" ()
      file = <<FILE
	J.Crew Group											Print Date:		04/22/2013
	Report:	/JCREW/CUSTOMS_BROKER_REPORT										Print Time:		09:13:38
	User:		MJIANG									Page:			    1
	Transaction Code: ZM18
	PO #			Season	Article	HS #	Quota	Duty %	COO	FOB	PO Cost		Binding Ruling
					Description
	1618733			SP1	48774	6204624055	348	16.60	CN	HK	10.74
					98% COTTON 2% SPANDEX TWILL WOMENS WOVEN SHORT
	J.Crew Group											Print Date:		04/22/2013
	Report:	/JCREW/CUSTOMS_BROKER_REPORT										Print Time:		09:13:38
	User:		MJIANG									Page:			    2
	Transaction Code: ZM18
	PO #			Season	Article	HS #	Quota	Duty %	COO	FOB	PO Cost		Binding Ruling
					Description
	1621783			SU1	43644	6205904040	840	2.80	CN	CS	22.27
					Mens woven 100% yd linen shirt"      
FILE
      output = StringIO.new ""
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.generate_product_file(StringIO.new(file), output)
      output.rewind
      line1, line2 = output.read.split("\r\n")
      line1[0, 20].should == "1618733".ljust(20)
      line1[20, 30].should == "48774".ljust(30)
      line1[50, 10].should == "6204624055"
      # Trim'ed at 40 chars
      line1[60, 40].should == "98% COTTON 2% SPANDEX TWILL WOMENS WOVEN"
      line1[100, 2].should == "CN"

      line2[0, 20].should == "1621783".ljust(20)
      line2[20, 30].should == "43644".ljust(30)
      line2[50, 10].should == "6205904040"
      # The quote is here to verify we've worked around a parsing issue with quotation marks in the data
      line2[60, 40].should == "Mens woven 100% yd linen shirt\"".ljust(40)
      line2[100, 2].should == "CN"
    end

    it "should trim data to the correct lengths and exclude incorrect length values" do
      file = <<FILE
	123456789012345678901			SP1	1234567890123456789012345678901	62046240551	348	16.60	CNX	HK	10.74
					98% COTTON 2% SPANDEX TWILL WOMENS WOVEN SHORT
FILE
      output = StringIO.new ""
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.generate_product_file(StringIO.new(file), output)
      output.rewind
      line1 = output.read
      line1[0, 20].should == "12345678901234567890"
      line1[20, 30].should == "123456789012345678901234567890"
      # HTS Numbers that aren't 10 characters are stripped
      line1[50, 10].should == "".ljust(10)
      line1[60, 40].should == "98% COTTON 2% SPANDEX TWILL WOMENS WOVEN"
      line1[100, 2].should == "".ljust(2)
    end

    it "should output header data that's missing description data" do
      file = <<FILE
	1618733			SP1	48774	6204624055	348	16.60	CN	HK	10.74
	1621783			SU1	43644	6205904040	840	2.80	CN	CS	22.27
FILE
			output = StringIO.new ""
			OpenChain::CustomHandler::JCrewPartsExtractParser.new.generate_product_file(StringIO.new(file), output)
			output.rewind
			line1, line2 = output.read.split("\r\n")
			line1[0, 20].should == "1618733".ljust(20)
			line1[60, 40].should == "".ljust(40)
			line2[0, 20].should == "1621783".ljust(20)
			line2[60, 40].should == "".ljust(40)
    end
  end

  context :integration_test do
    before :each do
      file = <<FILE
	J.Crew Group											Print Date:		04/22/2013
	Report:	/JCREW/CUSTOMS_BROKER_REPORT										Print Time:		09:13:38
	User:		MJIANG									Page:			    1
	Transaction Code: ZM18
	PO #			Season	Article	HS #	Quota	Duty %	COO	FOB	PO Cost		Binding Ruling
					Description
	1618733			SP1	48774	6204624055	348	16.60	CN	HK	10.74
					98% COTTON 2% SPANDEX TWILL WOMENS WOVEN SHORT      
FILE
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
    	output[0,20].should == "1618733".ljust(20)
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
