require 'spec_helper'
require 'spreadsheet'

describe CustomReport do

  describe "give_to" do
    before :each do
      MasterSetup.create(request_host:"localhost:3000")
      @u = Factory(:user,:first_name=>"A",:last_name=>"B")
      @u2 = Factory(:user)
      @s = CustomReportEntryInvoiceBreakdown.create!(:name=>"ABC",:user=>@u,:include_links=>true)
    end
    it "should copy to another user" do
      @s.give_to @u2
      d = CustomReport.find_by_user_id @u2.id
      expect(d.name).to eq("ABC (From #{@u.full_name})")
      expect(d.id).not_to be_nil
      expect(d.class).to eq(CustomReportEntryInvoiceBreakdown)
      @s.reload
      expect(@s.name).to eq("ABC") #we shouldn't modify the original object
    end
    it "should create a notification for recipient" do
      @s.give_to @u2
      expect(@u2.messages.count).to eq 1
      msg = @u2.messages.first
      expect(msg.subject).to eq "New Report from #{@u.username}"
      expect(msg.body).to eq "#{@u.username} has sent you a report titled #{@s.name}. Click <a href=\'#{Rails.application.routes.url_helpers.custom_report_url(CustomReport.last.id, host: MasterSetup.get.request_host, protocol: 'http')}\'>here</a> to view it."
    end
  end
  describe "deep_copy" do
    before :each do 
      @u = Factory(:user)
      @s = CustomReportEntryInvoiceBreakdown.create!(:name=>"ABC",:user=>@u,:include_links=>true)
    end
    it "should copy basic search setup" do
      d = @s.deep_copy "new"
      expect(d.id).not_to be_nil
      expect(d.id).not_to eq(@s.id)
      expect(d.name).to eq("new")
      expect(d.user).to eq(@u)
      expect(d.include_links).to be_truthy
      expect(d.class).to eq(CustomReportEntryInvoiceBreakdown)
    end
    it "should copy parameters" do
      @s.search_criterions.create!(:model_field_uid=>'a',:value=>'x',:operator=>'y',:status_rule_id=>1,:custom_definition_id=>2)
      d = @s.deep_copy "new"
      expect(d.search_criterions.size).to eq(1)
      sc = d.search_criterions.first
      expect(sc.model_field_uid).to eq('a')
      expect(sc.value).to eq('x')
      expect(sc.operator).to eq('y')
      expect(sc.status_rule_id).to eq(1)
      expect(sc.custom_definition_id).to eq(2)
    end
    it "should copy columns" do
      @s.search_columns.create!(:model_field_uid=>'a',:rank=>7,:custom_definition_id=>9)
      d = @s.deep_copy "new"
      expect(d.search_columns.size).to eq(1)
      sc = d.search_columns.first
      expect(sc.model_field_uid).to eq('a')
      expect(sc.rank).to eq(7)
      expect(sc.custom_definition_id).to eq(9)
    end
    it "should not copy schedules" do
      @s.search_schedules.create!
      d = @s.deep_copy "new"
      expect(d.search_schedules).to be_empty
    end
  end
  context "report_output" do
    before :each do
      @rpt = CustomReport.new
      def @rpt.run run_by, row_limit=nil
        write 0, 0, "MY HEADING"
        write 1, 0, "my data"
        write 1, 1, 7
        write_hyperlink 1, 2, "http://abc/def", "mylink"
        write 1, 3, Time.new(2014, 1, 1)
        write 4, 4, "my row 4"
        write_columns 5, 1, ["col1", "col2"]
        heading_row 0
      end
    end
    after :each do
      @tmp.unlink if @tmp
    end
    it 'should output xls to tmp file' do
      user= Factory(:user)
      @tmp = @rpt.xls_file user
      expect(@tmp.path).to match(/xls/)
      sheet = Spreadsheet.open(@tmp.path).worksheet(0)
      expect(sheet.row(0).default_format.name).to eq(XlsMaker::HEADER_FORMAT.name)
      expect(sheet.row(0)[0]).to eq("MY HEADING")
      expect(sheet.row(1)[0]).to eq("my data")
      expect(sheet.row(1)[1]).to eq(7)
      expect(sheet.row(1)[2]).to eq("mylink")
      expect(sheet.row(1)[2].url).to eq("http://abc/def")
      expect(sheet.row(1)[3]).to eq(Time.new(2014, 1, 1).to_s)
      expect(sheet.row(4)[4]).to eq("my row 4")
      expect(sheet.row(5)[1]).to eq("col1")
      expect(sheet.row(5)[2]).to eq("col2")
    end
    it 'should output to given xls file' do
      Tempfile.open('custom_report_spec') do |f|
        t = @rpt.xls_file Factory(:user), f
        expect(t.path).to eq(f.path)
        sheet = Spreadsheet.open(f.path).worksheet(0)
        expect(sheet.row(0)[0]).to eq("MY HEADING")
      end
    end

    it 'should output to array of arrays' do
      r = @rpt.to_arrays Factory(:user)
      expect(r[0][0]).to eq("MY HEADING")
      expect(r[1][0]).to eq("my data")
      expect(r[1][1]).to eq(7)
      expect(r[1][2]).to eq("http://abc/def")
      expect(r[1][3]).to eq(Time.new(2014, 1, 1))
      expect(r[2].size).to eq(0)
      expect(r[3].size).to eq(0)
      expect(r[4][0]).to eq("")
      expect(r[4][4]).to eq("my row 4")
      expect(r[5]).to eq(["", "col1", "col2"])
    end

    it 'should output csv' do
      @tmp = @rpt.csv_file Factory(:user)
      expect(@tmp.path).to match(/csv/)
      r = CSV.read @tmp.path
      expect(r[0][0]).to eq("MY HEADING")
      expect(r[1][0]).to eq("my data")
      expect(r[1][1]).to eq("7")
      expect(r[1][2]).to eq("http://abc/def")
      expect(r[1][3]).to eq(Time.new(2014, 1, 1).strftime("%Y-%m-%d %H:%M"))
      expect(r[2].size).to eq(0)
      expect(r[3].size).to eq(0)
      expect(r[4][0]).to eq("")
      expect(r[4][4]).to eq("my row 4")
      expect(r[5]).to eq(["", "col1", "col2"])
    end

    context "no time" do
      before :each do
        @rpt.no_time = true
      end

      it "does not truncate time from datetime in array-based output" do
        r = @rpt.to_arrays Factory(:user)
        expect(r[1][3]).to eq Time.new(2014, 1, 1)
      end

      it "truncates time from datetime in xls-based output" do
        @tmp = Tempfile.new('custom_report_spec')
        t = @rpt.xls_file Factory(:user), @tmp
        expect(t.path).to eq(@tmp.path)
        sheet = Spreadsheet.open(@tmp.path).worksheet(0)
        expect(sheet.row(1).format(3).number_format).to eq "YYYY-MM-DD"
      end

      it "truncates time from datetime in csv output" do
        @tmp = @rpt.csv_file Factory(:user)
        expect(@tmp.path).to match(/csv/)
        r = CSV.read @tmp.path
        expect(r[1][3]).to eq(Time.new(2014, 1, 1).strftime("%Y-%m-%d"))
      end
    end
    
  end

  describe "validate_access" do
    class CustomReportSpecImpl < CustomReport
      cattr_accessor :view

      def self.can_view? user
        @@view
      end
    end

    before :each do 
      @user = Factory(:user)
    end
    it "raises an error if the can_view? class method is false" do
      CustomReportSpecImpl.view = false
      r = CustomReportSpecImpl.new
      expect {r.send(:validate_access, @user)}.to raise_error "User #{@user.username} does not have permission to view this report."
    end

    it "does nothing if user can_view?" do
      CustomReportSpecImpl.view = true
      r = CustomReportSpecImpl.new
      expect(r.send(:validate_access, @user)).to be_truthy
    end
  end

  describe "write_headers" do
    before :each do
      @rpt = CustomReport.new
      def @rpt.run run_by, row_limit=nil
        write_headers 0, ["Header1", SearchColumn.new(model_field_uid: "prod_uid"), ModelField.find_by_uid(:prod_uid)], run_by
      end
    end

    it "adds all passed in values to the listener row specified as headers" do
      r = @rpt.to_arrays Factory(:user)
      expect(r[0]).to eq ["Header1", ModelField.find_by_uid(:prod_uid).label, ModelField.find_by_uid(:prod_uid).label]
    end

    it "adds web links as first column when include_links is true" do
      @rpt.include_links = true
      r = @rpt.to_arrays Factory(:user)
      expect(r[0]).to eq ["Web Links", "Header1", ModelField.find_by_uid(:prod_uid).label, ModelField.find_by_uid(:prod_uid).label]
    end

    it "prints disabled for fields the user can't view" do
      uid = ModelField.find_by_uid(:prod_uid)
      u = Factory(:user)
      allow(uid).to receive(:can_view?).with(u).and_return false

      r = @rpt.to_arrays u
      expect(r[0]).to eq ["Header1", ModelField.disabled_label, ModelField.disabled_label]
    end
  end

  describe "write_row" do
    before :each do
      @rpt = CustomReport.new
      @p = Factory(:product)
      @u = Factory(:user, :product_view => true)

      def @rpt.run run_by, row_limit=nil
        write_row 0, Product.first, ["Value", SearchColumn.new(model_field_uid: "prod_uid")], run_by
      end
    end

    it "adds all passed in values to the listener row specified as headers" do
      r = @rpt.to_arrays @u
      expect(r[0]).to eq ["Value", @p.unique_identifier]
    end

    it "adds web links as first column when include_links is true" do
      allow_any_instance_of(MasterSetup).to receive(:request_host).and_return "localhost"
      @rpt.include_links = true
      r = @rpt.to_arrays @u
      expect(r[0]).to eq [@p.excel_url, "Value", @p.unique_identifier]
    end
  end

  describe "write_no_data" do
    it "writes standard message for no data" do
      rpt = CustomReport.new
      def rpt.run run_by, row_limit=nil
        write_no_data 0
      end
      r = rpt.to_arrays nil
      expect(r[0]).to eq ["No data was returned for this report."]
    end

    it "allows override for message" do
      rpt = CustomReport.new
      def rpt.run run_by, row_limit=nil
        write_no_data 0, "New Message"
      end
      r = rpt.to_arrays nil
      expect(r[0]).to eq ["New Message"]
    end
  end

  describe "setup_report_query" do
    before :each do
      @rpt = CustomReport.new
      @u = Factory(:user, :product_view => true)
      @rpt.search_criterions.build model_field_uid: "prod_uid", operator: "eq", value: "Test"
    end

    it "generates a report query base" do
      query = @rpt.send(:setup_report_query, Product, @u, nil).to_sql
      expect(query).to include("SELECT DISTINCT `products`.*")
      expect(query).to include("unique_identifier = 'Test'")
      expect(query).to include(Product.search_where(@u))
    end

    it "generates a report query base with a limit" do
      query = @rpt.send(:setup_report_query, Product, @u, 10).to_sql
      expect(query).to include("LIMIT 10")
    end

    it "gneerates a report query base without distinct clause" do
      query = @rpt.send(:setup_report_query, Product, @u, nil, distinct: false).to_sql
      expect(query).to_not include("SELECT DISTINCT")
    end
  end

  describe "add_tab" do
    before :each do
      @rpt = CustomReport.new
      def @rpt.run run_by, row_limit=nil
        add_tab "First"
        write_row 0, nil, ["Data1"], nil
        add_tab "Second"
        write_row 0, nil, ["Data2"], nil
      end
    end

    it "adds a new tab when told to" do
      Tempfile.open('custom_report_spec') do |f|
        t = @rpt.xls_file Factory(:user), f
        sheet = Spreadsheet.open(f.path).worksheet("First")
        expect(sheet.row(0)[0]).to eq("Data1")
        sheet = Spreadsheet.open(f.path).worksheet("Second")
        expect(sheet.row(0)[0]).to eq("Data2")
      end
    end
  end
end
