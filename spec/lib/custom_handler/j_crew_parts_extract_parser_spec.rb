require 'spec_helper'

describe OpenChain::CustomHandler::JCrewPartsExtractParser do

  before :each do 
    # Create a J Crew company record (otherwise the process blows up).
    @j_crew = Factory(:company, :alliance_customer_number => "JCREW")
    @country = Factory(:country, iso_code: 'US')
    @cdefs ||= described_class.prep_custom_definitions([:prod_part_number, :prod_country_of_origin])
  end
  
  context "process_file" do
    it "should open a file and call generate and send" do
      path = "/path/to/file.txt"
      io = double("IO")
      expect(File).to receive(:open).with(path, "r:utf-16le").and_yield io
      expect_any_instance_of(OpenChain::CustomHandler::JCrewPartsExtractParser).to receive(:create_parts).with(io, 'file.txt')

      OpenChain::CustomHandler::JCrewPartsExtractParser.process_file path, "file.txt"
    end
  end

  context "process_s3" do
    it "should use s3 to process a file" do
      path = "/path/to/file.txt"
      file = double("file")
      expect(OpenChain::S3).to receive(:bucket_name).and_return("bucket")
      expect(OpenChain::S3).to receive(:download_to_tempfile).and_yield(file)
      expect(file).to receive(:path).and_return path
      io = double("IO")
      expect(File).to receive(:open).with(path, "r:utf-16le").and_yield io

      expect_any_instance_of(OpenChain::CustomHandler::JCrewPartsExtractParser).to receive(:create_parts).with(io, "file.txt")
      OpenChain::CustomHandler::JCrewPartsExtractParser.process_s3 path
    end
  end

  context "process" do
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

  context "create_parts" do
    before :each do
      file = <<FILE
      1620194           SU1           23953          6204624020               348              16.60                CN         HK           0.10
                                      women's knit swim neon cali halter 82% polyester 18% elastane
FILE
      file.gsub! "\n", "\r\n"
      file = file.encode("utf-16le")
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

      allow_any_instance_of(OpenChain::CustomHandler::JCrewPartsExtractParser).to receive(:custom_file).and_return(@custom_file)
    end

    after :each do
      @custom_file.delete if @custom_file
    end

    it "should read product data and translate it into the output format" do
    	us = @country
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
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.create_parts(StringIO.new(file.gsub("\n", "\r\n")), 'file.txt')
      product = Product.find_by_unique_identifier("JCREW-23346")
      # HTS #
      expect(product.hts_for_country(us)).to include("6204312010")
      # expect(line1[60, 10]).to eq("6204624020")
      # Description (Trim'ed at 40 chars) (There's a hardcoded space between HTS and description)
      expect(product.name).to eq("womens knit swim cali hipster 82% polyester 18% elastane")
      expect(product.custom_value(@cdefs[:prod_part_number])).to eq('23346')

      product = Product.find_by_unique_identifier("JCREW-23953")
      # HTS #
      expect(product.hts_for_country(us)).to include("6204624020")
      # expect(line1[60, 10]).to eq("6204624020")
      # Description (Trim'ed at 40 chars) (There's a hardcoded space between HTS and description)
      expect(product.name).to eq("women's knit swim neon cali halter 82% polyester 18% elastane")
      # Country of Origin
    end

    it "does not call save or snapshot on an unchanged record" do
      file = <<FILE
      1620194            SU1           23953          6204624020               348              16.60                CN         HK           0.10
                                      women‘s knit swim neon cali halter 82% polyester 18% elastane
FILE
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.create_parts(StringIO.new(file.gsub("\n", "\r\n")), "file.txt")

      # We are now pulling an old instance so we do not expect save or create_snapshot to be called.
      expect_any_instance_of(Product).to_not receive(:save)
      expect_any_instance_of(Product).to_not receive(:create_snapshot)
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.create_parts(StringIO.new(file.gsub("\n", "\r\n")), "file.txt")
    end

    it "transliterates UTF-8 chars" do
      # NOTE: the description has one of those non-ascii angled apostrophes for this test (JCREW does send us these)
      file = <<FILE
      1620194            SU1           23953          6204624020               348              16.60                CN         HK           0.10
                                      women‘s knit swim neon cali halter 82% polyester 18% elastane
FILE
      OpenChain::CustomHandler::JCrewPartsExtractParser.new.create_parts(StringIO.new(file.gsub("\n", "\r\n")), "file.txt")
      product = Product.find_by_unique_identifier("JCREW-23953")
      expect(product.name).to eq("women‘s knit swim neon cali halter 82% polyester 18% elastane")
    end

    it "should raise an error if J Crew company doesn't exist" do
      @j_crew.destroy

      expect {
        OpenChain::CustomHandler::JCrewPartsExtractParser.new.create_parts nil, nil
      }.to raise_error "Unable to process J Crew Parts Extract file because no company record could be found with Alliance Customer number 'JCREW'."
    end
  end

  context "integration_test" do
    before :each do
      file = <<FILE
      1620194           SU1           23953          6204624020               348              16.60                CN         HK           0.10
                                      women's knit swim neon cali halter 82% polyester 18% elastane
FILE
      file.gsub! "\n", "\r\n"
      file = file.encode("utf-16le")
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
  end

  context "can_view?" do
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
