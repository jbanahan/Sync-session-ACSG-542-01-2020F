class CustomReportSpecImpl < CustomReport
  cattr_accessor :view

  def self.can_view? _user
    @@view
  end
end

describe CustomReport do

  let! (:master_setup) { stub_master_setup }

  describe "give_to" do
    let(:user) { FactoryBot(:user, first_name: "A", last_name: "B") }
    let(:user2) { FactoryBot(:user) }

    let(:custom_report) do
      CustomReportEntryInvoiceBreakdown.create!(name: "ABC", user: user, include_links: true, include_rule_links: true)
    end

    it "copies to another user" do
      custom_report.give_to user2
      d = described_class.find_by(user: user2)
      expect(d.name).to eq("ABC (From #{user.full_name})")
      expect(d.id).not_to be_nil
      expect(d.class).to eq(CustomReportEntryInvoiceBreakdown)
      custom_report.reload
      expect(custom_report.name).to eq("ABC") # we shouldn't modify the original object
    end

    it "creates a notification for recipient" do
      custom_report.give_to user2
      expect(user2.messages.count).to eq 1
      msg = user2.messages.first
      expect(msg.subject).to eq "New Report from #{user.username}"
      # rubocop:disable Layout/LineLength
      expect(msg.body).to eq "#{user.username} has sent you a report titled #{custom_report.name}. Click <a href=\'#{Rails.application.routes.url_helpers.custom_report_url(described_class.last.id, host: master_setup.request_host, protocol: 'http')}\'>here</a> to view it."
      # rubocop:enable Layout/LineLength
    end
  end

  describe "deep_copy" do
    let(:user) { FactoryBot(:user) }

    let(:custom_report) do
      CustomReportEntryInvoiceBreakdown.create!(name: "ABC", user: user, include_links: true, include_rule_links: true)
    end

    it "copies basic search setup" do
      d = custom_report.deep_copy "new"
      expect(d.id).not_to be_nil
      expect(d.id).not_to eq(custom_report.id)
      expect(d.name).to eq("new")
      expect(d.user).to eq(user)
      expect(d.include_links).to be_truthy
      expect(d.include_rule_links).to be_truthy
      expect(d.class).to eq(CustomReportEntryInvoiceBreakdown)
    end

    it "copies parameters" do
      custom_report.search_criterions.create!(model_field_uid: 'a', value: 'x', operator: 'y', status_rule_id: 1, custom_definition_id: 2)
      d = custom_report.deep_copy "new"
      expect(d.search_criterions.size).to eq(1)
      sc = d.search_criterions.first
      expect(sc.model_field_uid).to eq('a')
      expect(sc.value).to eq('x')
      expect(sc.operator).to eq('y')
      expect(sc.status_rule_id).to eq(1)
      expect(sc.custom_definition_id).to eq(2)
    end

    it "copies columns" do
      custom_report.search_columns.create!(model_field_uid: 'a', rank: 7, custom_definition_id: 9)
      d = custom_report.deep_copy "new"
      expect(d.search_columns.size).to eq(1)
      sc = d.search_columns.first
      expect(sc.model_field_uid).to eq('a')
      expect(sc.rank).to eq(7)
      expect(sc.custom_definition_id).to eq(9)
    end

    it "does not copy schedules" do
      custom_report.search_schedules.create!
      d = custom_report.deep_copy "new"
      expect(d.search_schedules).to be_empty
    end
  end

  context "report_output" do
    let(:report) do
      rpt = described_class.new
      def rpt.run _run_by, _row_limit = nil
        write 0, 0, "MY HEADING"
        write 1, 0, "my data"
        write 1, 1, 7
        write_hyperlink 1, 2, "http://abc/def", "mylink"
        write 1, 3, Time.zone.local(2014, 1, 1)
        write 4, 4, "my row 4"
        write_columns 5, 1, ["col1", "col2"]
        heading_row 0
      end
      rpt
    end

    let(:temp) { nil }

    after do
      temp&.unlink
    end

    it 'outputs xls to tmp file' do
      user = FactoryBot(:user)
      report.name = "my&report.xls"
      temp, * = report.xls_file user
      expect(temp.path).to match(/my_report.xls/) # swaps out illegal characters
      sheet = Spreadsheet.open(temp.path).worksheet(0)
      expect(sheet.row(0).default_format.name).to eq(XlsMaker::HEADER_FORMAT.name)
      expect(sheet.row(0)[0]).to eq("MY HEADING")
      expect(sheet.row(1)[0]).to eq("my data")
      expect(sheet.row(1)[1]).to eq(7)
      expect(sheet.row(1)[2]).to eq("mylink")
      expect(sheet.row(1)[2].url).to eq("http://abc/def")
      expect(sheet.row(1)[3]).to eq(Time.zone.local(2014, 1, 1).to_s)
      expect(sheet.row(4)[4]).to eq("my row 4")
      expect(sheet.row(5)[1]).to eq("col1")
      expect(sheet.row(5)[2]).to eq("col2")
    end

    it 'outputs to given xls file' do
      Tempfile.open('custom_report_spec') do |f|
        t, * = report.xls_file FactoryBot(:user), file: f
        expect(t.path).to eq(f.path)
        sheet = Spreadsheet.open(f.path).worksheet(0)
        expect(sheet.row(0)[0]).to eq("MY HEADING")
      end
    end

    it 'outputs to array of arrays' do
      r = report.to_arrays FactoryBot(:user)
      expect(r[0][0]).to eq("MY HEADING")
      expect(r[1][0]).to eq("my data")
      expect(r[1][1]).to eq(7)
      expect(r[1][2]).to eq("http://abc/def")
      expect(r[1][3]).to eq(Time.zone.local(2014, 1, 1))
      expect(r[2].size).to eq(0)
      expect(r[3].size).to eq(0)
      expect(r[4][0]).to eq("")
      expect(r[4][4]).to eq("my row 4")
      expect(r[5]).to eq(["", "col1", "col2"])
    end

    it 'outputs csv' do
      report.name = "my/report.csv"
      temp, * = report.csv_file FactoryBot(:user)
      expect(temp.path).to match(/my_report.csv/) # swaps out illegal characters
      r = CSV.read temp.path
      expect(r[0][0]).to eq("MY HEADING")
      expect(r[1][0]).to eq("my data")
      expect(r[1][1]).to eq("7")
      expect(r[1][2]).to eq("http://abc/def")
      expect(r[1][3]).to eq(Time.zone.local(2014, 1, 1).strftime("%Y-%m-%d %H:%M"))
      expect(r[2].size).to eq(0)
      expect(r[3].size).to eq(0)
      expect(r[4][0]).to eq("")
      expect(r[4][4]).to eq("my row 4")
      expect(r[5]).to eq(["", "col1", "col2"])
    end

    context "no time" do
      before do
        report.no_time = true
      end

      it "does not truncate time from datetime in array-based output" do
        r = report.to_arrays FactoryBot(:user)
        expect(r[1][3]).to eq Time.zone.local(2014, 1, 1)
      end

      it "truncates time from datetime in xls-based output" do
        temp = Tempfile.new('custom_report_spec')
        t, * = report.xls_file FactoryBot(:user), file: temp
        expect(t.path).to eq(temp.path)
        sheet = Spreadsheet.open(temp.path).worksheet(0)
        expect(sheet.row(1).format(3).number_format).to eq "YYYY-MM-DD"
      end

      it "truncates time from datetime in csv output" do
        temp, * = report.csv_file FactoryBot(:user)
        expect(temp.path).to match(/csv/)
        r = CSV.read temp.path
        expect(r[1][3]).to eq(Time.zone.local(2014, 1, 1).strftime("%Y-%m-%d"))
      end
    end

  end

  describe "validate_access" do
    let(:user) { FactoryBot(:user) }

    it "raises an error if the can_view? class method is false" do
      CustomReportSpecImpl.view = false
      r = CustomReportSpecImpl.new
      expect {r.send(:validate_access, user)}.to raise_error "User #{user.username} does not have permission to view this report."
    end

    it "does nothing if user can_view?" do
      CustomReportSpecImpl.view = true
      r = CustomReportSpecImpl.new
      expect(r.send(:validate_access, user)).to be_truthy
    end
  end

  describe "write_headers" do
    let(:report) do
      rpt = described_class.new

      def rpt.run run_by, _row_limit = nil
        write_headers 0, ["Header1", SearchColumn.new(model_field_uid: "prod_uid"), ModelField.by_uid(:prod_uid)], run_by
      end

      rpt
    end

    it "adds all passed in values to the listener row specified as headers" do
      r = report.to_arrays FactoryBot(:user)
      expect(r[0]).to eq ["Header1", ModelField.by_uid(:prod_uid).label, ModelField.by_uid(:prod_uid).label]
    end

    it "adds web links as first columns when include_links/include_rule_links is true" do
      report.include_links = true
      report.include_rule_links = true
      r = report.to_arrays FactoryBot(:user)
      expect(r[0]).to eq ["Web Links", "Business Rule Links", "Header1", ModelField.by_uid(:prod_uid).label, ModelField.by_uid(:prod_uid).label]
    end

    it "prints disabled for fields the user can't view" do
      uid = ModelField.by_uid(:prod_uid)
      u = FactoryBot(:user)
      allow(uid).to receive(:can_view?).with(u).and_return false

      r = report.to_arrays u
      expect(r[0]).to eq ["Header1", ModelField.disabled_label, ModelField.disabled_label]
    end
  end

  describe "write_row" do
    let!(:product) { FactoryBot(:product) }
    let(:user) { FactoryBot(:user, product_view: true) }
    let(:report) do
      rpt = described_class.new

      def rpt.run run_by, _row_limit = nil
        write_row 0, Product.first, ["Value", SearchColumn.new(model_field_uid: "prod_uid")], run_by
      end

      rpt
    end

    before do
    end

    it "adds all passed in values to the listener row specified as headers" do
      r = report.to_arrays user
      expect(r[0]).to eq ["Value", product.unique_identifier]
    end

    it "adds web links as first column when include_links is true" do
      stub_master_setup
      report.include_links = true
      report.include_rule_links = true
      r = report.to_arrays user
      expect(r[0]).to eq [product.excel_url, "#{product.excel_url}/validation_results", "Value", product.unique_identifier]
    end
  end

  describe "write_no_data" do
    it "writes standard message for no data" do
      rpt = described_class.new
      def rpt.run _run_by, _row_limit = nil
        write_no_data 0
      end
      r = rpt.to_arrays nil
      expect(r[0]).to eq ["No data was returned for this report."]
    end

    it "allows override for message" do
      rpt = described_class.new
      def rpt.run _run_by, _row_limit = nil
        write_no_data 0, "New Message"
      end
      r = rpt.to_arrays nil
      expect(r[0]).to eq ["New Message"]
    end
  end

  describe "setup_report_query" do
    subject do
      r = described_class.new
      r.search_criterions.build model_field_uid: "prod_uid", operator: "eq", value: "Test"
      r
    end

    let (:user) { FactoryBot(:user, product_view: true) }

    it "generates a report query base" do
      query = subject.send(:setup_report_query, Product, user, nil).to_sql
      expect(query).to include("SELECT DISTINCT `products`.*")
      expect(query).to include("unique_identifier = 'Test'")
      expect(query).to include(Product.search_where(user))
    end

    it "generates a report query base with a limit" do
      query = subject.send(:setup_report_query, Product, user, 10).to_sql
      expect(query).to include("LIMIT 10")
    end

    it "gneerates a report query base without distinct clause" do
      query = subject.send(:setup_report_query, Product, user, nil, distinct: false).to_sql
      expect(query).not_to include("SELECT DISTINCT")
    end
  end

  describe "add_tab" do
    subject do
      Class.new(CustomReport) do
        def run _run_by, _row_limit = nil
          add_tab "First"
          write_row 0, nil, ["Data1"], nil
          add_tab "Second"
          write_row 0, nil, ["Data2"], nil
        end
      end.new
    end

    it "adds a new tab when told to" do
      Tempfile.open('custom_report_spec') do |f|
        subject.xls_file FactoryBot(:user), file: f
        sheet = Spreadsheet.open(f.path).worksheet("First")
        expect(sheet.row(0)[0]).to eq("Data1")
        sheet = Spreadsheet.open(f.path).worksheet("Second")
        expect(sheet.row(0)[0]).to eq("Data2")
      end
    end
  end

  describe "xlsx_file" do
    subject do
      Class.new(CustomReport) do
        def run _user, _row_limit
          nil
        end
      end.new
    end

    let (:workbook) do
      instance_double(XlsxBuilder)
    end

    let (:file) do
      instance_double(Tempfile)
    end

    let (:user) { User.new }

    it "runs xlsx custom report" do
      expect_any_instance_of(CustomReport::XlsxListener).to receive(:build_xlsx).and_return workbook
      expect(workbook).to receive(:write).with file
      expect_any_instance_of(CustomReport::XlsxListener).to receive(:blank_file?).and_return false
      expect(subject).to receive(:run).with(user, 25_000)

      expect(subject.xlsx_file(user, file: file)).to eq [file, false]
    end
  end

  describe "xls_file" do
    subject do
      Class.new(CustomReport) do
        def run _user, _row_limit
          nil
        end
      end.new
    end

    let (:workbook) do
      instance_double(Spreadsheet::Workbook)
    end

    let (:file) do
      tf = instance_double(Tempfile)
      allow(tf).to receive(:path).and_return "/path/to/file.xls"
      tf
    end

    let (:user) { User.new }

    it "runs xls custom report" do
      expect_any_instance_of(CustomReport::XlsListener).to receive(:workbook).and_return workbook
      expect(workbook).to receive(:write).with "/path/to/file.xls"
      expect_any_instance_of(CustomReport::XlsListener).to receive(:blank_file?).and_return false
      expect(subject).to receive(:run).with(user, 25_000)

      expect(subject.xls_file(user, file: file)).to eq [file, false]
    end
  end

  describe "csv_file" do

    subject do
      Class.new(CustomReport) do
        def run _user, _row_limit
          nil
        end
      end.new
    end

    let (:file) do
      instance_double(Tempfile)
    end

    let (:user) { User.new }

    it "runs csv custom report" do
      expect_any_instance_of(CustomReport::ArraysListener).to receive(:arrays).and_return [["1", "2"]]
      expect(file).to receive(:write).with "1,2\n"
      expect(file).to receive(:flush)
      expect_any_instance_of(CustomReport::ArraysListener).to receive(:blank_file?).and_return false
      expect(subject).to receive(:run).with(user, 25_000)

      expect(subject.csv_file(user, file: file)).to eq [file, false]
    end
  end

  describe "to_arrays" do
    subject do
      Class.new(CustomReport) do
        def run _user, _row_limit
          nil
        end
      end.new
    end

    let (:user) { User.new }

    it "runs report and returns results as arrays" do
      expect_any_instance_of(CustomReport::ArraysListener).to receive(:arrays).and_return [["1", "2"]]
      expect(subject).to receive(:run).with(user, 25_000)

      expect(subject.to_arrays(user)).to eq [["1", "2"]]
    end
  end

  context "validations" do

    subject { CustomReportEntryBillingBreakdownByPo.new }

    describe "scheduled_reports_have_parameters" do

      it "allows saving custom reports with schedules if there's a search criterion present" do
        subject.search_schedules.build email_addresses: "me@there.com", run_hour: 0, run_monday: true
        subject.search_criterions.build model_field_uid: 'bi_brok_ref', operator: 'eq', value: '123'

        subject.save
        expect(subject.errors).not_to include "All reports with schedules must have at least one parameter."
      end

      it "errors when attempting to save a report that has schedules but no search criterions" do
        subject.search_schedules.build email_addresses: "me@there.com", run_hour: 0, run_monday: true
        subject.save
        expect(subject.errors[:base]).to include "All reports with schedules must have at least one parameter."
      end
    end
  end
end
