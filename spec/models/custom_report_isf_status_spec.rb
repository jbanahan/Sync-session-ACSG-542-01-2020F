require 'spec_helper'

describe CustomReportIsfStatus do

  describe "template_name" do
    it "has a tmeplate name" do
      expect(CustomReportIsfStatus.template_name).to eq "ISF Status"
    end
  end

  describe "description" do
    it "has a description" do
      expect(CustomReportIsfStatus.description).to eq "Shows ISF Data for customers on first tab and all unmatched ISFs for last 90 days for the same customer on a second tab."
    end
  end

  describe "column_fields_available" do
    it "uses security filing fields" do
      u = Factory(:user)
      expect(CustomReportIsfStatus.column_fields_available(u)).to eq CoreModule::SECURITY_FILING.model_fields(u).values
    end
  end

  describe "criterion fields available" do
    it "uses security filing and line fields" do
      u = Factory(:user)
      expect(CustomReportIsfStatus.criterion_fields_available(u)).to eq CoreModule::SECURITY_FILING.model_fields_including_children(u).values
    end
  end

  describe "can_view?" do
    it "allows security filing viewers to view" do
      u = Factory(:user)
      u.should_receive(:view_security_filings?).and_return true
      expect(CustomReportIsfStatus.can_view?(u)).to be_true
    end

    it "disallows non-security filing viewers to view" do
      u = Factory(:user)
      u.should_receive(:view_security_filings?).and_return false
      expect(CustomReportIsfStatus.can_view?(u)).to be_false
    end
  end

  describe "run" do
    before :each do 
      @sf = Factory(:security_filing, :transaction_number => "1234", :broker_customer_number=> "4321", :status_code => "ACCNOMATCH", :file_logged_date=>Time.now)
      @u = Factory(:importer_user, company_id: @sf.importer_id)
      User.any_instance.stub(:view_security_filings?).and_return true

      @rpt = CustomReportIsfStatus.new
      @rpt.search_columns.build model_field_uid: "sf_transaction_number"
      @rpt.search_criterions.build model_field_uid: "sf_broker_customer_number", operator: "eq", value: "4321"
      @rpt.save!
    end

    it "returns specified data" do
      workbook = nil
      Tempfile.open("test") do |f|
        t = @rpt.xls_file @u, f
        workbook = Spreadsheet.open(f.path)
      end

      sheet = workbook.worksheet(0)
      expect(sheet.name).to eq "ISF Report Data"
      expect(sheet.row(0)).to eq ["Transaction Number"]
      expect(sheet.row(1)).to eq ["1234"]

      sheet = workbook.worksheet(1)
      expect(sheet.name).to eq "Unmatched #{90.days.ago.strftime("%m-%d-%y")} thru #{Time.zone.now.strftime("%m-%d-%y")}"
      expect(sheet.row(0)).to eq ["Transaction Number"]
      expect(sheet.row(1)).to eq ["1234"]
    end

    it "does not return ISFs on the unmatched tab if they are matched" do
      @sf.update_attributes! status_code: "MATCH"
      workbook = nil
      Tempfile.open("test") do |f|
        t = @rpt.xls_file @u, f
        workbook = Spreadsheet.open(f.path)
      end
      sheet = workbook.worksheet(1)
      expect(sheet.row(1)).to eq ["No data was returned for this report."]
    end

    it "does not return ISFs on the unmatched tab if they more than 90 days old" do
      @sf.update_attributes! file_logged_date: (Time.zone.now - 91.days)
      workbook = nil
      Tempfile.open("test") do |f|
        t = @rpt.xls_file @u, f
        workbook = Spreadsheet.open(f.path)
      end
      sheet = workbook.worksheet(1)
      expect(sheet.row(1)).to eq ["No data was returned for this report."]
    end

    it "searches secure" do
      u2 = Factory(:importer_user)
      workbook = nil
      Tempfile.open("test") do |f|
        t = @rpt.xls_file u2, f
        workbook = Spreadsheet.open(f.path)
      end
      sheet = workbook.worksheet(0)
      expect(sheet.row(1)).to eq ["No data was returned for this report."]
      sheet = workbook.worksheet(1)
      expect(sheet.row(1)).to eq ["No data was returned for this report."]
    end

    it "raises an error if customer number was not utilized as a criterion" do
      @rpt.search_criterions.destroy_all
      expect{@rpt.to_arrays @u}.to raise_error "This report must include the Customer Number parameter."
    end

    it "only shows first tab for preview runs" do
      # Just build an unmatched ISF for the same company that would normally show on the second tab and make sure it's not there
      sf2 = Factory(:security_filing, :transaction_number => "456789", :broker_customer_number=> "4321", :status_code => "ACCNOMATCH", :file_logged_date=>Time.now)
      @rpt.search_criterions.create! model_field_uid: "sf_transaction_number", operator: "eq", value: @sf.transaction_number

      a = @rpt.to_arrays @u, 10, true
      expect(a.length).to eq 2
      expect(a[1][0]).to eq @sf.transaction_number
    end
  end

  describe "criterions_contain_customer_number?" do
    it "adds errors if search criterions does not contain customer number" do
      rpt = CustomReportIsfStatus.new
      rpt.save
      expect(rpt.errors.full_messages).to include("This report must include the Customer Number parameter.")

      rpt.search_criterions.build model_field_uid: "sf_broker_customer_number", operator: "eq", value: "4321"
    end

    it "does not error if customer number criterion is present" do
      rpt = CustomReportIsfStatus.new
      rpt.search_criterions.build model_field_uid: "sf_broker_customer_number", operator: "eq", value: "4321"
      rpt.save

      expect(rpt.errors).to have(0).items
    end
  end
end