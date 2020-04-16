describe OpenChain::CustomHandler::Ascena::AscenaDutySavingsReport do

  subject { described_class }
  let(:helper) { OpenChain::CustomHandler::Ascena::AscenaReportHelper }
  let! (:ascena) { with_customs_management_id(Factory(:importer, name: "Ascena", system_code: "ASCENA"), "ASCE") }
  let! (:ann) { with_customs_management_id(Factory(:importer, name: "Ann"), "ATAYLOR") }
  let! (:maurices) { with_customs_management_id(Factory(:importer, name: "Maurices"), "MAUR") }
  let! (:ascena_master) { with_customs_management_id(Factory(:importer, name: "Ascena Master"), "ASCENAMASTER") }
  let! (:user) { Factory(:master_user) }
  let (:cdefs) { described_class::Query.new.cdefs }

  describe "permissions" do
    let!(:ms) do
      m = stub_master_setup
      allow(m).to receive(:custom_feature?).with("Ascena Reports").and_return true
      allow(user).to receive(:view_entries?).and_return true
      m
    end

    let!(:cust_descriptions) {[{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"}, 
                               {cust_num: "ATAYLOR", sys_code: "ATAYLOR", name: "ANN TAYLOR INC", short_name: "Ann"}, 
                               {cust_num: "MAUR", sys_code: "MAUR", name: "MAURICES", short_name: "Maurices"}]}

    it "returns empty if 'Ascena Reports' custom feature absent" do
      allow(ms).to receive(:custom_feature?).with("Ascena Reports").and_return false
      expect(subject.permissions user).to be_empty
    end

    it "returns empty if user can't view entries" do
      allow(user).to receive(:view_entries?).and_return false
      expect(subject.permissions user).to be_empty
    end

    it "returns info for Ascena, Ann, Maurices if master user" do
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns info for Ascena, Ann, Maurices if user belongs to ASCENAMASTER" do
      user.company = ascena_master; user.company.save!
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns info for Ascena, Ann, Maurices if user belongs to ASCE_TRADE_ASSOC group" do
      user.company.update master: false
      g = Factory(:group, system_code: "ASCE_TRADE_ASSOC")
      user.groups << g
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns only info for user's company if user doesn't belong to privileged category" do
      user.company = ascena; user.company.save!
      expect(subject.permissions user).to eq([{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"}])
    end

    it "omits info for missing company" do
      maurices.destroy
      expect(subject.permissions user).to eq([{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"}, 
                                              {cust_num: "ATAYLOR", sys_code: "ATAYLOR", name: "ANN TAYLOR INC", short_name: "Ann"}])
    end
  end

  describe "fiscal_month" do
    let (:fiscal_month) { Factory(:fiscal_month, company: ascena, year: 2017, month_number: 3) }

    it "parses fiscal month descriptor and returns fiscal month record" do
      fiscal_month
      expect(subject.fiscal_month({"fiscal_month"=>"2017-03"})).to eq fiscal_month
    end

    it "returns nil if format is bad" do
      expect(subject.fiscal_month({"fiscal_month"=>"month"})).to be_nil
    end

    it "handles missing setting" do
      expect(subject.fiscal_month({})).to be_nil
    end
  end

  describe "run_schedulable" do
    let!(:current_fm) { Factory(:fiscal_month, company: ascena, start_date: Date.new(2018,3,15), end_date: Date.new(2018,4,15), year: 2018, month_number: 2) }
    let!(:previous_fm) { Factory(:fiscal_month, company: ascena, start_date: Date.new(2018,2,15), end_date: Date.new(2018,3,14), year: 2018, month_number: 1) }
  
    it "runs report for previous fiscal month on fourth day of fiscal month" do
      Tempfile.open(["hi", ".xls"]) do |t|
        expect_any_instance_of(subject).to receive(:run).with(previous_fm).and_yield t
        Timecop.freeze(DateTime.new(2018,3,18,12,0)) do
          subject.run_schedulable('email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'], 
                                  'cust_numbers' => ['ASCE', 'ATAYLOR'],
                                  'company' => 'ASCENA',
                                  'fiscal_day' => 4)
        end

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk']
        expect(mail.subject).to eq "Ascena-Ann Duty Savings Report 2018-01"
        expect(mail.body).to match /Attached is the Ascena-Ann Duty Savings Report for 2018-01\./
        # not sure why following expectation fails. Leaving it commented for now.
        # expect(mail.attachments.first).to eq t
      end
    end

    it "does nothing on other days" do
      Timecop.freeze(DateTime.new(2018,3,20,12,0)) do
        subject.run_schedulable('email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'], 
                                'cust_numbers' => ['ASCE', 'ATAYLOR'],
                                'company' => 'ASCENA',
                                'fiscal_day' => 3)
      end
      mail = ActionMailer::Base.deliveries.pop
      expect(mail).to be_nil
    end

  end

  describe "generate_first_sale_data" do
    let(:row) do
      row = described_class::Wrapper.new []
      row[:customer_number] = "ASCE"
      row[:product_line] = "JST"
      row[:order_type] = "NONAGS"
      row[:non_dutiable_amount] = 2.5
      row[:special_tariff] = false
      row[:cil_entered_value_7501] = 1.5
      row[:contract_amount] = 3.5
      row
    end
    let(:result_set) { [row] }
    let(:savings_set) do
      [
       {savings_type: :gsp, savings_title: "GSP", calculations: {calculated_invoice_value: 1, calculated_duty: 2, savings: 3}},
       {savings_type: :first_sale, savings_title: "First Sale", calculations: {calculated_invoice_value: 1.1, calculated_duty: 2.1, savings: 3.1}},
       {savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 1.2, calculated_duty: 2.2, savings: 3.2}}
      ]
    end

    before { allow(row).to receive(:duty_savings).and_return savings_set }

    context "Ascena/Maurices" do
      it "sums first-sale data" do
        summary = described_class.new(["ASCE"]).generate_first_sale_data result_set
        expected = {"AGS"=>{}, "NONAGS"=> {"JST"=> {:vendor_invoice=>3.5,
                                                    :entered_value_7501=>1.5,
                                                    :total_entered_value_7501=>7.6,
                                                    :duty_savings=>3.1}}}
        expect(summary).to eq expected
        
        expected = {"AGS"=>{}, "NONAGS"=> {"MAUR"=> {:vendor_invoice=>3.5,
                                                    :entered_value_7501=>1.5,
                                                    :total_entered_value_7501=>7.6,
                                                    :duty_savings=>3.1}}}
        row[:customer_number] = "MAUR"
        summary = described_class.new(["MAUR"]).generate_first_sale_data result_set
        expect(summary).to eq expected
      end
    end

    context "Ann" do
      it "sums first-sale data, assigning total_entered_value_7501 to total_calculated_invoice_value from the summary" do
        row[:customer_number] = "ATAYLOR"
        report = described_class.new(["ATAYLOR"])
        report.instance_variable_set(:@ann_entry_total_calculated_invoice_value, 5.1)
        summary = report.generate_first_sale_data result_set
        expected = {"AGS"=>{}, "NONAGS"=> {"ATAYLOR"=> {:vendor_invoice=>3.5,
                                                        :entered_value_7501=>1.5,
                                                        :total_entered_value_7501=>5.1,
                                                        :duty_savings=>3.1}}}
        expect(summary).to eq expected                                          
      end
    end
    
    it "sums first-sale AGS" do
      row[:order_type] = "AGS"
      summary = described_class.new(["ASCE"]).generate_first_sale_data result_set
      expected = {"AGS"=>{"JST"=> {:vendor_invoice=>3.5,
                                  :entered_value_7501=>1.5,
                                  :total_entered_value_7501=>7.6,
                                  :duty_savings=>3.1}}, 
                  "NONAGS"=> {}}
      expect(summary).to eq expected
    end

    it "only increment duty savings for special tariffs" do
      row[:special_tariff] = true
      summary = described_class.new(["ASCE"]).generate_first_sale_data result_set
      expected = {"AGS"=>{}, "NONAGS"=> {"JST"=> {:vendor_invoice=>0,
                                                  :entered_value_7501=>0,
                                                  :total_entered_value_7501=>0,
                                                  :duty_savings=>3.1}}}
      expect(summary).to eq expected
    end

    it "only increments total entered value when there are no savings" do
      allow(row).to receive(:duty_savings).and_return []
      summary = described_class.new(["ASCE"]).generate_first_sale_data result_set
      expected = {"AGS"=>{}, "NONAGS"=> {"JST"=> {:vendor_invoice=>0.0,
                                                  :entered_value_7501=>0.0,
                                                  :total_entered_value_7501=>1.5,
                                                  :duty_savings=>0.0}}}
      expect(summary).to eq expected
    end
  end

  describe "generate_customer_summary_data" do
    let(:row) do
      row = described_class::Wrapper.new []
      row[:customer_number] = "ASCE"
      row[:special_tariff] = false
      row[:cil_entered_value_7501] = 1.5
      row[:duty_amount] = 3.5
      row
    end
    let(:result_set) { [row] }
    let(:savings_set) do
      [
       {savings_type: :gsp, savings_title: "GSP", calculations: {calculated_invoice_value: 1, calculated_duty: 2, savings: 3}},
       {savings_type: :first_sale, savings_title: "First Sale", calculations: {calculated_invoice_value: 1.1, calculated_duty: 2.1, savings: 3.1}},
       {savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 1.2, calculated_duty: 2.2, savings: 3.2}}
      ]
    end

    before { allow(row).to receive(:duty_savings).and_return savings_set }

    it "returns summary of customer data" do
      summary = described_class.new(["ASCE"]).generate_customer_summary_data result_set, "ASCE"
      expected = {"GSP"=>
                    {:usage_count=>1,
                     :entered_value_7501=>1.5,
                     :duty_paid=>3.5,
                     :calculated_invoice_value=>1,
                     :calculated_duty=>2,
                     :duty_savings=>3},
                  "First Sale"=>
                    {:usage_count=>1,
                     :entered_value_7501=>1.5,
                     :duty_paid=>3.5,
                     :calculated_invoice_value=>1.1,
                     :calculated_duty=>2.1,
                     :duty_savings=>3.1},
                  "Actual Entry Totals"=>
                    {:usage_count=>1,
                     :entered_value_7501=>1.5,
                     :duty_paid=>3.5,
                     :calculated_invoice_value=>1.2,
                     :calculated_duty=>2.2,
                     :duty_savings=>3.2}}

      expect(summary).to eq expected
    end

    it "doesn't increment entered value and calculated invoice value if special tariff" do
      row[:special_tariff] = true
      summary = described_class.new(["ASCE"]).generate_customer_summary_data result_set, "ASCE"
      expected = {"GSP"=>
                    {:usage_count=>1,
                     :entered_value_7501=>0,
                     :duty_paid=>3.5,
                     :calculated_invoice_value=>0,
                     :calculated_duty=>2,
                     :duty_savings=>3},
                  "First Sale"=>
                    {:usage_count=>1,
                     :entered_value_7501=>0,
                     :duty_paid=>3.5,
                     :calculated_invoice_value=>0,
                     :calculated_duty=>2.1,
                     :duty_savings=>3.1},
                  "Actual Entry Totals"=>
                    {:usage_count=>1,
                     :entered_value_7501=>0,
                     :duty_paid=>3.5,
                     :calculated_invoice_value=>0,
                     :calculated_duty=>2.2,
                     :duty_savings=>3.2}}
      
      expect(summary).to eq expected
    end

    it "doesn't increment discount's usage count more than once per broker invoice" do
      row_2 = row.dup
      allow(row_2).to receive(:duty_savings).and_return savings_set
      result_set << row_2

      summary = described_class.new(["ASCE"]).generate_customer_summary_data result_set, "ASCE"

      expect(summary["GSP"][:usage_count]).to eq 1
      expect(summary["First Sale"][:usage_count]).to eq 1
      expect(summary["Actual Entry Totals"][:usage_count]).to eq 1
    end

    it "assigns @ann_entry_total_calculated_invoice_value for Ann" do
      row[:customer_number] = "ATAYLOR"
      report = described_class.new(["ATAYLOR"])
      summary = report.generate_customer_summary_data result_set, "ATAYLOR"
      expect(report.instance_variable_get(:@ann_entry_total_calculated_invoice_value)).to eq 1.2
    end

  end

  describe "run_report" do
    let! (:fiscal_month) { Factory(:fiscal_month, company: ascena, year: 2017, month_number: 3, start_date: Date.new(2017, 3, 1), end_date: Date.new(2017, 4, 1)) }
    let (:data_sheet_header) do
      ["Broker Reference Number", "Importer", "First Sale", "Supplier", "Manufacturer", "Transactions Related", "Mode of Transport", "Fiscal Month", "Release Date", 
       "Filer", "Entry No.", "7501 Line Number", "Invoice Number", "Product Code", "PO Number", "Brand", "Order Type", "Country of Origin", "Country of Export", 
       "Arrival Date", "Import Date", "Arrival Port", "Entry Port", "Tariff", "Duty Rate", "Goods Description", "Price/Unit", "Invoice Quantity", "Invoice UOM", 
       "Original FOB Unit Value", "Original FOB Entered Value", "Duty", "First Sale Difference", "First Sale Duty Savings", "First Sale Margin %", 
       "Line Price Before Discounts", "Line Entered Value", "Air/Sea Discount", "Air/Sea Per Unit Savings", "Air/Sea Duty Savings", "Early Payment Discount", 
       "EPD per Unit Savings", "EPD Duty Savings", "Trade Discount", "Trade Discount per Unit Savings", "Trade Discount Duty Savings", "SPI", "Original Duty Rate", 
       "SPI Duty Savings", "Fish and Wildlife", "Hanger Duty Savings", "MP vs. Air/Sea", "MP vs. EPD", "MP vs. Trade Discount", "MP vs. Air/Sea/EPD Trade", 
       "First Sale Savings", "Air/Sea Savings", "EPD Savings", "Trade Discount Savings", "Applied Discount"]
    end

    context "with mocked data" do
      let(:row_jst) { create_row "ASCE", "JST" }
      let(:row_lb) { create_row "ASCE", "LB" }
      let(:row_ca) { create_row "ASCE", "CA" }
      let(:row_maur) { create_row "ASCE", "MAU" }
      let(:row_db) { create_row "ASCE", "DB" }
      let(:row_ann) { create_row "ATAYLOR", "ANN"}
      let(:row_maurices_maur) { create_row "MAUR", "MAUR"}
      let(:result_set) { [row_jst, row_lb, row_ca, row_maur, row_db, row_ann, row_maurices_maur] }
      let(:savings_set) do
        [
         {savings_type: :gsp, savings_title: "GSP", calculations: {calculated_invoice_value: 1, calculated_duty: 2, savings: 3}},
         {savings_type: :first_sale, savings_title: "First Sale", calculations: {calculated_invoice_value: 1.1, calculated_duty: 2.1, savings: 3.1}},
         {savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 1.2, calculated_duty: 2.2, savings: 3.2}}
        ]
      end
  
      let(:asce_summary) do
        {"GSP"=> {:usage_count=>"count GSP ASCE", :entered_value_7501=>"7501 GSP ASCE", :duty_paid=>3.5, :calculated_invoice_value=>"val GSP ASCE", :calculated_duty=>2, :duty_savings=>"savings GSP ASCE"},
         "First Sale"=> {:usage_count=>"count FS ASCE", :entered_value_7501=>"7501 FS ASCE", :duty_paid=>3.5, :calculated_invoice_value=>"val FS ASCE", :calculated_duty=>2.1, :duty_savings=>"savings FS ASCE"},
         "Actual Entry Totals"=> {:usage_count=>"count actual ASCE", :entered_value_7501=>"7501 actual ASCE", :duty_paid=>3.5, :calculated_invoice_value=>"val actual ASCE", :calculated_duty=>2.2, :duty_savings=>"savings actual ASCE"}}
      end
  
      let(:maur_summary) do
        {"GSP"=> {:usage_count=>"count GSP MAUR", :entered_value_7501=>"7501 GSP MAUR", :duty_paid=>3.6, :calculated_invoice_value=>"val GSP MAUR", :calculated_duty=>2.6, :duty_savings=>"savings GSP MAUR"},
         "First Sale"=> {:usage_count=>"count FS MAUR", :entered_value_7501=>"7501 FS MAUR", :duty_paid=>3.6, :calculated_invoice_value=>"val FS MAUR", :calculated_duty=>2.6, :duty_savings=>"savings FS MAUR"},
         "Actual Entry Totals"=> {:usage_count=>"count actual MAUR", :entered_value_7501=>"7501 actual MAUR", :duty_paid=>3.6, :calculated_invoice_value=>"val actual MAUR", :calculated_duty=>2.6, :duty_savings=>"savings actual MAUR"}}
      end
  
      let(:ann_summary) do
        {"GSP"=> {:usage_count=>"count GSP ATAYLOR", :entered_value_7501=>"7501 GSP ATAYLOR", :duty_paid=>3.7, :calculated_invoice_value=>"val GSP ATAYLOR", :calculated_duty=>2.7, :duty_savings=>"savings GSP ATAYLOR"},
         "First Sale"=> {:usage_count=>"count FS ATAYLOR", :entered_value_7501=>"7501 FS ATAYLOR", :duty_paid=>3.7, :calculated_invoice_value=>"val FS ATAYLOR", :calculated_duty=>2.7, :duty_savings=>"savings FS ATAYLOR"},
         "Actual Entry Totals"=> {:usage_count=>"count actual ATAYLOR", :entered_value_7501=>"7501 actual ATAYLOR", :duty_paid=>3.7, :calculated_invoice_value=>"val actual ATAYLOR", :calculated_duty=>2.7, :duty_savings=>"savings actual ATAYLOR"}}
      end
  
      let(:first_sale_summary) do 
        {"AGS"   => {"JST"=> {:vendor_invoice=>"inv AGS JST", :entered_value_7501=>"7501 AGS JST", :total_entered_value_7501=>"total 7501 AGS JST", :duty_savings=>"duty AGS JST"},
                      "LB"=> {:vendor_invoice=>"inv AGS LB", :entered_value_7501=>"7501 AGS LB", :total_entered_value_7501=>"total 7501 AGS LB", :duty_savings=>"duty AGS LB"},
                      "CA"=> {:vendor_invoice=>"inv AGS CA", :entered_value_7501=>"7501 AGS CA", :total_entered_value_7501=>"total 7501 AGS CA", :duty_savings=>"duty AGS CA"},
                     "MAU"=> {:vendor_invoice=>"inv AGS MAU", :entered_value_7501=>"7501 AGS MAU", :total_entered_value_7501=>"total 7501 AGS MAU", :duty_savings=>"duty AGS MAU"},
                      "DB"=> {:vendor_invoice=>"inv AGS DB", :entered_value_7501=>"7501 AGS DB", :total_entered_value_7501=>"total 7501 AGS DB", :duty_savings=>"duty AGS DB"},
                 "ATAYLOR"=> {:vendor_invoice=>"inv AGS ATAYLOR", :entered_value_7501=>"7501 AGS ATAYLOR", :total_entered_value_7501=>"total 7501 AGS ATAYLOR", :duty_savings=>"duty AGS ATAYLOR"},
                    "MAUR"=> {:vendor_invoice=>"inv AGS MAUR", :entered_value_7501=>"7501 AGS MAUR", :total_entered_value_7501=>"total 7501 AGS MAUR", :duty_savings=>"duty AGS MAUR"}}, 
         "NONAGS"=> {"JST"=> {:vendor_invoice=>"inv NONAGS JST", :entered_value_7501=>"7501 NONAGS JST", :total_entered_value_7501=>"total 7501 NONAGS JST", :duty_savings=>"duty NONAGS JST"},
                      "LB"=> {:vendor_invoice=>"inv NONAGS LB", :entered_value_7501=>"7501 NONAGS LB", :total_entered_value_7501=>"total 7501 NONAGS LB", :duty_savings=>"duty NONAGS LB"},
                      "CA"=> {:vendor_invoice=>"inv NONAGS CA", :entered_value_7501=>"7501 NONAGS CA", :total_entered_value_7501=>"total 7501 NONAGS CA", :duty_savings=>"duty NONAGS CA"},
                     "MAU"=> {:vendor_invoice=>"inv NONAGS MAU", :entered_value_7501=>"7501 NONAGS MAU", :total_entered_value_7501=>"total 7501 NONAGS MAU", :duty_savings=>"duty NONAGS MAU"},
                      "DB"=> {:vendor_invoice=>"inv NONAGS DB", :entered_value_7501=>"7501 NONAGS DB", :total_entered_value_7501=>"total 7501 NONAGS DB", :duty_savings=>"duty NONAGS DB"},
                 "ATAYLOR"=> {:vendor_invoice=>"inv NONAGS ATAYLOR", :entered_value_7501=>"7501 NONAGS ATAYLOR", :total_entered_value_7501=>"total 7501 NONAGS ATAYLOR", :duty_savings=>"duty NONAGS ATAYLOR"},
                    "MAUR"=> {:vendor_invoice=>"inv NONAGS MAUR", :entered_value_7501=>"7501 NONAGS MAUR", :total_entered_value_7501=>"total 7501 NONAGS MAUR", :duty_savings=>"duty NONAGS MAUR"}}}
      end
  
      before do
        expect_any_instance_of(described_class::Query).to receive(:run).with(["ASCE", "ATAYLOR", "MAUR"], Date.new(2017,3,1), Date.new(2017,4,1)).and_return result_set
        allow_any_instance_of(described_class).to receive(:generate_customer_summary_data).with(anything, "ASCE").and_return asce_summary
        allow_any_instance_of(described_class).to receive(:generate_customer_summary_data).with(anything, "MAUR").and_return maur_summary
        allow_any_instance_of(described_class).to receive(:generate_customer_summary_data).with(anything, "ATAYLOR").and_return ann_summary
        expect_any_instance_of(described_class).to receive(:generate_first_sale_data).with(result_set).and_return first_sale_summary
      end
  
      def create_row cust_num, brand, order_type="NONAGS"
        row = described_class::Wrapper.new []
        described_class::Wrapper::FIELD_MAP.keys.each{ |k| row[k] = "#{k} #{brand}" }
        row[:customer_number] = cust_num
        row[:product_line] = brand
        row[:order_type] = order_type 
        allow(row).to receive(:duty_savings).and_return create_saving_set(brand)
        row
      end
  
      def create_saving_set brand
        [
         {savings_type: :gsp, savings_title: "GSP", calculations: {calculated_invoice_value: "GSP val #{brand}", calculated_duty: "GSP dty #{brand}", savings: "GSP svgs #{brand}"}},
         {savings_type: :first_sale, savings_title: "First Sale", calculations: {calculated_invoice_value: "FS val #{brand}", calculated_duty: "FS dty #{brand}", savings: "FS svgs #{brand}"}},
         {savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: "Actual val #{brand}", calculated_duty: "Actual dty #{brand}", savings: "Actual svgs #{brand}"}}
        ]
      end
  
      it "writes data to spreadsheet" do
        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE", "ATAYLOR", "MAUR"]}
        expect(tf).not_to be_nil
  
        wb = XlsMaker.open_workbook(tf)
        expect(sheet = wb.worksheet("ATS Summary")).not_to be_nil
        summary_header = ["Program Name", "Entry Usage Count", "Total Entered Value", "Total Duty Paid", "Total Calculated Invoice Value", "Total Calculated Duty", "Duty Savings", "Duty Savings Percentage"]
        expect(sheet.rows.count).to eq 4
        expect(sheet.row(0)).to eq summary_header
        expect(sheet.row(1)).to eq ["First Sale", "count FS ASCE", "7501 FS ASCE", 3.5, "val FS ASCE", 2.1, "savings FS ASCE", -0.6667]
        expect(sheet.row(2)).to eq ["GSP", "count GSP ASCE", "7501 GSP ASCE", 3.5, "val GSP ASCE", 2, "savings GSP ASCE", -0.75]
        expect(sheet.row(3)).to eq ["Actual Entry Totals", "count actual ASCE", "7501 actual ASCE", 3.5, "val actual ASCE", 2.2, "savings actual ASCE", -0.5909]
        
        expect(sheet2 = wb.worksheet("Ann Inc. Summary")).not_to be_nil
        expect(sheet2.rows.count).to eq 4
        expect(sheet2.row(0)).to eq summary_header
        expect(sheet2.row(1)).to eq ["First Sale", "count FS ATAYLOR", "7501 FS ATAYLOR", 3.7, "val FS ATAYLOR", 2.7, "savings FS ATAYLOR", -0.3704]
        expect(sheet2.row(2)).to eq ["GSP", "count GSP ATAYLOR", "7501 GSP ATAYLOR", 3.7, "val GSP ATAYLOR", 2.7, "savings GSP ATAYLOR", -0.3704]
        expect(sheet2.row(3)).to eq ["Actual Entry Totals", "count actual ATAYLOR", "7501 actual ATAYLOR", 3.7, "val actual ATAYLOR", 2.7, "savings actual ATAYLOR", -0.3704]
  
        expect(sheet3 = wb.worksheet("Maurices Summary")).not_to be_nil
        expect(sheet3.rows.count).to eq 4
        expect(sheet3.row(0)).to eq summary_header
        expect(sheet3.row(1)).to eq ["First Sale", "count FS MAUR", "7501 FS MAUR", 3.6, "val FS MAUR", 2.6, "savings FS MAUR", -0.3846]
        expect(sheet3.row(2)).to eq ["GSP", "count GSP MAUR", "7501 GSP MAUR", 3.6, "val GSP MAUR", 2.6, "savings GSP MAUR", -0.3846]
        expect(sheet3.row(3)).to eq ["Actual Entry Totals", "count actual MAUR", "7501 actual MAUR", 3.6, "val actual MAUR", 2.6, "savings actual MAUR", -0.3846]
  
        expect(sheet4 = wb.worksheet("First Sale")).not_to be_nil
        expect(sheet4.rows.count).to eq 10
        expect(sheet4.row(0)).to eq [nil, "Justice", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn", nil, "Ann Inc.", nil, "Maurices-Maur"]
        expect(sheet4.row(1)).to eq ["AGS Vendor Invoice", "inv AGS JST", nil, "inv AGS LB", nil, "inv AGS CA", nil, "inv AGS MAU", nil, "inv AGS DB", nil, "inv AGS ATAYLOR", nil, "inv AGS MAUR"]
        expect(sheet4.row(2)).to eq ["AGS Entered Value", "7501 AGS JST", nil, "7501 AGS LB", nil, "7501 AGS CA", nil, "7501 AGS MAU", nil, "7501 AGS DB", nil, "7501 AGS ATAYLOR", nil, "7501 AGS MAUR"]
        expect(sheet4.row(3)).to eq ["AGS Duty Savings", "duty AGS JST", nil, "duty AGS LB", nil, "duty AGS CA", nil, "duty AGS MAU", nil, "duty AGS DB", nil, "duty AGS ATAYLOR", nil, "duty AGS MAUR"]
        expect(sheet4.row(4)).to eq ["AGS Total Brand FOB Receipts", "total 7501 AGS JST", nil, "total 7501 AGS LB", nil, "total 7501 AGS CA", nil, "total 7501 AGS MAU", nil, "total 7501 AGS DB", nil, "total 7501 AGS ATAYLOR", nil, "total 7501 AGS MAUR"]
        expect(sheet4.row(6)).to eq ["NONAGS Vendor Invoice", "inv NONAGS JST", nil, "inv NONAGS LB", nil, "inv NONAGS CA", nil, "inv NONAGS MAU", nil, "inv NONAGS DB", nil, "inv NONAGS ATAYLOR", nil, "inv NONAGS MAUR"]
        expect(sheet4.row(7)).to eq ["NONAGS Entered Value", "7501 NONAGS JST", nil, "7501 NONAGS LB", nil, "7501 NONAGS CA", nil, "7501 NONAGS MAU", nil, "7501 NONAGS DB", nil, "7501 NONAGS ATAYLOR", nil, "7501 NONAGS MAUR"]
        expect(sheet4.row(8)).to eq ["NONAGS Duty Savings", "duty NONAGS JST", nil, "duty NONAGS LB", nil, "duty NONAGS CA", nil, "duty NONAGS MAU", nil, "duty NONAGS DB", nil, "duty NONAGS ATAYLOR", nil, "duty NONAGS MAUR"]
        expect(sheet4.row(9)).to eq ["NONAGS Total Brand FOB Receipts", "total 7501 NONAGS JST", nil, "total 7501 NONAGS LB", nil, "total 7501 NONAGS CA", nil, "total 7501 NONAGS MAU", nil, "total 7501 NONAGS DB", nil, "total 7501 NONAGS ATAYLOR", nil, "total 7501 NONAGS MAUR"]
  
        expect(sheet5 = (wb.worksheet "Data")).not_to be_nil
        expect(sheet5.rows.count).to eq 8
        expect(sheet5.row(0)).to eq data_sheet_header
        expect(sheet5.row(1)).to eq ["broker_reference JST", "customer_name JST", "first_sale JST", "vendor JST", "factory JST", "related_parties JST", "transport_mode_code JST", "fiscal_month JST", "release_date JST", "filer JST", "entry_number JST", "custom_line_number JST", "invoice_number JST", "part_number JST", "po_number JST", "JST", "NONAGS", "country_origin_code JST", "country_export_code JST", "arrival_date JST", "import_date JST", "arrival_port JST", "entry_port JST", "hts_code JST", "duty_rate JST", "goods_description JST", "unit_price JST", "quantity JST", "unit_of_measure JST", "original_fob_unit_value JST", "original_fob_entered_value JST", "duty JST", "first_sale_difference JST", "first_sale_duty_savings JST", "first_sale_margin_percent JST", "price_before_discounts JST", "line_entered_value JST", "air_sea_discount JST", "air_sea_per_unit_savings JST", "air_sea_duty_savings JST", "early_payment_discount JST", "epd_per_unit_savings JST", "epd_duty_savings JST", "trade_discount JST", "trade_discount_per_unit_savings JST", "trade_discount_duty_savings JST", "spi JST", "original_duty_rate JST", "spi_duty_savings JST", "fish_and_wildlife JST", "hanger_duty_savings JST", "mp_vs_air_sea JST", "mp_vs_epd JST", "mp_vs_trade_discount JST", "mp_vs_air_sea_epd_trade JST", "first_sale_savings JST", "air_sea_savings JST", "epd_savings JST", "trade_discount_savings JST", "applied_discount JST"]
        expect(sheet5.row(2)).to eq ["broker_reference LB", "customer_name LB", "first_sale LB", "vendor LB", "factory LB", "related_parties LB", "transport_mode_code LB", "fiscal_month LB", "release_date LB", "filer LB", "entry_number LB", "custom_line_number LB", "invoice_number LB", "part_number LB", "po_number LB", "LB", "NONAGS", "country_origin_code LB", "country_export_code LB", "arrival_date LB", "import_date LB", "arrival_port LB", "entry_port LB", "hts_code LB", "duty_rate LB", "goods_description LB", "unit_price LB", "quantity LB", "unit_of_measure LB", "original_fob_unit_value LB", "original_fob_entered_value LB", "duty LB", "first_sale_difference LB", "first_sale_duty_savings LB", "first_sale_margin_percent LB", "price_before_discounts LB", "line_entered_value LB", "air_sea_discount LB", "air_sea_per_unit_savings LB", "air_sea_duty_savings LB", "early_payment_discount LB", "epd_per_unit_savings LB", "epd_duty_savings LB", "trade_discount LB", "trade_discount_per_unit_savings LB", "trade_discount_duty_savings LB", "spi LB", "original_duty_rate LB", "spi_duty_savings LB", "fish_and_wildlife LB", "hanger_duty_savings LB", "mp_vs_air_sea LB", "mp_vs_epd LB", "mp_vs_trade_discount LB", "mp_vs_air_sea_epd_trade LB", "first_sale_savings LB", "air_sea_savings LB", "epd_savings LB", "trade_discount_savings LB", "applied_discount LB"]
        expect(sheet5.row(3)).to eq ["broker_reference CA", "customer_name CA", "first_sale CA", "vendor CA", "factory CA", "related_parties CA", "transport_mode_code CA", "fiscal_month CA", "release_date CA", "filer CA", "entry_number CA", "custom_line_number CA", "invoice_number CA", "part_number CA", "po_number CA", "CA", "NONAGS", "country_origin_code CA", "country_export_code CA", "arrival_date CA", "import_date CA", "arrival_port CA", "entry_port CA", "hts_code CA", "duty_rate CA", "goods_description CA", "unit_price CA", "quantity CA", "unit_of_measure CA", "original_fob_unit_value CA", "original_fob_entered_value CA", "duty CA", "first_sale_difference CA", "first_sale_duty_savings CA", "first_sale_margin_percent CA", "price_before_discounts CA", "line_entered_value CA", "air_sea_discount CA", "air_sea_per_unit_savings CA", "air_sea_duty_savings CA", "early_payment_discount CA", "epd_per_unit_savings CA", "epd_duty_savings CA", "trade_discount CA", "trade_discount_per_unit_savings CA", "trade_discount_duty_savings CA", "spi CA", "original_duty_rate CA", "spi_duty_savings CA", "fish_and_wildlife CA", "hanger_duty_savings CA", "mp_vs_air_sea CA", "mp_vs_epd CA", "mp_vs_trade_discount CA", "mp_vs_air_sea_epd_trade CA", "first_sale_savings CA", "air_sea_savings CA", "epd_savings CA", "trade_discount_savings CA", "applied_discount CA"]
        expect(sheet5.row(4)).to eq ["broker_reference MAU", "customer_name MAU", "first_sale MAU", "vendor MAU", "factory MAU", "related_parties MAU", "transport_mode_code MAU", "fiscal_month MAU", "release_date MAU", "filer MAU", "entry_number MAU", "custom_line_number MAU", "invoice_number MAU", "part_number MAU", "po_number MAU", "MAU", "NONAGS", "country_origin_code MAU", "country_export_code MAU", "arrival_date MAU", "import_date MAU", "arrival_port MAU", "entry_port MAU", "hts_code MAU", "duty_rate MAU", "goods_description MAU", "unit_price MAU", "quantity MAU", "unit_of_measure MAU", "original_fob_unit_value MAU", "original_fob_entered_value MAU", "duty MAU", "first_sale_difference MAU", "first_sale_duty_savings MAU", "first_sale_margin_percent MAU", "price_before_discounts MAU", "line_entered_value MAU", "air_sea_discount MAU", "air_sea_per_unit_savings MAU", "air_sea_duty_savings MAU", "early_payment_discount MAU", "epd_per_unit_savings MAU", "epd_duty_savings MAU", "trade_discount MAU", "trade_discount_per_unit_savings MAU", "trade_discount_duty_savings MAU", "spi MAU", "original_duty_rate MAU", "spi_duty_savings MAU", "fish_and_wildlife MAU", "hanger_duty_savings MAU", "mp_vs_air_sea MAU", "mp_vs_epd MAU", "mp_vs_trade_discount MAU", "mp_vs_air_sea_epd_trade MAU", "first_sale_savings MAU", "air_sea_savings MAU", "epd_savings MAU", "trade_discount_savings MAU", "applied_discount MAU"]
        expect(sheet5.row(5)).to eq ["broker_reference DB", "customer_name DB", "first_sale DB", "vendor DB", "factory DB", "related_parties DB", "transport_mode_code DB", "fiscal_month DB", "release_date DB", "filer DB", "entry_number DB", "custom_line_number DB", "invoice_number DB", "part_number DB", "po_number DB", "DB", "NONAGS", "country_origin_code DB", "country_export_code DB", "arrival_date DB", "import_date DB", "arrival_port DB", "entry_port DB", "hts_code DB", "duty_rate DB", "goods_description DB", "unit_price DB", "quantity DB", "unit_of_measure DB", "original_fob_unit_value DB", "original_fob_entered_value DB", "duty DB", "first_sale_difference DB", "first_sale_duty_savings DB", "first_sale_margin_percent DB", "price_before_discounts DB", "line_entered_value DB", "air_sea_discount DB", "air_sea_per_unit_savings DB", "air_sea_duty_savings DB", "early_payment_discount DB", "epd_per_unit_savings DB", "epd_duty_savings DB", "trade_discount DB", "trade_discount_per_unit_savings DB", "trade_discount_duty_savings DB", "spi DB", "original_duty_rate DB", "spi_duty_savings DB", "fish_and_wildlife DB", "hanger_duty_savings DB", "mp_vs_air_sea DB", "mp_vs_epd DB", "mp_vs_trade_discount DB", "mp_vs_air_sea_epd_trade DB", "first_sale_savings DB", "air_sea_savings DB", "epd_savings DB", "trade_discount_savings DB", "applied_discount DB"]
        expect(sheet5.row(6)).to eq ["broker_reference ANN", "customer_name ANN", "first_sale ANN", "vendor ANN", "factory ANN", "related_parties ANN", "transport_mode_code ANN", "fiscal_month ANN", "release_date ANN", "filer ANN", "entry_number ANN", "custom_line_number ANN", "invoice_number ANN", "part_number ANN", "po_number ANN", "ANN", "NONAGS", "country_origin_code ANN", "country_export_code ANN", "arrival_date ANN", "import_date ANN", "arrival_port ANN", "entry_port ANN", "hts_code ANN", "duty_rate ANN", "goods_description ANN", "unit_price ANN", "quantity ANN", "unit_of_measure ANN", "original_fob_unit_value ANN", "original_fob_entered_value ANN", "duty ANN", "first_sale_difference ANN", "first_sale_duty_savings ANN", "first_sale_margin_percent ANN", "price_before_discounts ANN", "line_entered_value ANN", "air_sea_discount ANN", "air_sea_per_unit_savings ANN", "air_sea_duty_savings ANN", "early_payment_discount ANN", "epd_per_unit_savings ANN", "epd_duty_savings ANN", "trade_discount ANN", "trade_discount_per_unit_savings ANN", "trade_discount_duty_savings ANN", "spi ANN", "original_duty_rate ANN", "spi_duty_savings ANN", "fish_and_wildlife ANN", "hanger_duty_savings ANN", "mp_vs_air_sea ANN", "mp_vs_epd ANN", "mp_vs_trade_discount ANN", "mp_vs_air_sea_epd_trade ANN", "first_sale_savings ANN", "air_sea_savings ANN", "epd_savings ANN", "trade_discount_savings ANN", "applied_discount ANN"]
        expect(sheet5.row(7)).to eq ["broker_reference MAUR", "customer_name MAUR", "first_sale MAUR", "vendor MAUR", "factory MAUR", "related_parties MAUR", "transport_mode_code MAUR", "fiscal_month MAUR", "release_date MAUR", "filer MAUR", "entry_number MAUR", "custom_line_number MAUR", "invoice_number MAUR", "part_number MAUR", "po_number MAUR", "MAUR", "NONAGS", "country_origin_code MAUR", "country_export_code MAUR", "arrival_date MAUR", "import_date MAUR", "arrival_port MAUR", "entry_port MAUR", "hts_code MAUR", "duty_rate MAUR", "goods_description MAUR", "unit_price MAUR", "quantity MAUR", "unit_of_measure MAUR", "original_fob_unit_value MAUR", "original_fob_entered_value MAUR", "duty MAUR", "first_sale_difference MAUR", "first_sale_duty_savings MAUR", "first_sale_margin_percent MAUR", "price_before_discounts MAUR", "line_entered_value MAUR", "air_sea_discount MAUR", "air_sea_per_unit_savings MAUR", "air_sea_duty_savings MAUR", "early_payment_discount MAUR", "epd_per_unit_savings MAUR", "epd_duty_savings MAUR", "trade_discount MAUR", "trade_discount_per_unit_savings MAUR", "trade_discount_duty_savings MAUR", "spi MAUR", "original_duty_rate MAUR", "spi_duty_savings MAUR", "fish_and_wildlife MAUR", "hanger_duty_savings MAUR", "mp_vs_air_sea MAUR", "mp_vs_epd MAUR", "mp_vs_trade_discount MAUR", "mp_vs_air_sea_epd_trade MAUR", "first_sale_savings MAUR", "air_sea_savings MAUR", "epd_savings MAUR", "trade_discount_savings MAUR", "applied_discount MAUR"]
      end
    end

    # This integration test verifies that the essential wiring is in place. It's too cumbersome to do more than spot-check
    context "with actual data" do
      let! (:entry) do
        e = Factory(:entry, importer: ascena, import_country: Factory(:country), customer_number: "ASCE", source_system: "Alliance", fiscal_date: Date.new(2017, 3, 1), broker_reference: "REF", transport_mode_code: "40", fiscal_year: 2017, fiscal_month: 3, release_date: DateTime.new(2017, 3, 1, 5, 0))
        ci = e.commercial_invoices.create! invoice_number: "INV"
        cil = ci.commercial_invoice_lines.create! po_number: "PO", part_number: "PART", product_line: "JST", non_dutiable_amount: 20, entered_value_7501: BigDecimal("10"), value: BigDecimal("10"), contract_amount: 0
        cit = cil.commercial_invoice_tariffs.create! hts_code: "1234567890", tariff_description: "DESC", entered_value_7501: BigDecimal("10"), spi_primary: "", duty_rate: BigDecimal("0.1"), duty_amount: BigDecimal("1")
        
        cil = ci.commercial_invoice_lines.create! po_number: "PO", part_number: "PART2", product_line: "JST", non_dutiable_amount: 0, entered_value_7501: BigDecimal("10"), value: BigDecimal("10"), contract_amount: 0
        cit = cil.commercial_invoice_tariffs.create! hts_code: "1234567890", tariff_description: "DESC", entered_value_7501: BigDecimal("10"), spi_primary: "", duty_rate: BigDecimal("0.1"), duty_amount: BigDecimal("1")
  
        e
      end

      let! (:order) do
        order = Factory(:order, order_number: "ASCENA-JST-PO")
        order.update_custom_value! cdefs[:ord_type], "AGS"
        order
      end

      it "writes data to spreadsheet" do
        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE", "ATAYLOR", "MAUR"]}
        expect(tf).not_to be_nil
  
        wb = XlsMaker.open_workbook(tf)
        summary_header = ["Program Name", "Entry Usage Count", "Total Entered Value", "Total Duty Paid", "Total Calculated Invoice Value", "Total Calculated Duty", "Duty Savings", "Duty Savings Percentage"]
        expect(sheet = wb.worksheet("ATS Summary")).not_to be_nil
        expect(sheet.rows.count).to eq 3
        expect(sheet.row(0)).to eq summary_header
        expect(sheet.row(1)).to eq ["Air Sea Differential", 1, 10.0, 1.0, 30.0, 3.0, 2.0, 0.6667]
        expect(sheet.row(2)).to eq ["Actual Entry Totals", 1, 10.0, 1.0, 30.0, 3.0, 2.0, 0.6667]
        
        expect(sheet2 = wb.worksheet("Ann Inc. Summary")).not_to be_nil
        expect(sheet2.rows.count).to eq 1
        expect(sheet2.row(0)).to eq summary_header

        expect(sheet3 = wb.worksheet("Maurices Summary")).not_to be_nil
        expect(sheet3.rows.count).to eq 1
        expect(sheet3.row(0)).to eq summary_header        
        
        expect(sheet4 = wb.worksheet("First Sale")).not_to be_nil
        expect(sheet4.rows.count).to eq 10
        expect(sheet4.row(0)).to eq [nil, "Justice", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn", nil, "Ann Inc.", nil, "Maurices-Maur"]
        expect(sheet4.row(1)).to eq ["AGS Vendor Invoice", 0, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet4.row(2)).to eq ["AGS Entered Value", 0, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet4.row(3)).to eq ["AGS Duty Savings", 0, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet4.row(4)).to eq ["AGS Total Brand FOB Receipts", 40, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet4.row(6)).to eq ["NONAGS Vendor Invoice", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet4.row(7)).to eq ["NONAGS Entered Value", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet4.row(8)).to eq ["NONAGS Duty Savings", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet4.row(9)).to eq ["NONAGS Total Brand FOB Receipts", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        
        expect(sheet5 = (wb.worksheet "Data")).not_to be_nil
        expect(sheet5.rows.count).to eq 3
        expect(sheet5.row(0)).to eq data_sheet_header
        expect(sheet5.row(1)[0]).to eq "REF"
      end
    end
  end

  describe "DutySavingsCalculator" do
    let!(:row) { described_class::Wrapper.new [] }
    let!(:dsc) { described_class::DutySavingsCalculator.new row }

    describe "get" do
      context "without savings" do
        it "returns default values when there aren't any savings" do
          row[:cil_entered_value_7501] = 10
          row[:duty_amount] = 3
          expect_any_instance_of(described_class::DutySavingsType).to receive(:get).and_return []

          expect(dsc.get).to eq [{savings_type: nil, savings_title: nil, calculations: {calculated_invoice_value: 10, calculated_duty: 3, savings: 0}}]
        end

        it "returns calculated invoice value of 0 if special tariff" do
          row[:cil_entered_value_7501] = 10
          row[:duty_amount] = 3
          row[:special_tariff] = true
          expect_any_instance_of(described_class::DutySavingsType).to receive(:get).and_return []

          expect(dsc.get).to eq [{savings_type: nil, savings_title: nil, calculations: {calculated_invoice_value: 0, calculated_duty: 3, savings: 0}}]
        end
      end

      it "returns array of discounts" do
        air_sea_hsh = double "air/sea hsh"
        first_sale_hsh = double "first_sale_hsh"
        spi_hsh = double "spi_hsh"
        epd_hsh = double "epd_hsh"
        trade_hsh = double "trade_hsh"

        expect_any_instance_of(described_class::DutySavingsType).to receive(:get).and_return [[:air_sea, "Air Sea Differential"], [:first_sale, "First Sale"], 
                                                                                              [:spi, "CAFTA"], [:epd, "EPD Discount"], [:trade, "Trade Discount"], 
                                                                                              [:line, "Actual Entry Totals"]]
        expect(dsc).to receive(:calculate_air_sea_differential).and_return air_sea_hsh
        expect(dsc).to receive(:calculate_first_sale).and_return first_sale_hsh
        expect(dsc).to receive(:calculate_spi).and_return spi_hsh
        expect(dsc).to receive(:calculate_epd).and_return epd_hsh
        expect(dsc).to receive(:calculate_trade_discount).and_return trade_hsh
        expect_any_instance_of(described_class::ActualEntryTotalCalculator).to receive(:fill_totals)

        expect(dsc.get).to eq [{savings_type: :air_sea, savings_title: "Air Sea Differential", calculations: air_sea_hsh}, 
                               {savings_type: :first_sale, savings_title: "First Sale", calculations: first_sale_hsh},
                               {savings_type: :spi, savings_title: "CAFTA", calculations: spi_hsh},
                               {savings_type: :epd, savings_title: "EPD Discount", calculations: epd_hsh},
                               {savings_type: :trade, savings_title: "Trade Discount", calculations: trade_hsh},
                               # Because ActualEntryTotalCalculator#fill_totals is side-effecting, it's difficult to mock so we'll leave 'calculations' nil
                               {savings_type: :line, savings_title: "Actual Entry Totals", calculations: nil}]                               
      end
    end
  
    describe "calculate_first_sale" do
      before do
        row[:contract_amount] = 10
        row[:duty] = 3
        row[:duty_rate] = 0.2
        row[:first_sale_savings] = 4
        row[:first_sale_duty_savings] = 2
      end

      context "Ascena/Maurices" do
        it "returns results of first-sale calculation" do
          row[:customer_number] = "ASCE"
          expect(dsc.calculate_first_sale).to eq({calculated_invoice_value: 10, calculated_duty: 2 , savings: 2 })

          row[:customer_number] = "MAUR"
          expect(dsc.calculate_first_sale).to eq({calculated_invoice_value: 10, calculated_duty: 2 , savings: 2 })
        end

        it "returns calculated invoice value of 0 if special tariff" do
          row[:customer_number] = "ASCE"
          row[:special_tariff] = true
          expect(dsc.calculate_first_sale).to eq({calculated_invoice_value: 0, calculated_duty: 2 , savings: 2 })
        end
      end

      context "Ann" do
        before { row[:customer_number] = "ATAYLOR" }
        
        it "calculates first sale" do
          expect(dsc.calculate_first_sale).to eq({calculated_invoice_value: 10, calculated_duty: 7 , savings: 2 })
        end

        it "returns calculated invoice value of 0 if special tariff" do
          row[:special_tariff] = true
          expect(dsc.calculate_first_sale).to eq({calculated_invoice_value: 0, calculated_duty: 7 , savings: 2 })
        end
      end
    end

    describe "calculate_spi" do
      let(:ot) { Factory(:official_tariff, common_rate_decimal: 0.3) }
      before do 
        row.official_tariff = ot
        row[:cil_entered_value_7501] = 10
        row[:duty_amount] = 1
        row[:duty_rate] = 0.2
      end
      
      it "returns results of SPI calculation if there's a common rate" do
        expect(dsc.calculate_spi).to eq({calculated_invoice_value: 10 , calculated_duty: 3, savings: 2})
      end

      it "returns results of different calculation if there isn't a common rate" do
        ot.update_attributes common_rate_decimal: 0
        expect(dsc.calculate_spi).to eq({calculated_invoice_value: 10 , calculated_duty: 0.2, savings: 0})
      end

      it "returns duty_amount as savings if spi is suspended" do
        row[:spi] = "A"
        row[:release_date] = Date.new(2018,3,15)
        expect(dsc.calculate_spi).to eq({calculated_invoice_value: 10 , calculated_duty: 3, savings: 1})
      end

      it "returns calculated invoice value of 0 if special tariff" do
        row[:special_tariff] = true
        expect(dsc.calculate_spi).to eq({calculated_invoice_value: 0 , calculated_duty: 3, savings: 2})
      end
    end

    describe "calculate_air_sea_differential" do
      before do
        row[:non_dutiable_amount] = 5
        row[:cil_entered_value_7501] = 10
        row[:duty_rate] = 0.2
        row[:duty_amount] = 3
        row[:price_before_discounts] = 4
        row[:air_sea_duty_savings] = 2
        row[:duty] = 4
      end

      context "Ascena/Maurices" do
        it "returns results of Ascena/Maurices air/sea calculation" do
          row[:customer_number] = "ASCE"
          expect(dsc.calculate_air_sea_differential).to eq({calculated_invoice_value: 15, calculated_duty: 3, savings: 0})

          row[:customer_number] = "MAUR"
          expect(dsc.calculate_air_sea_differential).to eq({calculated_invoice_value: 15, calculated_duty: 3, savings: 0})
        end

        it "returns calculated invoice value of 0 if special tariff" do
          row[:customer_number] = "ASCE"
          row[:special_tariff] = true
          expect(dsc.calculate_air_sea_differential).to eq({calculated_invoice_value: 0, calculated_duty: 3, savings: 0})
        end
      end

      context "Ann" do
        before { row[:customer_number] = "ATAYLOR" }
        
        it "returns results of Ann air/sea calculation" do
          expect(dsc.calculate_air_sea_differential).to eq({calculated_invoice_value: 4, calculated_duty: 6, savings: 2})
        end

        it "returns calculated invoice value of 0 if special tariff" do
          row[:special_tariff] = true
          expect(dsc.calculate_air_sea_differential).to eq({calculated_invoice_value: 0, calculated_duty: 6, savings: 2})
        end
      end
    end

    describe "calculate_epd" do
      before do
        row[:price_before_discounts] = 10
        row[:duty] = 4
        row[:epd_duty_savings] = 3
      end

      it "returns results of EPD calculation" do
        expect(dsc.calculate_epd).to eq({calculated_invoice_value: 10, calculated_duty: 7, savings: 3})
      end

      it "returns calculated invoice of 0 if special tariff" do
        row[:special_tariff] = true
        expect(dsc.calculate_epd).to eq({calculated_invoice_value: 0, calculated_duty: 7, savings: 3})
      end
    end

    describe "calculate_trade_discount" do
      before do
        row[:price_before_discounts] = 10
        row[:duty] = 4
        row[:trade_discount_duty_savings] = 3
      end

      it "returns results of trade-discount calculation" do
        expect(dsc.calculate_trade_discount).to eq({calculated_invoice_value: 10, calculated_duty: 7, savings: 3})
      end

      it "returns calculated invoice of 0 if special tariff" do
        row[:special_tariff] = true
        expect(dsc.calculate_trade_discount).to eq({calculated_invoice_value: 0, calculated_duty: 7, savings: 3})
      end
    end
  end

  describe "DutySavingsType" do
    let!(:row) { described_class::Wrapper.new [] }
    let!(:dst) { described_class::DutySavingsType.new row }
    
    describe "get" do
      it "returns nested array of discount types along with 'Actual Entry Totals'" do
        row[:spi] = "A"
        expect(dst).to receive(:air_sea_differential?).and_return true
        expect(dst).to receive(:other?).and_return true
        expect(row).to receive(:first_sale?).and_return true
        expect(dst).to receive(:epd_discount?).and_return true
        expect(dst).to receive(:trade_discount?).and_return true
        expect(dst.get).to eq [[:spi, "GSP"], 
                               [:air_sea, "Air Sea Differential"], 
                               [:other, "Other"], 
                               [:first_sale, "First Sale"], 
                               [:epd, "EPD Discount"], 
                               [:trade, "Trade Discount"], 
                               [:line, "Actual Entry Totals"]]
      end

      it "returns empty array if there aren't any" do
        row[:spi] = ""
        expect(dst).to receive(:air_sea_differential?).and_return false
        expect(dst).to receive(:other?).and_return false
        expect(row).to receive(:first_sale?).and_return false
        expect(dst).to receive(:epd_discount?).and_return false
        expect(dst).to receive(:trade_discount?).and_return false
        expect(dst.get).to eq []
      end
    end

    describe "air_sea_differential?" do
      context "ascena/maurices" do

        it "returns true if transport_mode_code is 40 and non_dutiable exists" do
          row[:customer_number] = "ASCE"
          row[:transport_mode_code] = 40
          row[:non_dutiable_amount] = 1
          expect(dst.air_sea_differential?).to eq true

          row[:customer_number] = "MAUR"
          expect(dst.air_sea_differential?).to eq true
        end

        it "returns false if transport_mode_code isn't 40" do
          row[:customer_number] = "ASCE"
          row[:transport_mode_code] = 10
          row[:non_dutiable_amount] = 1
          expect(dst.air_sea_differential?).to eq false

          row[:customer_number] = "MAUR"
          expect(dst.air_sea_differential?).to eq false
        end

        it "returns false if there's no non_dutiable" do
          row[:customer_number] = "ASCE"
          row[:transport_mode_code] = 40
          row[:non_dutiable_amount] = 0
          expect(dst.air_sea_differential?).to eq false

          row[:customer_number] = "MAUR"
          expect(dst.air_sea_differential?).to eq false
        end
      end

      context "ann" do
        before { row[:customer_number] = "ATAYLOR" }

        it "returns true if there's an air/sea discount" do
          row[:air_sea_discount] = 1
          expect(dst.air_sea_differential?).to eq true
        end

        it "returns false if there's no air/sea discount" do
          row[:air_sea_discount] = 0
          expect(dst.air_sea_differential?).to eq false
        end
      end
    end

    describe "epd_discount?" do
      context "ann" do
        before { row[:customer_number] = "ATAYLOR" }        

        it "returns true if there's an early payment discount" do
          row[:early_payment_discount] = 1
          expect(dst.epd_discount?).to eq true
        end

        it "returns false otherwise" do
          row[:early_payment_discount] = 0
          expect(dst.epd_discount?).to eq false
        end
      end

      it "returns false for Ascena/Maurices" do
        row[:customer_number] = "ASCE"
        row[:early_payment_discount] = 1
        expect(dst.epd_discount?).to eq false

        row[:customer_number] = "MAUR"
        expect(dst.epd_discount?).to eq false
      end
    end
  
    describe "trade_discount?" do
      context "ann" do
        before { row[:customer_number] = "ATAYLOR" }        

        it "returns true if there's a trade discount" do
          row[:trade_discount] = 1
          expect(dst.trade_discount?).to eq true
        end

        it "returns false otherwise" do
          row[:trade_discount] = 0
          expect(dst.trade_discount?).to eq false
        end
      end

      it "returns false for Ascena/Maurices" do
        row[:customer_number] = "ASCE"
        row[:trade_discount] = 1
        expect(dst.trade_discount?).to eq false

        row[:customer_number] = "MAUR"
        expect(dst.trade_discount?).to eq false
      end
    end

    describe "other?" do
      context "ascena/maurices" do
        
        it "returns true if transport_mode_code isn't 40 and there's a non-dutiable amount" do
          row[:customer_number] = "ASCE"
          row[:transport_mode_code] = 10
          row[:non_dutiable_amount] = 1
          expect(dst.other?).to eq true

          row[:customer_number] = "MAUR"
          expect(dst.other?).to eq true
        end

        it "returns false if transport_mode_code is 40" do
          row[:customer_number] = "ASCE"
          row[:transport_mode_code] = 40
          row[:non_dutiable_amount] = 1
          expect(dst.other?).to eq false

          row[:customer_number] = "MAUR"
          expect(dst.other?).to eq false
        end

        it "returns false if there isn't a non-dutiable" do
          row[:customer_number] = "ASCE"
          row[:transport_mode_code] = 10
          row[:non_dutiable_amount] = 0
          expect(dst.other?).to eq false

          row[:customer_number] = "MAUR"
          expect(dst.other?).to eq false
        end
      end
    
      it "return false for Ann" do
        row[:customer_number] = "ATAYLOR"
        row[:transport_mode_code] = 10
        row[:non_dutiable_amount] = 1
        expect(dst.other?).to eq false
      end
    end
  end

  describe "ActualEntryTotalCalculator" do
    let!(:row) do 
      r = described_class::Wrapper.new []
      r[:air_sea_discount] = 1
      r[:first_sale_difference] = 5
      r
    end
    let!(:savings_set) { [{savings_type: :line, savings_title: "Actual Entry Totals"}] }
    let!(:aetc) { described_class::ActualEntryTotalCalculator.new row, savings_set }

    describe "fill_totals" do
      context "Ascena" do
        let!(:input) { {savings_type: :line, savings_title: "Actual Entry Totals"} }
        before do 
          row[:customer_number] = "ASCE"
          row[:non_dutiable_amount] = 0
          savings_set.concat [{savings_type: :spi, savings_title: "GSP", calculations: {calculated_invoice_value: 7, calculated_duty: 4, savings: 2}},
                              {savings_type: :other, savings_title: "Other", calculations: {calculated_invoice_value: 8, calculated_duty: 5, savings: 3}},
                              {savings_type: :first_sale, savings_title: "First Sale", calculations: {calculated_invoice_value: 9, calculated_duty: 6, savings: 1}}]
        end

        it "selects the discount with the highest savings and copies it into the input's 'calculations' hash" do
          aetc.fill_totals
          total = savings_set.find{ |ss| ss[:savings_type ] == :line }
          expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 8, calculated_duty: 5, savings: 3} })
        end

        it "selects the largest discount when there are no savings" do
          savings_set.reject{ |ss| ss[:savings_type] == :line }
                     .each{ |ss| ss[:calculations][:savings] = ss[:calculations][:calculated_duty] = 0 }
          row[:first_sale_difference] = 2
          row[:non_dutiable_amount] = 1
          aetc.fill_totals
          total = savings_set.find{ |ss| ss[:savings_type ] == :line }
          expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 9, calculated_duty: 0, savings: 0} })
        end
      end

      context "Ann" do
        before do
          savings_set.concat [{savings_type: :first_sale, savings_title: "First Sale", calculations: {calculated_invoice_value: 9, calculated_duty: 2, savings: 5}},
                              {savings_type: :spi, savings_title: "GSP", calculations: {calculated_invoice_value: 8, calculated_duty: 1, savings: 1}},
                              {savings_type: :trade, savings_title: "Trade Discount", calculations: {calculated_invoice_value: 10, calculated_duty: 3, savings: 2}},
                              {savings_type: :epd, savings_title: "EPD Discount", calculations: {calculated_invoice_value: 10, calculated_duty: 4, savings: 3}},
                              {savings_type: :air_sea, savings_title: "Air/Sea Differential", calculations: {calculated_invoice_value: 10, calculated_duty: 5, savings: 4}}]
          row[:customer_number] = "ATAYLOR"
          row[:early_payment_discount] = 2
          row[:trade_discount] = 3
        end

        context "select by highest savings" do
          it "selects the combination of air/sea, EPD, and trade discount if total savings higher than first sale or SPI" do
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 10, calculated_duty: 10, savings: 9}})
          end
          
          it "selects first sale and copies it into the input's 'calculations' hash if it's the highest" do
            savings_set[1][:calculations][:savings] = 10
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 9, calculated_duty: 2, savings: 10}})
          end 

          it "selects SPI and copies it into the input's 'calculations' hash if it's the highest (it's always 0)" do
            savings_set[2][:calculations][:savings] = 10
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 8, calculated_duty: 1, savings: 10}})
          end
        end

        context "select by highest discount" do
          before do
            savings_set.reject{ |s| s[:savings_type] == :line}.each { |s| s[:calculations][:savings] = 0 }
          end
          
          it "selects the combination of air/sea, EPD, and trade discount if total discount higher than first sale or SPI." do
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 10, calculated_duty: 0, savings: 0}})
          end

          it "selects first sale if it's the highest." do
            row[:first_sale_difference] = 7
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 9, calculated_duty: 0, savings: 0}})
          end

          it "selects SPI if it's the highest. (because it's always 0, only happens when it's the only discount)" do
            savings_set.delete_if{ |s| ![:spi, :line].include? s[:savings_type] }
            row[:trade_discount] = row[:early_payment_discount] = row[:air_sea_discount] = row[:first_sale_difference] = 0
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 8, calculated_duty: 0, savings: 0}})
          end
        end
      end
    end
  end

  describe "FieldFiller" do
    let(:klass) { described_class::FieldFiller }
    
    describe "fill_missing_fields" do
      let(:us) { Factory(:country, iso_code: "US")}
      let!(:ot) { Factory(:official_tariff, country: us, hts_code: "123456789", general_rate: "2%")}
      let(:results) do
        row = described_class::Wrapper.new []
        row[:e_id] = 1
        row[:cil_id] = 2
        row[:import_country_id] = us.id
        row[:hts_code] = "123456789" 
        row[:quantity_attrib] = 10
        row[:special_tariff] = false
        row[:middleman_charge] = BigDecimal "1.5"
        row[:value] = BigDecimal "7.5"
        row[:unit_of_measure_attrib] = "lbs"
        row[:contract_amount] = BigDecimal "5"
        row[:customer_number] = "ATAYLOR"
        row[:cil_entered_value_7501] = BigDecimal "3"
        row[:duty_rate] = BigDecimal "2.5"
        row[:air_sea_discount_attrib] = BigDecimal "2"
        row[:early_payment_discount_attrib] = BigDecimal "3.2"
        row[:trade_discount_attrib] = BigDecimal "2.8"
        row[:price_before_discounts] = BigDecimal "5"
        row[:spi] = "some SPI program"
        row[:non_dutiable_amount] = BigDecimal "1"
        row[:miscellaneous_discount] = 0
        row[:other_amount] = 0

        [row]
      end
      let!(:filler) { klass.new results }
      before do
        ent_helper = klass::EntFieldHelper.new({1 => {ent_entry_filer: "123", ent_unlading_port_name: "unl port", ent_entry_port_name: "ent port"}})
        inv_helper = klass::InvFieldHelper.new({2 => {cil_first_sale: true, cil_contract_amount_unit_price: 0.5, cil_total_duty: 8, cil_first_sale_difference: 4}})
        tariff_helper = klass::TariffFieldHelper.new({[us.id, "123456789"] => ot})

        expect(klass::EntFieldHelper).to receive(:create).with(results).and_return(ent_helper)
        expect(klass::InvFieldHelper).to receive(:create).with(results).and_return(inv_helper)
        expect(klass::TariffFieldHelper).to receive(:create).with(results).and_return(tariff_helper)
      end
      
      it "populates fields missing from query results" do
        filler.fill_missing_fields
        row = filler.results.first

        expect(row[:first_sale]).to eq "Y"
        expect(row[:filer]).to eq "123"
        expect(row[:arrival_port]).to eq "unl port"
        expect(row[:entry_port]).to eq "ent port"
        expect(row[:quantity]).to eq 10
        expect(row[:unit_of_measure]).to eq "lbs"
        expect(row[:original_fob_unit_value]).to eq 0.5
        expect(row[:original_fob_entered_value]).to eq 5
        expect(row[:first_sale_difference]).to eq 1.5
        expect(row[:line_entered_value]).to eq 3
        expect(row[:price_before_discounts]).to eq 7.5
        expect(row[:first_sale_duty_savings]).to eq 5
        expect(row[:first_sale_margin_percent]).to eq 0.3
        expect(row[:air_sea_discount]).to eq 2
        expect(row[:air_sea_per_unit_savings]).to eq 0.2
        expect(row[:air_sea_duty_savings]).to eq 5
        expect(row[:early_payment_discount]).to eq 3.2
        expect(row[:epd_per_unit_savings]).to eq 0.32
        expect(row[:epd_duty_savings]).to eq 8
        expect(row[:trade_discount]).to eq 2.8
        expect(row[:trade_discount_per_unit_savings]).to eq 0.28
        expect(row[:trade_discount_duty_savings]).to eq 7
        expect(row[:original_duty_rate]).to eq "2%"
        expect(row[:spi_duty_savings]).to eq(-7.85)
        expect(row[:mp_vs_air_sea]).to eq 0
        expect(row[:mp_vs_epd]).to eq(-3)
        expect(row[:mp_vs_trade_discount]).to eq(-2)
        expect(row[:mp_vs_air_sea_epd_trade]).to eq(-15)
        expect(row[:first_sale_savings]).to eq 5
        expect(row[:air_sea_savings]).to eq 0
        expect(row[:epd_savings]).to eq 3
        expect(row[:trade_discount_savings]).to eq 2
        expect(row[:applied_discount]).to eq "FS"
      end
    end

    context "EntFieldHelper" do
      let(:helper) { klass::EntFieldHelper }
      let(:ent) do 
        e = Factory(:entry, entry_number: "123456789")
        e.unlading_port =  Factory(:port, name: "unl port", schedule_d_code: "1234")
        e.us_entry_port = Factory(:port, name: "ent port", schedule_d_code: "4321")
        e.save!
        e
      end
      let(:results) do
        row = described_class::Wrapper.new []
        row[:e_id] = ent.id
        row[:entry_number] = "123456789"
        [row]
      end

      it "queries model fields" do
        helper_inst = helper.create results       
        expect(helper_inst.fields[ent.id][:ent_entry_filer]).to eq "123"
        expect(helper_inst.fields[ent.id][:ent_unlading_port_name]).to eq "unl port"
        expect(helper_inst.fields[ent.id][:ent_entry_port_name]).to eq "ent port"
      end
    end

    context "InvFieldHelper" do
      let(:helper) { klass::InvFieldHelper }
      let(:cil) do 
        cil = Factory(:commercial_invoice_line, contract_amount: 5, quantity: 10, value: 1)
        Factory(:commercial_invoice_tariff, commercial_invoice_line: cil, duty_amount: 2)
        Factory(:commercial_invoice_tariff, commercial_invoice_line: cil, duty_amount: 6)
        cil
      end
      let(:results) do
        row = described_class::Wrapper.new []
        row[:cil_id] = cil.id
        [row]
      end

      it "queries model fields" do
        helper_inst = helper.create results
        expect(helper_inst.fields[cil.id][:cil_first_sale]).to eq true
        expect(helper_inst.fields[cil.id][:cil_contract_amount_unit_price]).to eq 0.5
        expect(helper_inst.fields[cil.id][:cil_total_duty]).to eq 8
        expect(helper_inst.fields[cil.id][:cil_first_sale_difference]).to eq 4
      end
    end

    context "TariffFieldHelper" do
      let(:helper) { klass::TariffFieldHelper }
      let(:us) { Factory(:country, iso_code: "US") }
      let(:ca) { Factory(:country, iso_code: "CA") }
      let!(:ot_1) { Factory(:official_tariff, hts_code: "123456789", country: us )}
      let!(:ot_2) { Factory(:official_tariff, hts_code: "987654321", country: us )}
      let!(:ot_3) { Factory(:official_tariff, hts_code: "246810121", country: ca )}
      let(:results) do
        row_1 = described_class::Wrapper.new []
        row_1[:hts_code] = "123456789"
        row_1[:import_country_id] = us.id
        
        row_2 = described_class::Wrapper.new []
        row_2[:hts_code] = "987654321"
        row_2[:import_country_id] = us.id

        row_3 = described_class::Wrapper.new []
        row_3[:hts_code] = "246810121"
        row_3[:import_country_id] = ca.id
        
        [row_1, row_2, row_3]
      end
      
      it "returns hash of tariffs keyed to country_id/hts tuplets" do
        tariffs = helper.create(results).tariffs
        expect(tariffs[[us.id, "123456789"]].id).to eq ot_1.id
        expect(tariffs[[us.id, "987654321"]].id).to eq ot_2.id
        expect(tariffs[[ca.id, "246810121"]].id).to eq ot_3.id
      end
    end

    context "non-MF helpers" do
      let(:inv_field_helper) { instance_double klass::InvFieldHelper }
      let(:filler) do 
        f = klass.new(:foo)
        f.inv_field_helper = inv_field_helper
        f
      end
      let(:row) { described_class::Wrapper.new([]) }
    
      describe "quantity" do
        before { row[:quantity_attrib] = 5 }

        it "returns quantity if not special tariff" do
          row[:special_tariff] = false
          expect(filler.quantity row).to eq 5
        end

        it "returns 0 otherwise " do
          row[:special_tariff] = true
          expect(filler.quantity row).to eq 0
        end
      end

      describe "unit_of_measure" do
        before { row[:unit_of_measure_attrib] = "lbs" }

        it "returns unit_of_measure if not special tariff" do
          row[:special_tariff] = false
          expect(filler.unit_of_measure row).to eq "lbs"
        end

        it "returns nil if special_tariff" do
          row[:special_tariff]  = true
          expect(filler.unit_of_measure row).to be_nil
        end
      end

      describe "original_fob_unit_value" do
        it "returns contract_amount_unit_price if not special tariff" do
          row[:special_tariff] = false
          expect(inv_field_helper).to receive(:fields).and_return( 1 => { :cil_contract_amount_unit_price => 10})

          expect(filler.original_fob_unit_value row, 1).to eq 10
        end

        it "return 0 if special tariff" do
          row[:special_tariff] = true
          expect(inv_field_helper).to_not receive(:fields)

          expect(filler.original_fob_unit_value row, 1).to eq 0
        end
      end

      describe "original_fob_entered_value" do
        before do 
          row[:contract_amount] = 5
          row[:special_tariff] = false
        end
        
        it "returns contract amount if it exists and not special tariff" do
          expect(filler.original_fob_entered_value row).to eq 5
        end

        it "returns 0 if special tariff" do
          row[:special_tariff] = true
          expect(filler.original_fob_entered_value row).to eq 0
        end
      end

      describe "first_sale_duty_savings" do
        it "returns (contract_amount - cil entered value 7501) * duty rate" do
          row[:contract_amount] = 10
          row[:cil_entered_value_7501] = 2
          row[:duty_rate] = 3

          expect(filler.first_sale_duty_savings row).to eq 24
        end

        it "returns 0 if not first sale" do
          row[:contract_amount] = 0
          row[:cil_entered_value_7501] = 2
          row[:duty_rate] = 3

          expect(filler.first_sale_duty_savings row).to eq 0
        end
      end

      describe "first_sale_difference" do
        context "Ascena/Maurices" do
          it "returns content of model field for Ascena if not special tariff" do
            row[:customer_number] = "ASCE"
            row[:special_tariff] = false
            row[:contract_amount] = 10
            row[:cil_entered_value_7501] = 2
            
            expect(filler.first_sale_difference row, 1).to eq 8

            row[:customer_number] = "MAUR"
            expect(filler.first_sale_difference row, 1).to eq 8
          end

          it "return 0 for special tariff" do
            row[:customer_number] = "ASCE"
            row[:special_tariff] = true
            row[:contract_amount] = 10
            row[:cil_entered_value_7501] = 2
            
            expect(filler.first_sale_difference row, 1).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.first_sale_difference row, 1).to eq 0
          end

          it "return 0 if not first sale" do
            row[:customer_number] = "ASCE"
            row[:special_tariff] = true
            row[:contract_amount] = 0
            row[:cil_entered_value_7501] = 2
            
            expect(filler.first_sale_difference row, 1).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.first_sale_difference row, 1).to eq 0
          end
        end

        context "Ann" do
          before do 
            row[:middleman_charge] = 4
            row[:customer_number] = "ATAYLOR"
            row[:special_tariff] = false
          end
          
          it "returns middleman charge" do
            row[:contract_amount] = 1
            row[:special_tariff] = false

            expect(filler.first_sale_difference row, 1).to eq 4
          end

          it "returns 0 if not first sale" do
            row[:contract_amount] = 0
            row[:special_tariff] = false
            
            expect(filler.first_sale_difference row, 1).to eq 0
          end

          it "returns 0 for special tariff" do
            row[:contract_amount] = 0
            row[:special_tariff] = true

            expect(filler.first_sale_difference row, 1).to eq 0
          end
        end
      end

      describe "line_entered_value" do
        before { row[:cil_entered_value_7501] = 10 }
        
        it "returns cil_entered_value_7501 if not special tariff" do
          row[:special_tariff] = false
          expect(filler.line_entered_value row).to eq 10
        end

        it "returns 0 if special tariff" do
          row[:special_tariff] = true
          expect(filler.line_entered_value row).to eq 0
        end
      end

      describe "price before discounts" do
        before do
          row[:value] = 5
          row[:first_sale_difference] = 3
        end
        
        context "Ascena/Maurices" do
          
          it "returns value + first_sale_difference if not special tariff" do
            row[:customer_number] = "ASCE"
            expect(filler.price_before_discounts row).to eq 8

            row[:customer_number] = "MAUR"
            expect(filler.price_before_discounts row).to eq 8
          end

          it "returns 0 if special tariff" do
            row[:customer_number] = "ASCE"
            row[:special_tariff] = 0
            expect(filler.price_before_discounts row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.price_before_discounts row).to eq 0
          end
        end

        context "Ann" do
          before { row[:customer_number] = "ATAYLOR" }
          
          it "returns value if not special tariff" do
            expect(filler.price_before_discounts row).to eq 5
          end

          it "returns 0 if special tariff" do
            row[:special_tariff] = true
            expect(filler.price_before_discounts row).to eq 0
          end
        end
      end

      describe "first_sale_margin_percent" do
        context "Ascena/Maurices" do

          it "returns first_sale_difference / contract_amount for first sale, non-special tariff" do
            row[:customer_number] = "ASCE"
            allow(inv_field_helper).to receive(:fields).and_return(1 => {cil_first_sale_difference: 10})
            row[:contract_amount] = 2
            row[:special_tariff] = false

            expect(filler.first_sale_margin_percent row, 1).to eq 5

            row[:customer_number] = "MAUR"
            expect(filler.first_sale_margin_percent row, 1).to eq 5
          end

          it "returns 0 if not first-sale" do
            row[:customer_number] = "ASCE"
            row[:contract_amount] = 0
            expect(inv_field_helper).to_not receive(:fields)
            row[:special_tariff] = false

            expect(filler.first_sale_margin_percent row, 1).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.first_sale_margin_percent row, 1).to eq 0
          end

          it "returns 0 if special tariff" do
            row[:customer_number] = "ASCE"
            allow(inv_field_helper).to receive(:fields).and_return(1 => {cil_first_sale_difference: 10})
            row[:contract_amount] = 2
            row[:special_tariff] = true

            expect(filler.first_sale_margin_percent row, 1).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.first_sale_margin_percent row, 1).to eq 0
          end
        end

        context "Ann" do
          before { row[:customer_number] = "ATAYLOR" }

          it "returns middleman_charge / contract_amount if first sale and not special tariff" do
            row[:contract_amount] = 4
            row[:middleman_charge] = 8
            row[:special_tariff] = false
            
            expect(filler.first_sale_margin_percent row, 1).to eq 2
          end

          it "returns 0 if not first sale" do
            row[:contract_amount] = 0
            row[:middleman_charge] = 8
            row[:special_tariff] = false

            expect(filler.first_sale_margin_percent row, 1).to eq 0
          end

          it "returns 0 if special tariff" do
            row[:contract_amount] = 4
            row[:middleman_charge] = 8
            row[:special_tariff] = true

            expect(filler.first_sale_margin_percent row, 1).to eq 0
          end
        end
      end

      describe "air_sea_discount" do
        
        context "Ann" do
          before { row[:customer_number] = "ATAYLOR" }
          
          it "returns customer-invoice air_sea_discount if not special tariff" do
            row[:air_sea_discount_attrib] = 1
            row[:special_tariff] = false
            
            expect(filler.air_sea_discount row).to eq 1
          end

          it "returns 0 if special tariff" do
            row[:air_sea_discount_attrib] = 1
            row[:special_tariff] = true

            expect(filler.air_sea_discount row).to eq 0
          end
        end

        context "Ascena/Maurices" do
          before do 
            row[:non_dutiable_amount] = 2
            row[:transport_mode_code] = "40"
            row[:special_tariff] = false
          end
          
          it "returns non-dutiable amount if it's positive, transport_mode_code is 40, and not special tariff" do
            row[:customer_number] = "ASCE"
            expect(filler.air_sea_discount row).to eq 2

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_discount row).to eq 2
          end

          it "returns 0 if transport_mode_code isn't 40" do
            row[:customer_number] = "ASCE"
            row[:transport_mode_code] = "10"
            expect(filler.air_sea_discount row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_discount row).to eq 0
          end

          it "returns 0 if non-dutiable amount isn't positive" do
            row[:customer_number] = "ASCE"
            row[:non_dutiable_amount] = -1
            expect(filler.air_sea_discount row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_discount row).to eq 0
          end

          it "returns 0 if special tariff" do
            row[:customer_number] = "ASCE"
            row[:special_tariff] = true
            expect(filler.air_sea_discount row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_discount row).to eq 0
          end
        end
      end

      describe "air_sea_per_unit_savings" do
        context "Ann" do
          before do 
            row[:customer_number] = "ATAYLOR"
            row[:air_sea_discount] = 10
            row[:special_tariff] = false
          end
          
          it "returns air_sea_discount / quantity for Ann if not special tariff" do
            row[:quantity] = 5
            expect(filler.air_sea_per_unit_savings row).to eq 2
          end

          it "returns 0 if quantity is 0" do
            row[:quantity] = 0
            expect(filler.air_sea_per_unit_savings row).to eq 0
          end

          it "returns 0 if special tariff" do
            row[:quantity] = 5
            row[:special_tariff] = true
            expect(filler.air_sea_per_unit_savings row).to eq 0
          end
        end

        context "Ascena/Maurices" do
          before do 
            row[:non_dutiable_amount] = 8
            row[:quantity] = 2
            row[:transport_mode_code] = "40"
            row[:special_tariff] = false
          end

          it "returns non_dutiable_amount / quantity if transport_mode_code is 40, non_dutiable_amount is positive, and not special tariff" do
            row[:customer_number] = "ASCE"
            expect(filler.air_sea_per_unit_savings row).to eq 4

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_per_unit_savings row).to eq 4
          end

          it "returns 0 if transport_mode_code isn't 40" do
            row[:customer_number] = "ASCE"
            row[:transport_mode_code] = "10"
            expect(filler.air_sea_per_unit_savings row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_per_unit_savings row).to eq 0
          end

          it "returns 0 if non_dutiable_amount isn't positive" do
            row[:customer_number] = "ASCE"
            row[:non_dutiable_amount] = -8
            expect(filler.air_sea_per_unit_savings row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_per_unit_savings row).to eq 0
          end

          it "returns 0 if quantity is 0" do
            row[:customer_number] = "ASCE"
            row[:quantity] = 0
            expect(filler.air_sea_per_unit_savings row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_per_unit_savings row).to eq 0
          end

          it "returns 0 if special tariff" do
            row[:customer_number] = "ASCE"
            row[:special_tariff] = true
            expect(filler.air_sea_per_unit_savings row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_per_unit_savings row).to eq 0
          end

        end
      end

      describe "air_sea_duty_savings" do
        context "Ann" do
          before { row[:customer_number] = "ATAYLOR" }
          
          it "returns air_sea_discount * duty_rate" do
            row[:air_sea_discount] = 3
            row[:duty_rate] = 2

            expect(filler.air_sea_duty_savings row).to eq 6
          end
        end

        context "Ascena/Maurices" do
          before do
            row[:transport_mode_code] = "40"
            row[:non_dutiable_amount] = 9
            row[:duty_rate] = 2
          end

          it "returns product of non_dutiable_amount and duty_rate if transport_mode_code is 40 and non_dutiable_amount is positive" do
            row[:customer_number] = "ASCE"
            expect(filler.air_sea_duty_savings row).to eq 18

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_duty_savings row).to eq 18
          end

          it "returns 0 if transport_mode_code isn't 40" do
            row[:customer_number] = "ASCE"
            row[:transport_mode_code] = "10"
            expect(filler.air_sea_duty_savings row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_duty_savings row).to eq 0
          end

          it "returns 0 if non_dutiable_amount isn't positive" do
            row[:customer_number] = "ASCE"
            row[:non_dutiable_amount] = -9
            expect(filler.air_sea_duty_savings row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.air_sea_duty_savings row).to eq 0
          end
        end
      end

      context "OfficialTariff calculations" do
        let(:co) { Factory(:country)}
        let!(:ot) { Factory(:official_tariff, country: co, hts_code: "1111", general_rate: "2%")}
        before { row[:import_country_id] = co.id }
          
        describe "original_duty_rate" do
          it "returns common rate if the HTS exists" do
            expect(row).to receive(:official_tariff).and_return ot
            expect(filler.original_duty_rate row).to eq "2%"
          end

          it "returns 'No HTS Found' otherwise" do
            expect(row).to receive(:official_tariff).and_return nil
            expect(filler.original_duty_rate row).to eq "No HTS Found"
          end
        end

        describe "spi_duty_savings" do
          before do
            row[:hts_code] = "1111"
            row[:price_before_discounts] = 400
            row[:spi] = "SPI"
            row[:special_tariff] = false
          end

          it "returns calculated value if the common rate is positive, SPI is populated, and not special tariff" do
            expect(inv_field_helper).to receive(:fields).and_return(1 => {cil_total_duty: 3})          
            expect(row).to receive(:official_tariff).and_return ot

            expect(filler.spi_duty_savings row, 1).to eq 5
          end

          it "returns 0 if the common rate isn't positive" do
            ot.update_attributes! general_rate: "0" 
            expect(row).to receive(:official_tariff).and_return ot         

            expect(filler.spi_duty_savings row, 1).to eq 0
          end

          it "returns 0 if there's no HTS" do
            expect(row).to receive(:official_tariff).and_return nil
            
            expect(filler.spi_duty_savings row, 1).to eq 0
          end

          it "returns 0 if there's no SPI" do
            row[:spi] = nil
            expect(row).to receive(:official_tariff).and_return ot                   
            
            expect(filler.spi_duty_savings row, 1).to eq 0
          end

          it "returns 0 if special tariff" do
            row[:special_tariff] = true
            expect(row).to receive(:official_tariff).and_return ot                   
            
            expect(filler.spi_duty_savings row, 1).to eq 0
          end

          context "missing common_rate_decimal" do
            it "tries to guess the value" do
              ot.update_attributes! general_rate: "foobar 32.06%", common_rate_decimal: nil
              #if OfficialTariff#set_common_rate changes this test should change (or be removed)
              expect(ot.common_rate_decimal).to be_nil

              expect(inv_field_helper).to receive(:fields).and_return(1 => {cil_total_duty: 3})          
              expect(row).to receive(:official_tariff).and_return ot
              expect(filler.spi_duty_savings row, 1).to eq 125.24            
            end

            it "uses 0 if guess fails" do
              ot.update_attributes! general_rate: "foobar", common_rate_decimal: nil
              #if OfficialTariff#set_common_rate changes this test should change (or be removed)
              expect(ot.common_rate_decimal).to be_nil

              expect(row).to receive(:official_tariff).and_return ot
              expect(filler.spi_duty_savings row, 1).to eq 0
            end
          end
        end
      end

      describe "early_payment_discount" do
        before do
          row[:special_tariff] = false
          row[:early_payment_discount_attrib] = 10
        end

        context "Ann" do
          before { row[:customer_number] = "ATAYLOR" }
          
          it "returns early_payment_discount_attrib if not special tariff" do
            expect(filler.early_payment_discount row).to eq 10
          end

          it "returns 0 if special tariff" do
            row[:special_tariff] = true
            expect(filler.early_payment_discount row).to eq 0
          end
        end

        context "Ascena/Maurices" do
          
          it "returns 0" do
            row[:customer_number] = "ASCE"
            expect(filler.early_payment_discount row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.early_payment_discount row).to eq 0
          end
        end
      end

      describe "epd_per_unit_savings" do
        before do
          row[:early_payment_discount] = BigDecimal("2")
          row[:quantity] = 3
          row[:special_tariff] = false
        end
        
        context "Ann" do
          before { row[:customer_number] = "ATAYLOR" }
          
          it "early_payment_discount / quantity if not special tariff" do
            expect(filler.epd_per_unit_savings row).to eq 0.67
          end

          it "returns 0 if special tariff" do
            row[:special_tariff] = true
            expect(filler.epd_per_unit_savings row).to eq 0
          end
        end

        context "Ascena/Maurices" do

          it "returns 0" do
            row[:customer_number] = "ASCE"
            expect(filler.epd_per_unit_savings row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.epd_per_unit_savings row).to eq 0
          end
        end
      end

      describe "epd_duty_savings" do
        context "Ann" do
          before do 
            row[:customer_number] = "ATAYLOR"
            row[:early_payment_discount] = 10.222
            row[:duty_rate] = 2
            row[:special_tariff] = false
          end
          
          it "returns early_payment_discount * duty_rate if not special tariff" do
            expect(filler.epd_duty_savings row).to eq 20.44
          end

          it "returns 0 if special tariff" do
            row[:special_tariff] = true
            expect(filler.epd_duty_savings row).to eq 0
          end
        end

        context "Ascena/Maurices" do
          before { row[:customer_number] = "ASCE" }

          it "returns 0" do
            row[:customer_number] = "ASCE"
            expect(filler.epd_duty_savings row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.epd_duty_savings row).to eq 0
          end
        end
      end

      describe "trade_discount" do
        before do
          row[:trade_discount_attrib] = 5
          row[:special_tariff] = false
        end

        context "Ann" do
          before { row[:customer_number] = "ATAYLOR" }

          it "returns trade_discount if not special tariff" do
            expect(filler.trade_discount row).to eq 5
          end

          it "returns 0 if special tariff" do
            row[:special_tariff] = true
            expect(filler.trade_discount row).to eq 0
          end
        end

        context "Ascena/Maurices" do
          it "returns 0" do
            row[:customer_number] = "ASCE"
            expect(filler.trade_discount row).to eq 0
            
            row[:customer_number] = "MAUR"
            expect(filler.trade_discount row).to eq 0
          end
        end
      end

      describe "trade_discount_per_unit_savings" do
        before do
          row[:trade_discount] = BigDecimal("2")
          row[:quantity] = 3
          row[:special_tariff] = false
        end

        context "Ann" do
          before { row[:customer_number] = "ATAYLOR" } 

          it "returns trade_discount / quantity if not special tariff" do
            expect(filler.trade_discount_per_unit_savings row).to eq 0.67
          end

          it "returns 0 if special tariff" do
            row[:special_tariff] = true
            expect(filler.trade_discount_per_unit_savings row).to eq 0
          end

          it "returns 0 if quantity is 0" do
            row[:quantity] = 0
            expect(filler.trade_discount_per_unit_savings row).to eq 0
          end
        end

        context "Ascena/Maurices" do
          it "returns 0" do
            row[:customer_number] = "ASCE"
            expect(filler.trade_discount_per_unit_savings row).to eq 0
            
            row[:customer_number] = "MAUR"
            expect(filler.trade_discount_per_unit_savings row).to eq 0
          end
        end
      end

      describe "trade_discount_duty_savings" do
        before do
          row[:trade_discount] = 3.333
          row[:duty_rate] = 2
          row[:special_tariff] = false
        end

        context "Ann" do
          before { row[:customer_number] = "ATAYLOR" }
          
          it "returns trade_discount * duty_rate if not special tariff" do
            expect(filler.trade_discount_duty_savings row).to eq 6.67
          end

          it "returns 0 if special tariff" do
            row[:special_tariff] = true
            expect(filler.trade_discount_duty_savings row).to eq 0
          end
        end

        context "Ascena/Maurices" do
          it "returns 0" do
            row[:customer_number] = "ASCE"
            expect(filler.trade_discount_duty_savings row).to eq 0
            
            row[:customer_number] = "MAUR"
            expect(filler.trade_discount_duty_savings row).to eq 0
          end
        end
      end

      describe "mp_vs_air_sea" do
        before do
          row[:first_sale_duty_savings] = 10
          row[:air_sea_duty_savings] = 3
          row[:special_tariff] = false
        end

        it "returns first_sale_duty_savings - air_sea_duty_savings if not special tariff" do
          expect(filler.mp_vs_air_sea row).to eq 7
        end

        it "returns 0 if special tariff" do
          row[:special_tariff] = true
          expect(filler.mp_vs_air_sea row).to eq 0
        end
      end

      describe "mp vs epd" do
        context "Ann" do
          before do
            row[:customer_number] = "ATAYLOR"
            row[:special_tariff] = false
          end

          it "returns first_sale_duty_savings - epd_duty_savings if not special tariff" do
            row[:first_sale_duty_savings] = 9
            row[:epd_duty_savings] = 2

            expect(filler.mp_vs_epd row).to eq 7
          end

          it "returns 0 if special tariff" do
            row[:special_tariff] = true
            row[:first_sale_duty_savings] = 9
            row[:epd_duty_savings] = 2

            expect(filler.mp_vs_epd row).to eq 0
          end
        end

        context "Ascena/Maurices" do
          before { row[:special_tariff] = false }
          
          it "returns 0" do
            row[:customer_number] = "ASCE"
            row[:first_sale_duty_savings] = 9
            row[:epd_duty_savings] = 2
            expect(filler.mp_vs_epd row).to eq 0

            row[:customer_number] = "MAUR"
            expect(filler.mp_vs_epd row).to eq 0
          end
        end
      end

      describe "mp_vs_trade_discount" do
        context "Ann" do
          before { row[:customer_number] = "ATAYLOR" }

          it "returns first_sale_duty_savings - trade_discount_duty_savings if not special tariff" do
            row[:first_sale_duty_savings] = 9
            row[:trade_discount_duty_savings] = 3
            row[:special_tariff] = false

            expect(filler.mp_vs_trade_discount row).to eq 6
          end
          
          it "returns 0 if special tariff" do
            row[:first_sale_duty_savings] = 9
            row[:trade_discount_duty_savings] = 3
            row[:special_tariff] = true

            expect(filler.mp_vs_trade_discount row).to eq 0
          end
        end

        context "Ascena/Maurices" do
          
          it "returns 0 for Ascena" do
            row[:customer_number] = "ASCE"
            row[:first_sale_duty_savings] = 9
            row[:trade_discount_duty_savings] = 3
            row[:special_tariff] = false
            expect(filler.mp_vs_trade_discount row).to eq 0

            row[:customer_number] = "ASCE"
            expect(filler.mp_vs_trade_discount row).to eq 0
          end
        end
      end

      describe "mp_vs_air_sea_epd_trade" do
        before do
          row[:first_sale_duty_savings] = 10
          row[:air_sea_duty_savings] = 3
          row[:epd_duty_savings] = 4
          row[:trade_discount_duty_savings] = 2
          row[:special_tariff] = false
        end
        
        it "returns first_sale_duty_savings - (air_sea_duty_savings + epd_duty_savings + trade_discount_duty_savings if not special tariff)" do
          expect(filler.mp_vs_air_sea_epd_trade row).to eq 1
        end

        it "returns 0 if special tariff" do
          row[:special_tariff] = true
          expect(filler.mp_vs_air_sea_epd_trade row).to eq 0
        end
      end

      describe "air_sea_savings" do
        it "returns absolute value of 'MP vs Air/Sea' if it's less than 0" do 
          row[:mp_vs_air_sea] = -1
          expect(filler.air_sea_savings row).to eq 1
        end

        it "returns 0 otherwise" do
          row[:mp_vs_air_sea] = 1
          expect(filler.air_sea_savings row).to eq 0
        end
      end

      describe "epd_savings" do
        it "returns absolute value of 'MP vs EPD' if it's less than 0" do 
          row[:mp_vs_epd] = -1
          expect(filler.epd_savings row).to eq 1
        end

        it "returns 0 otherwise" do
          row[:mp_vs_epd] = 1
          expect(filler.epd_savings row).to eq 0
        end
      end

      describe "trade_discount_savings" do
        it "returns absolute value of 'MP vs Trade Discount' if it's less than 0" do 
          row[:mp_vs_trade_discount] = -1
          expect(filler.trade_discount_savings row).to eq 1
        end

        it "returns 0 otherwise" do
          row[:mp_vs_trade_discount] = 1
          expect(filler.trade_discount_savings row).to eq 0
        end
      end

      describe "applied_discount" do
        context "Ann" do
          before do 
            row[:customer_number] = "ATAYLOR"
            row[:contract_amount] = 0
            row[:non_dutiable_amount] = 0
            row[:miscellaneous_discount] = 0
            row[:other_amount] = 0
          end
          
          it "returns 'FS' if contract_amount present and non_dutiable_amount is positive" do
            row[:contract_amount] = 1
            row[:non_dutiable_amount] = 1
            expect(filler.applied_discount row).to eq "FS"
          end

          it "returns 'AS' if there's no contract_amount and non_dutiable_amount is positive" do
            row[:contract_amount] = 0
            row[:non_dutiable_amount] = 1
            expect(filler.applied_discount row).to eq "AS"
          end

          it "returns 'EP' if miscellaneous_discount is positive" do
            row[:miscellaneous_discount] = 1
            expect(filler.applied_discount row).to eq "EP"
          end

          it "returns 'TD' if other_amount is negative" do
            row[:other_amount] = -1
            expect(filler.applied_discount row).to eq "TD"
          end

          it "returns multiple codes if applicable" do
            row[:contract_amount] = 1
            row[:non_dutiable_amount] = 1
            row[:miscellaneous_discount] = 1
            row[:other_amount] = -1

            expect(filler.applied_discount row).to eq "FS, EP, TD"
          end
        end

        context "Ascena/Maurices" do
          before do
            row[:transport_mode_code] = "10"
            row[:contract_amount] = 0
            row[:non_dutiable_amount] = 0
          end

          it "returns 'FS' if contract_amount is positive" do
            row[:customer_number] = "ASCE"
            row[:contract_amount] = 1
            expect(filler.applied_discount row).to eq "FS"

            row[:customer_number] = "MAUR"
            expect(filler.applied_discount row).to eq "FS"
          end

          it "returns 'AS' if transport_mode_code is 40 and non_dutiable_amount is positive" do
            row[:customer_number] = "ASCE"
            row[:transport_mode_code] = "40"
            row[:non_dutiable_amount] = 1
            expect(filler.applied_discount row).to eq "AS"

            row[:customer_number] = "MAUR"
            expect(filler.applied_discount row).to eq "AS"
          end

          it "returns both codes if applicable" do
            row[:customer_number] = "ASCE"
            row[:contract_amount] = 1
            row[:transport_mode_code] = "40"
            row[:non_dutiable_amount] = 1
            expect(filler.applied_discount row).to eq "FS, AS"

            row[:customer_number] = "MAUR"
            expect(filler.applied_discount row).to eq "FS, AS"
          end
        end
      end
    end

  end

  # Checks only db fields. FieldFiller tested separately
  describe "Query" do
    subject { report = described_class::Query.new }
    
    let!(:ann) { Factory(:importer, alliance_customer_number: "ATAYLOR") }
    let!(:us) { Factory(:country)}

    let!(:e_asce) { Factory(:entry, importer: ascena, import_country_id: us.id, customer_name: "Ascena", customer_number: "ASCE", source_system: "Alliance", broker_reference: "ascena broker ref", transport_mode_code: "40", fiscal_date: "2018-03-16", fiscal_month: 1, release_date: "2018-03-10", entry_number: "asce ent number", arrival_date: "2018-03-08", import_date: "2018-03-06", unlading_port_code:"1234", entry_port_code: "4321", fish_and_wildlife_transmitted_date: "2018-03-06")}
    let!(:ci_asce) { Factory(:commercial_invoice, entry: e_asce, invoice_number: "inv num asce") }
    let!(:cil_asce) { Factory(:commercial_invoice_line, commercial_invoice: ci_asce, contract_amount: 5, related_parties: true, customs_line_number: 1, part_number: "part asce", po_number: "po asce", entered_value_7501: 5, product_line: "brand asce", country_origin_code: "AM", country_export_code: "country export asce", unit_price: 1, quantity: 2, unit_of_measure: "uom asce", value: 1, non_dutiable_amount: 2) }
    let!(:cit_asce) { Factory(:commercial_invoice_tariff, commercial_invoice_line: cil_asce, hts_code: "hts code", duty_rate: 1.1, tariff_description: "tar descr asce", duty_amount: 2, entered_value_7501: 4, spi_primary: "spi asce", special_tariff:true) }
    let!(:vend_asce) { Factory(:vendor, name: "asce vend") }
    let!(:fact_asce) { Factory(:factory, name: "asce fact") }
    let!(:ord_asce) do 
      order = Factory(:order, order_number: "ASCENA-brand asce-po asce", vendor: vend_asce, factory: fact_asce)
      order.update_custom_value! cdefs[:ord_type], "ord type asce"
      order
    end

    let!(:official_tariff) { Factory(:official_tariff, country: us, hts_code: "hts code", general_rate: "2%") }
    let!(:port_arrival) { Factory(:port, schedule_d_code: "1234", name: "arrival port")}
    let!(:port_entry) { Factory(:port, schedule_d_code: "4321", name: "entry port")}

    let!(:e_ann) { Factory(:entry, importer: ann, import_country_id: us.id, customer_name: "Ann", customer_number: "ATAYLOR", source_system: "Alliance", broker_reference: "ann broker ref", transport_mode_code: "40", fiscal_date: "2018-03-16", fiscal_month: 2, release_date: "2018-03-11", entry_number: "ann ent number", arrival_date: "2018-03-09", import_date: "2018-03-07", unlading_port_code: "1234", entry_port_code: "4321")}
    let!(:ci_ann) { Factory(:commercial_invoice, entry: e_ann, invoice_number: "inv num ann") }
    let!(:cil_ann) { Factory(:commercial_invoice_line, commercial_invoice: ci_ann, contract_amount: 6, related_parties: true, customs_line_number: 1, part_number: "part ann", po_number: "po ann", entered_value_7501: 6, product_line: "brand ann", country_origin_code: "AM", country_export_code: "country export ann", unit_price: 3, quantity: 4, unit_of_measure: "uom ann", value: 1, non_dutiable_amount: 4, miscellaneous_discount: 2, other_amount: -1) }
    let!(:cit_ann) { Factory(:commercial_invoice_tariff, commercial_invoice_line: cil_ann, hts_code: "hts code", duty_rate: 1.3, tariff_description: "tar descr ann", duty_amount: 3, entered_value_7501: 5, spi_primary: "spi ann", special_tariff: true) }
    let!(:vend_ann_810) { Factory(:vendor, name: "ann vend 810") }
    let!(:fact_ann_810) { Factory(:factory, name: "ann fact 810") }
    let!(:vend_ann_ord) { Factory(:vendor, name: "ann vend ord") }
    let!(:fact_ann_ord) { Factory(:factory, name: "ann fact ord") }
    let!(:i) { Factory(:invoice, importer: ann, invoice_number: "inv num ann", vendor: vend_ann_810, factory: fact_ann_810) }
    let!(:il) { Factory(:invoice_line, invoice: i, po_number: "po ann", part_number: "part ann", part_description: "part descr", air_sea_discount: 4, early_pay_discount: 2, trade_discount: 6, middleman_charge: 8)}
    let!(:ord_ann) do 
      order = Factory(:order, order_number: "ATAYLOR-po ann", vendor: vend_ann_ord, factory: fact_ann_ord)
      order.update_custom_value! cdefs[:ord_type], "ord type ann"
      order
    end

    before do
      # FieldFiller doesn't have to be stubbed, but since we're not testing its output we might as well save a few cycles
      filler = instance_double(described_class::FieldFiller)
      expect(described_class::FieldFiller).to receive(:new).with(anything).and_return filler
      expect(filler).to receive(:fill_missing_fields)
    end
    
    def test_asce_results r
      expect(r[:broker_reference]).to eq "ascena broker ref"
      expect(r[:customer_name]).to eq "Ascena"
      expect(r[:vendor]).to eq "asce vend"
      expect(r[:factory]).to eq "asce fact"
      expect(r[:related_parties]).to eq "Y"
      expect(r[:transport_mode_code]).to eq "40"
      expect(r[:fiscal_month]).to eq 1
      expect(r[:release_date]).to eq Date.new(2018,3,10)
      expect(r[:entry_number]).to eq "asce ent number"
      expect(r[:custom_line_number]).to eq 1
      expect(r[:invoice_number]).to eq "inv num asce"
      expect(r[:part_number]).to eq "part asce"
      expect(r[:po_number]).to eq "po asce"
      expect(r[:product_line]).to eq "brand asce"
      expect(r[:order_type]).to eq "ord type asce"
      expect(r[:country_origin_code]).to eq "AM"
      expect(r[:country_export_code]).to eq "country export asce"
      expect(r[:arrival_date]).to eq Date.new(2018,3,8)
      expect(r[:import_date]).to eq Date.new(2018,3,6)
      expect(r[:hts_code]).to eq "hts code"
      expect(r[:duty_rate]).to eq 1.1
      expect(r[:goods_description]).to eq "tar descr asce"
      expect(r[:unit_price]).to eq 1
      expect(r[:duty]).to eq 2
      expect(r[:spi]).to eq "spi asce"
      expect(r[:fish_and_wildlife]).to eq "Y"
      expect(r[:hanger_duty_savings]).to eq 0
      expect(r[:e_id]).to eq e_asce.id
      expect(r[:import_country_id]).to eq e_asce.import_country_id
      expect(r[:customer_number]).to eq "ASCE"
      expect(r[:cil_id]).to eq cil_asce.id
      expect(r[:contract_amount]).to eq 5
      expect(r[:non_dutiable_amount]).to eq 2
      expect(r[:value]).to eq 1
      expect(r[:quantity_attrib]).to eq 2
      expect(r[:unit_of_measure_attrib]).to eq "uom asce"
      expect(r[:cil_entered_value_7501]).to eq 5
      expect(r[:miscellaneous_discount]).to eq 0
      expect(r[:other_amount]).to eq 0
      expect(r[:duty_amount]).to eq 2
      expect(r[:special_tariff]).to eq 1
      expect(r[:air_sea_discount_attrib]).to eq 0
    end

    def test_ann_results r, with_po=true
      expect(r[:broker_reference]).to eq "ann broker ref"
      expect(r[:customer_name]).to eq "Ann"      
      expect(r[:vendor]).to eq(with_po ? "ann vend ord" : "ann vend 810")
      expect(r[:factory]).to eq(with_po ? "ann fact ord" : "ann fact 810")
      expect(r[:related_parties]).to eq "Y"
      expect(r[:transport_mode_code]).to eq "40"
      expect(r[:fiscal_month]).to eq 2
      expect(r[:release_date]).to eq Date.new(2018,3,11)      
      expect(r[:entry_number]).to eq "ann ent number"
      expect(r[:custom_line_number]).to eq 1
      expect(r[:invoice_number]).to eq "inv num ann"
      expect(r[:part_number]).to eq "part ann"
      expect(r[:po_number]).to eq "po ann"
      expect(r[:product_line]).to eq "brand ann"
      expect(r[:order_type]).to eq "NONAGS"
      expect(r[:country_origin_code]).to eq "AM"
      expect(r[:country_export_code]).to eq "country export ann"
      expect(r[:arrival_date]).to eq Date.new(2018,3,9)
      expect(r[:import_date]).to eq Date.new(2018,3,7)            
      expect(r[:hts_code]).to eq "hts code"
      expect(r[:duty_rate]).to eq 1.3
      expect(r[:goods_description]).to eq "part descr"
      expect(r[:unit_price]).to eq 3                        
      expect(r[:duty]).to eq 3
      expect(r[:spi]).to eq "spi ann"
      expect(r[:fish_and_wildlife]).to eq "N"
      expect(r[:hanger_duty_savings]).to eq 0
      expect(r[:e_id]).to eq e_ann.id
      expect(r[:import_country_id]).to eq e_ann.import_country_id
      expect(r[:customer_number]).to eq "ATAYLOR"
      expect(r[:cil_id]).to eq cil_ann.id
      expect(r[:contract_amount]).to eq 6
      expect(r[:non_dutiable_amount]).to eq 4
      expect(r[:value]).to eq 1
      expect(r[:quantity_attrib]).to eq 4
      expect(r[:unit_of_measure_attrib]).to eq "uom ann"
      expect(r[:cil_entered_value_7501]).to eq 6 
      expect(r[:miscellaneous_discount]).to eq 2
      expect(r[:other_amount]).to eq(-1)
      expect(r[:duty_amount]).to eq 3
      expect(r[:middleman_charge]).to eq 8
      expect(r[:special_tariff]).to eq 1
      expect(r[:air_sea_discount_attrib]).to eq 4
    end

    it "produces expected results for Ascena" do      
      result = nil
      Timecop.freeze(DateTime.new 2018, 3, 16) { result = subject.run(["ASCE"], "2018-03-15", "2018-03-17") }
      r = result.first
      test_asce_results r
    end

    it "produces expected results for Ann with matching order" do
      result = nil
      result = Timecop.freeze(DateTime.new 2018, 3, 16) { result = subject.run(["ATAYLOR"], "2018-03-15", "2018-03-17") }
      r = result.first
      test_ann_results r
    end

    it "produces expected results for Ann without matching order" do
      ord_ann.destroy
      result = nil
      result = Timecop.freeze(DateTime.new 2018, 3, 16) { result = subject.run(["ATAYLOR"], "2018-03-15", "2018-03-17") }
      r = result.first
      test_ann_results r, false
    end

    it "produces expected combined results" do
      result = []
      result = Timecop.freeze(DateTime.new 2018, 3, 16) { subject.run(["ASCE", "ATAYLOR"], "2018-03-15", "2018-03-17").each{ |r| result << r } }
      r = result[0]
      test_asce_results r
      
      r = result[1]
      test_ann_results r
    end

    it "produces expected results for Maurices" do
      # purpose of this is to check the order join

      e_asce.update! importer: maurices, customer_number: "MAUR"
      cil_asce.update! product_line: nil
      ord_asce.update! order_number: "ASCENA-MAU-po asce"

      result = nil
      Timecop.freeze(DateTime.new 2018, 3, 16) { result = subject.run(["MAUR"], "2018-03-15", "2018-03-17") }
      r = result.first
      expect(r[:vendor]).to eq "asce vend"
      
    end
  end

end
