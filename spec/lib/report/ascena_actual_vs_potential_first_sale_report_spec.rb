describe OpenChain::Report::AscenaActualVsPotentialFirstSaleReport do
  let(:report) { described_class.new }

  describe "permission?" do
    let (:ascena) { create(:importer, system_code: "ASCENA") }

    before(:each) do
      ascena
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return "www-vfitrack-net"
    end

    it "allows access for master users who can view entries" do
      u = create(:master_user)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "allows access for Ascena users who can view entries" do
      u = create(:user, company: ascena)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "allows access for users of Ascena's parent companies" do
      parent = create(:company, linked_companies: [ascena])
      u = create(:user, company: parent)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "prevents access by other companies" do
      u = create(:user)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq false
    end

    it "prevents access by users who can't view entries" do
      u = create(:master_user)
      expect(u).to receive(:view_entries?).and_return false
      expect(described_class.permission? u).to eq false
    end
  end

  describe "run_schedulable" do
    def create_data
      agent_cdef = described_class.prep_custom_definitions([:ord_selling_agent])[:ord_selling_agent]
      co = create(:company, system_code: "ASCENA")
      fact1 = create(:company, name: "fact1")
      fact2 = create(:company, name: "fact2")
      DataCrossReference.create!(cross_reference_type: 'asce_mid', key: 'mid1-vendorId1')
      DataCrossReference.create!(cross_reference_type: 'asce_mid', key: 'mid2-vendorId2')
      fm_year_start = create(:fiscal_month, company: co, year: 2016, month_number: 1, start_date: '2016-01-01', end_date: '2016-01-31')
      fm_season_start = create(:fiscal_month, company: co, year: 2016, month_number: 7, start_date: '2016-07-01', end_date: '2016-07-31')
      fm_previous = create(:fiscal_month, company: co, year: 2016, month_number: 8, start_date: '2016-08-01', end_date: '2016-08-31')
      fm_current = create(:fiscal_month, company: co, year: 2016, month_number: 9, start_date: '2016-09-01', end_date: '2016-09-30')

      # ELIGIBLE (contract_amount > 0)
      vend1 = create(:company, name: "vend1")
      vend2 = create(:company, name: "vend2")

      # FIRST SALE

      # previous month
      ent1 = create(:entry, customer_number: 'ASCE', fiscal_date: '2016-08-04', fiscal_month: 9, fiscal_year: 2016)
      ci1 = create(:commercial_invoice, entry: ent1, invoice_value: 20)
      cil1_1 = create(:commercial_invoice_line, commercial_invoice: ci1, po_number: 'po num1_1', contract_amount: 10, value: 8, mid: 'mid1')
      cil1_2 = create(:commercial_invoice_line, commercial_invoice: ci1, po_number: 'po num1_2', contract_amount: 9, value: 6, mid: 'mid1')
      cil1_3 = create(:commercial_invoice_line, commercial_invoice: ci1, po_number: 'po num1_3', contract_amount: 8, value: 5, mid: 'mid2')
      create(:commercial_invoice_tariff, commercial_invoice_line: cil1_1, duty_amount: 3, entered_value: 5)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil1_2, duty_amount: 5, entered_value: 10)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil1_3, duty_amount: 2, entered_value: 6)
      create(:order, order_number: 'ASCENA-po num1_1', vendor: vend1, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num1_2', vendor: vend1, factory: fact2).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num1_3', vendor: vend2, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      # season
      ent2 = create(:entry, customer_number: 'ASCE', fiscal_date: '2016-07-04', fiscal_month: 9, fiscal_year: 2016)
      ci2 = create(:commercial_invoice, entry: ent2, invoice_value: 20)
      cil2_1 = create(:commercial_invoice_line, commercial_invoice: ci2, po_number: 'po num2_1', contract_amount: 10, value: 8, mid: 'mid1')
      cil2_2 = create(:commercial_invoice_line, commercial_invoice: ci2, po_number: 'po num2_2', contract_amount: 9, value: 6, mid: 'mid1')
      cil2_3 = create(:commercial_invoice_line, commercial_invoice: ci2, po_number: 'po num2_3', contract_amount: 8, value: 5, mid: 'mid2')
      create(:commercial_invoice_tariff, commercial_invoice_line: cil2_1, duty_amount: 3, entered_value: 5)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil2_2, duty_amount: 5, entered_value: 10)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil2_3, duty_amount: 2, entered_value: 6)
      create(:order, order_number: 'ASCENA-po num2_1', vendor: vend1, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num2_2', vendor: vend1, factory: fact2).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num2_3', vendor: vend2, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      # ytd
      ent3 = create(:entry, customer_number: 'ASCE', fiscal_date: '2016-01-04', fiscal_month: 9, fiscal_year: 2016)
      ci3 = create(:commercial_invoice, entry: ent3, invoice_value: 20)
      cil3_1 = create(:commercial_invoice_line, commercial_invoice: ci3, po_number: 'po num3_1', contract_amount: 10, value: 8, mid: 'mid1')
      cil3_2 = create(:commercial_invoice_line, commercial_invoice: ci3, po_number: 'po num3_2', contract_amount: 9, value: 6, mid: 'mid1')
      cil3_3 = create(:commercial_invoice_line, commercial_invoice: ci3, po_number: 'po num3_3', contract_amount: 8, value: 5, mid: 'mid2')
      create(:commercial_invoice_tariff, commercial_invoice_line: cil3_1, duty_amount: 3, entered_value: 5)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil3_2, duty_amount: 5, entered_value: 10)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil3_3, duty_amount: 2, entered_value: 6)
      create(:order, order_number: 'ASCENA-po num3_1', vendor: vend1, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num3_2', vendor: vend1, factory: fact2).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num3_3', vendor: vend2, factory: fact1).update_custom_value!(agent_cdef, 'agent')

      # MISSED SAVINGS (contract_amount = 0)

      # previous month
      ent4 = create(:entry, customer_number: 'ASCE', fiscal_date: '2016-08-04', fiscal_month: 9, fiscal_year: 2016)
      ci4 = create(:commercial_invoice, entry: ent4, invoice_value: 20)
      cil4_1 = create(:commercial_invoice_line, commercial_invoice: ci4, po_number: 'po num4_1', contract_amount: 0, value: 8, mid: 'mid1')
      cil4_2 = create(:commercial_invoice_line, commercial_invoice: ci4, po_number: 'po num4_2', contract_amount: 0, value: 6, mid: 'mid1')
      cil4_3 = create(:commercial_invoice_line, commercial_invoice: ci4, po_number: 'po num4_3', contract_amount: 0, value: 5, mid: 'mid2')
      create(:commercial_invoice_tariff, commercial_invoice_line: cil4_1, duty_amount: 3, duty_rate: 2, entered_value: 5)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil4_2, duty_amount: 5, duty_rate: 3, entered_value: 10)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil4_3, duty_amount: 2, duty_rate: 4, entered_value: 6)
      create(:order, order_number: 'ASCENA-po num4_1', vendor: vend1, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num4_2', vendor: vend1, factory: fact2).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num4_3', vendor: vend2, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      # season
      ent5 = create(:entry, customer_number: 'ASCE', fiscal_date: '2016-07-04', fiscal_month: 9, fiscal_year: 2016)
      ci5 = create(:commercial_invoice, entry: ent5, invoice_value: 20)
      cil5_1 = create(:commercial_invoice_line, commercial_invoice: ci5, po_number: 'po num5_1', contract_amount: 0, value: 8, mid: 'mid1')
      cil5_2 = create(:commercial_invoice_line, commercial_invoice: ci5, po_number: 'po num5_2', contract_amount: 0, value: 6, mid: 'mid1')
      cil5_3 = create(:commercial_invoice_line, commercial_invoice: ci5, po_number: 'po num5_3', contract_amount: 0, value: 5, mid: 'mid2')
      create(:commercial_invoice_tariff, commercial_invoice_line: cil5_1, duty_amount: 3, duty_rate: 2, entered_value: 5)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil5_2, duty_amount: 5, duty_rate: 3, entered_value: 10)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil5_3, duty_amount: 2, duty_rate: 4, entered_value: 6)
      create(:order, order_number: 'ASCENA-po num5_1', vendor: vend1, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num5_2', vendor: vend1, factory: fact2).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num5_3', vendor: vend2, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      # ytd
      ent6 = create(:entry, customer_number: 'ASCE', fiscal_date: '2016-01-04', fiscal_month: 9, fiscal_year: 2016)
      ci6 = create(:commercial_invoice, entry: ent6, invoice_value: 20)
      cil6_1 = create(:commercial_invoice_line, commercial_invoice: ci6, po_number: 'po num6_1', contract_amount: 0, value: 8, mid: 'mid1')
      cil6_2 = create(:commercial_invoice_line, commercial_invoice: ci6, po_number: 'po num6_2', contract_amount: 0, value: 6, mid: 'mid1')
      cil6_3 = create(:commercial_invoice_line, commercial_invoice: ci6, po_number: 'po num6_3', contract_amount: 0, value: 5, mid: 'mid2')
      create(:commercial_invoice_tariff, commercial_invoice_line: cil6_1, duty_amount: 3, duty_rate: 2, entered_value: 5)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil6_2, duty_amount: 5, duty_rate: 3, entered_value: 10)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil6_3, duty_amount: 2, duty_rate: 4, entered_value: 6)
      create(:order, order_number: 'ASCENA-po num6_1', vendor: vend1, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num6_2', vendor: vend1, factory: fact2).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num6_3', vendor: vend2, factory: fact1).update_custom_value!(agent_cdef, 'agent')

      # INELIGIBLE
      vend3 = create(:company, name: "vend3")
      vend4 = create(:company, name: "vend4")

      # POTENTIAL SAVINGS (contract_amount = 0)

      # previous month
      ent7 = create(:entry, customer_number: 'ASCE', fiscal_date: '2016-08-04', fiscal_month: 9, fiscal_year: 2016)
      ci7 = create(:commercial_invoice, entry: ent7, invoice_value: 20)
      cil7_1 = create(:commercial_invoice_line, commercial_invoice: ci7, po_number: 'po num7_1', contract_amount: 0, value: 8, mid: 'mid3')
      cil7_2 = create(:commercial_invoice_line, commercial_invoice: ci7, po_number: 'po num7_2', contract_amount: 0, value: 6, mid: 'mid3')
      cil7_3 = create(:commercial_invoice_line, commercial_invoice: ci7, po_number: 'po num7_3', contract_amount: 0, value: 5, mid: 'mid4')
      create(:commercial_invoice_tariff, commercial_invoice_line: cil7_1, duty_amount: 3, duty_rate: 2, entered_value: 5)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil7_2, duty_amount: 5, duty_rate: 3, entered_value: 10)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil7_3, duty_amount: 2, duty_rate: 4, entered_value: 6)
      create(:order, order_number: 'ASCENA-po num7_1', vendor: vend3, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num7_2', vendor: vend3, factory: fact2).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num7_3', vendor: vend4, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      # season
      ent8 = create(:entry, customer_number: 'ASCE', fiscal_date: '2016-07-04', fiscal_month: 9, fiscal_year: 2016)
      ci8 = create(:commercial_invoice, entry: ent8, invoice_value: 20)
      cil8_1 = create(:commercial_invoice_line, commercial_invoice: ci8, po_number: 'po num8_1', contract_amount: 0, value: 8, mid: 'mid3')
      cil8_2 = create(:commercial_invoice_line, commercial_invoice: ci8, po_number: 'po num8_2', contract_amount: 0, value: 6, mid: 'mid3')
      cil8_3 = create(:commercial_invoice_line, commercial_invoice: ci8, po_number: 'po num8_3', contract_amount: 0, value: 5, mid: 'mid4')
      create(:commercial_invoice_tariff, commercial_invoice_line: cil8_1, duty_amount: 3, duty_rate: 2, entered_value: 5)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil8_2, duty_amount: 5, duty_rate: 3, entered_value: 10)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil8_3, duty_amount: 2, duty_rate: 4, entered_value: 6)
      create(:order, order_number: 'ASCENA-po num8_1', vendor: vend3, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num8_2', vendor: vend3, factory: fact2).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num8_3', vendor: vend4, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      # ytd
      ent9 = create(:entry, customer_number: 'ASCE', fiscal_date: '2016-01-04', fiscal_month: 9, fiscal_year: 2016)
      ci9 = create(:commercial_invoice, entry: ent9, invoice_value: 20)
      cil9_1 = create(:commercial_invoice_line, commercial_invoice: ci9, po_number: 'po num9_1', contract_amount: 0, value: 8, mid: 'mid3')
      cil9_2 = create(:commercial_invoice_line, commercial_invoice: ci9, po_number: 'po num9_2', contract_amount: 0, value: 6, mid: 'mid3')
      cil9_3 = create(:commercial_invoice_line, commercial_invoice: ci9, po_number: 'po num9_3', contract_amount: 0, value: 5, mid: 'mid4')
      create(:commercial_invoice_tariff, commercial_invoice_line: cil9_1, duty_amount: 3, duty_rate: 2, entered_value: 5)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil9_2, duty_amount: 5, duty_rate: 3, entered_value: 10)
      create(:commercial_invoice_tariff, commercial_invoice_line: cil9_3, duty_amount: 2, duty_rate: 4, entered_value: 6)
      create(:order, order_number: 'ASCENA-po num9_1', vendor: vend3, factory: fact1).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num9_2', vendor: vend3, factory: fact2).update_custom_value!(agent_cdef, 'agent')
      create(:order, order_number: 'ASCENA-po num9_3', vendor: vend4, factory: fact1).update_custom_value!(agent_cdef, 'agent')
    end

    it "emailed attachment has correct data" do
      create_data
      Timecop.freeze(DateTime.new(2016, 9, 4, 12)) { described_class.run_schedulable({'email' => ['test@vandegriftinc.com'], 'company' => 'ASCENA', 'fiscal_day' => 4}) }
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq [ "test@vandegriftinc.com" ]
      expect(mail.subject).to eq "Actual vs Potential First Sale Report"
      expect(mail.attachments.count).to eq 1
      Tempfile.open('attachment') do |t|
        t.binmode
        t << mail.attachments.first.read
        t.flush
        wb = Spreadsheet.open t.path

        sheet_1 = wb.worksheet(0)
        expect(sheet_1.row(1)).to eq ["First Sale Eligible Vendors Claiming First Sale at Entry"]
        expect(sheet_1.row(2)).to eq ['Vendor', 'Seller', 'create', 'Previous Fiscal Month Duty Savings', 'Fiscal Season to Date Savings', 'Fiscal YTD Savings']
        expect(sheet_1.row(3)).to eq ['vend1', 'agent', 'fact1', 1.20, 2.40, 3.60]
        expect(sheet_1.row(4)).to eq ['vend1', 'agent', 'fact2', 1.50, 3.00, 4.50]
        expect(sheet_1.row(5)).to eq [nil, nil, nil, 2.70, 5.40, 8.10, 'vend1 Subtotal']
        expect(sheet_1.row(6)).to eq ['vend2', 'agent', 'fact1', 1.00, 2.00, 3.00]
        expect(sheet_1.row(7)).to eq [nil, nil, nil, 1.00, 2.00, 3.00, 'vend2 Subtotal']

        expect(sheet_1.row(9)).to eq [nil, nil, nil, 3.70, 7.40, 11.10, 'Total']

        expect(sheet_1.row(11)).to eq ['First Sale Eligible Vendors Not Claiming First Sale at Entry']
        expect(sheet_1.row(12)).to eq [nil, '29.63%', 'Previous Fiscal Period Average Vendor Margin']
        expect(sheet_1.row(13)).to eq [nil, '29.63%', 'Fiscal Season Average Vendor Margin']
        expect(sheet_1.row(14)).to eq [nil, '29.63%', 'Fiscal YTD Average Vendor Margin']

        expect(sheet_1.row(16)).to eq ['Vendor', 'Seller', 'create', 'Previous Fiscal Month Missed Duty Savings', 'Fiscal Season to Date Missed Savings', 'Fiscal YTD Missed Savings']
        expect(sheet_1.row(17)).to eq ['vend1', 'agent', 'fact1', 4.74, 9.48, 14.22]
        expect(sheet_1.row(18)).to eq ['vend1', 'agent', 'fact2', 5.33, 10.67, 16.00]
        expect(sheet_1.row(19)).to eq [nil, nil, nil, 10.07, 20.15, 30.22, 'vend1 Subtotal']
        expect(sheet_1.row(20)).to eq ['vend2', 'agent', 'fact1', 5.93, 11.85, 17.78]
        expect(sheet_1.row(21)).to eq [nil, nil, nil, 5.93, 11.85, 17.78, 'vend2 Subtotal']

        expect(sheet_1.row(23)).to eq [nil, nil, nil, 16.00, 32.00, 48.00, 'Total']

        expect(sheet_1.row(25)).to eq ['First Sale Ineligible Vendors Potential Duty Savings']
        expect(sheet_1.row(26)).to eq [nil, '29.63%', 'Previous Fiscal Period Average Vendor Margin']
        expect(sheet_1.row(27)).to eq [nil, '29.63%', 'Fiscal Season Average Vendor Margin']
        expect(sheet_1.row(28)).to eq [nil, '29.63%', 'Fiscal YTD Average Vendor Margin']

        expect(sheet_1.row(30)).to eq ['Vendor', 'Seller', 'create', 'Previous Fiscal Month Potential Duty Savings', 'Fiscal Season to Date Potential Savings', 'Fiscal YTD Potential Savings']
        expect(sheet_1.row(31)).to eq ['vend3', 'agent', 'fact1', 4.74, 9.48, 14.22]
        expect(sheet_1.row(32)).to eq ['vend3', 'agent', 'fact2', 5.33, 10.67, 16.00]
        expect(sheet_1.row(33)).to eq [nil, nil, nil, 10.07, 20.15, 30.22, 'vend3 Subtotal']
        expect(sheet_1.row(34)).to eq ['vend4', 'agent', 'fact1', 5.93, 11.85, 17.78]
        expect(sheet_1.row(35)).to eq [nil, nil, nil, 5.93, 11.85, 17.78, 'vend4 Subtotal']

        expect(sheet_1.row(37)).to eq [nil, nil, nil, 16.00, 32.00, 48.00, 'Total']

        detail_header_savings = ['Entry Number', 'Entry Filed Date', 'Entry First Release Date', 'Fiscal Month', 'AGS Office', 'Vendor Name', 'MID Supplier Name', 'MID',
                                 'Invoice Value - Brand', 'COO', 'Style Number', 'PO Number', 'Invoice Number', 'Quantity', 'Unit Price',
                                 'Invoice Tariff - Duty Rate', 'Invoice Tariff - Duty', 'Invoice Value - Contract', 'Unit Price - 7501',
                                 'Invoice Value - 7501', 'Value Reduction', 'Vendor Margin', 'Invoice Line - First Sale Savings', 'First Sale Flag']

        detail_header_missed_potential = ['Entry Number', 'Entry Filed Date', 'Entry First Release Date', 'Fiscal Month', 'AGS Office', 'Vendor Name', 'MID Supplier Name', 'MID',
                                          'Invoice Value - Brand', 'COO', 'Style Number', 'PO Number', 'Invoice Number', 'Quantity', 'Unit Price', 'Invoice Tariff - Duty Rate',
                                          'Invoice Tariff - Duty', 'Invoice Value - Contract', 'Unit Price - 7501', 'Invoice Value - 7501', 'First Sale Flag']

        sheet_2 = wb.worksheet(1)
        expect(sheet_2.rows.count).to eq 4
        expect(sheet_2.row(0)).to eq detail_header_savings

        sheet_3 = wb.worksheet(2)
        expect(sheet_3.rows.count).to eq 4
        expect(sheet_3.row(0)).to eq detail_header_missed_potential

        sheet_4 = wb.worksheet(3)
        expect(sheet_4.rows.count).to eq 4
        expect(sheet_4.row(0)).to eq detail_header_missed_potential
      end
    end
  end


  describe "QueryConverter" do
    let(:converter) { described_class::QueryConverter }

    describe "split_results" do
      it "splits query results with block" do
        query_results = {previous_fiscal_month: [{'vendor' => 'ACME', 'seller' => 'Smith', 'factory' => 'Smoky', 'first_sale_flag' => 'Y'},
                                                 {'vendor' => 'ACME', 'seller' => 'Jones', 'factory' => 'Smoky', 'first_sale_flag' => 'N'}],
                         fiscal_season_to_date: [{'vendor' => 'ACME', 'seller' => 'Smith', 'factory' => 'Smoky', 'first_sale_flag' => 'N'},
                                                 {'vendor' => 'ACME', 'seller' => 'Brown', 'factory' => 'Dirty', 'first_sale_flag' => 'Y'}],
                         fiscal_ytd: [{'vendor' => 'Konvenientz', 'seller' => 'Smith', 'factory' => 'Dirty', 'first_sale_flag' => 'N'}]}
        first_sale, missed = converter.split_results(query_results) { |rs| converter.first_sale_partition rs }

        expect(first_sale[:previous_fiscal_month]).to eq([{'vendor' => 'ACME', 'seller' => 'Smith', 'factory' => 'Smoky', 'first_sale_flag' => 'Y'}])
        expect(first_sale[:fiscal_season_to_date]).to eq([{'vendor' => 'ACME', 'seller' => 'Brown', 'factory' => 'Dirty', 'first_sale_flag' => 'Y'}])
        expect(first_sale[:fiscal_ytd]).to be_empty

        expect(missed[:previous_fiscal_month]).to eq([{'vendor' => 'ACME', 'seller' => 'Jones', 'factory' => 'Smoky', 'first_sale_flag' => 'N'}])
        expect(missed[:fiscal_season_to_date]).to eq([{'vendor' => 'ACME', 'seller' => 'Smith', 'factory' => 'Smoky', 'first_sale_flag' => 'N'}])
        expect(missed[:fiscal_ytd]).to eq([{'vendor' => 'Konvenientz', 'seller' => 'Smith', 'factory' => 'Dirty', 'first_sale_flag' => 'N'}])
      end
    end

    describe "convert_first_sale_results" do
      it "converts and returns results for the three fiscal periods, along with combined vendor/seller/factory triplets" do
        prev_month_result = double "prev month result"
        season_result = double "fiscal season result"
        ytd_result = double "fiscal ytd result"

        prev_month_hsh = double "prev month hsh"
        expect(prev_month_hsh).to receive(:[]).with(:triplets).and_return([['a', 'b', 'c'], ['a', 'b', 'd']])
        season_hsh = double "season hsh"
        expect(season_hsh).to receive(:[]).with(:triplets).and_return([['a', 'b', 'c'], ['a', 'c', 'd']])
        ytd_hsh = double "ytd hsh"
        expect(ytd_hsh).to receive(:[]).with(:triplets).and_return([['d', 'e', 'f']])

        expect(converter).to receive(:convert_one_first_sale_result).with(prev_month_result).and_return prev_month_hsh
        expect(converter).to receive(:convert_one_first_sale_result).with(season_result).and_return season_hsh
        expect(converter).to receive(:convert_one_first_sale_result).with(ytd_result).and_return ytd_hsh

        results = {previous_fiscal_month: prev_month_result, fiscal_season_to_date: season_result, fiscal_ytd: ytd_result}
        expect(converter.convert_first_sale_results results).to eq({previous_fiscal_month: prev_month_hsh,
                                                                    fiscal_season_to_date: season_hsh,
                                                                    fiscal_ytd: ytd_hsh,
                                                                    triplets: {'a' => [['b', 'c'], ['b', 'd'], ['c', 'd']], 'd' => [['e', 'f']]}})

      end
    end

    describe "convert_missed_or_potential_results" do
      it "converts and returns results for the three fiscal periods, along with combined vendor/seller/factory triplets" do
        prev_month_result = double "prev month result"
        season_result = double "fiscal season result"
        ytd_result = double "fiscal ytd result"

        prev_month_hsh = double "prev month hsh"
        expect(prev_month_hsh).to receive(:[]).with(:triplets).and_return([['a', 'b', 'c'], ['a', 'b', 'd']])
        season_hsh = double "season hsh"
        expect(season_hsh).to receive(:[]).with(:triplets).and_return([['a', 'b', 'c'], ['a', 'c', 'd']])
        ytd_hsh = double "ytd hsh"
        expect(ytd_hsh).to receive(:[]).with(:triplets).and_return([['d', 'e', 'f']])
        percs_hsh = {previous_fiscal_month: 0.3, fiscal_season_to_date: 0.5, fiscal_ytd: 0.7}

        expect(converter).to receive(:convert_one_missed_or_potential_result).with(prev_month_result, 0.3).and_return prev_month_hsh
        expect(converter).to receive(:convert_one_missed_or_potential_result).with(season_result, 0.5).and_return season_hsh
        expect(converter).to receive(:convert_one_missed_or_potential_result).with(ytd_result, 0.7).and_return ytd_hsh

        results = {previous_fiscal_month: prev_month_result, fiscal_season_to_date: season_result, fiscal_ytd: ytd_result}
        expect(converter.convert_missed_or_potential_results results, percs_hsh).to eq({previous_fiscal_month: prev_month_hsh,
                                                                    fiscal_season_to_date: season_hsh,
                                                                    fiscal_ytd: ytd_hsh,
                                                                    triplets: {'a' => [['b', 'c'], ['b', 'd'], ['c', 'd']], 'd' => [['e', 'f']]}})
      end
    end

    context "convert result" do
      let(:query_result) do
        [{'vendor' => 'ACME', 'seller' => 'Smith', 'factory' => 'Smoky', 'first_sale_sav' => BigDecimal(5), 'first_sale_diff' => BigDecimal(2), 'inv_val_contract' => BigDecimal(1), 'val_contract_x_tariff_rate' => BigDecimal(3)},
         {'vendor' => 'ACME', 'seller' => 'Smith', 'factory' => 'Dirty', 'first_sale_sav' => BigDecimal(7), 'first_sale_diff' => BigDecimal(0), 'inv_val_contract' => BigDecimal(2), 'val_contract_x_tariff_rate' => BigDecimal(4)},
         {'vendor' => 'ACME', 'seller' => 'Brown', 'factory' => 'Smoky', 'first_sale_sav' => BigDecimal(3), 'first_sale_diff' => BigDecimal(3), 'inv_val_contract' => BigDecimal(1), 'val_contract_x_tariff_rate' => BigDecimal(5)},
         {'vendor' => 'Konvenientz', 'seller' => 'Smith', 'factory' => 'Smoky', 'first_sale_sav' => BigDecimal(7), 'first_sale_diff' => BigDecimal(1), 'inv_val_contract' => BigDecimal(1), 'val_contract_x_tariff_rate' => BigDecimal(6)}]
      end

      describe "convert_one_first_sale_result" do
        it "returns nested savings hash, vendor-total hash, grand total, and average percentage along with list of vendor/seller/factory triplets" do
           r = converter.convert_one_first_sale_result(query_result)

           expect(r[:lines]).to eq({'ACME'=>{'Smith' => {'Smoky' => 5,
                                                         'Dirty' => 7},
                                             'Brown' => {'Smoky' =>3}},
                                    'Konvenientz'=> {'Smith'=>{'Smoky'=>7}}})
           expect(r[:vendor_total]).to eq({'ACME' => 15, 'Konvenientz' => 7})
           expect(r[:grand_total]).to eq 22
           expect(r[:avg_savings_perc]).to eq 1.2
           expect(r[:triplets]).to eq [['ACME', 'Smith', 'Smoky'], ['ACME', 'Smith', 'Dirty'], ['ACME', 'Brown', 'Smoky'], ['Konvenientz', 'Smith', 'Smoky']]
        end
      end

      describe "convert_one_missed_or_potential_result" do
          it "returns nested missed/potential hash, vendor-total hash, grand total, along with list of vendor/seller/factory triplets" do
            r = converter.convert_one_missed_or_potential_result(query_result, 0.8)
            expect(r[:lines]).to eq({'ACME'=>{'Smith' => {'Smoky' => 2.4,
                                                          'Dirty' => 3.2},
                                              'Brown' => {'Smoky' =>4}},
                                     'Konvenientz'=> {'Smith'=>{'Smoky'=>4.8}}})
            expect(r[:vendor_total]).to eq({'ACME' => 9.6, 'Konvenientz' => 4.8})
            expect(r[:grand_total]).to eq 14.4
            expect(r[:triplets]).to eq [['ACME', 'Smith', 'Smoky'], ['ACME', 'Smith', 'Dirty'], ['ACME', 'Brown', 'Smoky'], ['Konvenientz', 'Smith', 'Smoky']]
          end
      end

    end
  end

  describe "FiscalMonthRange" do
    let!(:co) { create(:company, system_code: "ASCENA") }
    let(:fm_range) { described_class::FiscalMonthRange.new }

    describe "range_for_previous_fiscal_month" do
      it "returns SQL range encompassing previous fiscal month when it falls within current year" do
        create(:fiscal_month, company: co, year: 2018, month_number: 2, start_date: '2017-08-27', end_date: '2017-09-30')
        create(:fiscal_month, company: co, year: 2018, month_number: 3, start_date: '2017-10-01', end_date: '2017-10-28')

        Timecop.freeze(DateTime.new(2017, 10, 10)) do
          expect(fm_range.range_for_previous_fiscal_month).to eq "e.fiscal_date >= '2017-08-27' AND e.fiscal_date < '2017-10-01'"
        end
      end

      it "returns SQL range encompassing previous fiscal month when it falls within previous year" do
        create(:fiscal_month, company: co, year: 2018, month_number: 1, start_date: '2017-07-30', end_date: '2017-08-26')
        create(:fiscal_month, company: co, year: 2017, month_number: 12, start_date: '2017-07-02', end_date: '2017-07-29')

        Timecop.freeze(Date.new(2017, 8, 10)) do
          expect(fm_range.range_for_previous_fiscal_month).to eq "e.fiscal_date >= '2017-07-02' AND e.fiscal_date < '2017-07-30'"
        end
      end
    end

    describe "range_for_fiscal_season_to_date" do
      it "returns SQL range starting from beginning of current fiscal season (mos. 1-6)" do
        create(:fiscal_month, company: co, year: 2017, month_number: 1, start_date: '2016-07-31', end_date: '2016-08-27')
        create(:fiscal_month, company: co, year: 2017, month_number: 5, start_date: '2016-11-27', end_date: '2016-12-31')

        Timecop.freeze(Date.new(2016, 12, 10)) do
          expect(fm_range.range_for_fiscal_season_to_date).to eq "e.fiscal_date >= '2016-07-31' AND e.fiscal_date < '2016-11-27'"
        end
      end

      it "returns SQL range starting from beginning of current fiscal season (mos. 7-12)" do
        create(:fiscal_month, company: co, year: 2017, month_number: 7, start_date: '2017-01-29', end_date: '2017-02-25')
        create(:fiscal_month, company: co, year: 2017, month_number: 12, start_date: '2017-07-02', end_date: '2017-07-29')

        Timecop.freeze(Date.new(2017, 7, 4)) do
          expect(fm_range.range_for_fiscal_season_to_date).to eq "e.fiscal_date >= '2017-01-29' AND e.fiscal_date < '2017-07-02'"
        end
      end
    end

    describe "range_for_fiscal_ytd" do
      it "returns SQL range encompassing fiscal year-to-date" do
        create(:fiscal_month, company: co, year: 2017, month_number: 1, start_date: '2016-07-31', end_date: '2016-08-27')
        create(:fiscal_month, company: co, year: 2017, month_number: 12, start_date: '2017-07-02', end_date: '2017-07-29')

        Timecop.freeze(Date.new(2017, 7, 04)) do
          expect(fm_range.range_for_fiscal_ytd).to eq "e.fiscal_date >= '2016-07-31' AND e.fiscal_date < '2017-07-02'"
        end
      end
    end

  end


  describe "SharedSql" do
    class Report
      include OpenChain::Report::AscenaActualVsPotentialFirstSaleReport::SharedSql
    end

    describe "first_sale_savings" do
      before do
        rep = Report.new
        @cil = create(:commercial_invoice_line, contract_amount: 10.5, value: 7)
        create(:commercial_invoice_tariff, commercial_invoice_line: @cil, duty_amount: 4.5, entered_value: 8)
        create(:commercial_invoice_tariff, commercial_invoice_line: @cil, duty_amount: 3, entered_value: 6)

        @qry = <<-SQL
                SELECT #{rep.first_sale_savings('cil')}
                FROM entries e
                  INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
                  INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
                  INNER JOIN commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
               SQL
      end

      it "returns 0 if contract_amount is NULL" do
        @cil.update_attributes(contract_amount: 0)
        result = []
        ActiveRecord::Base.connection.execute(@qry).each { |r| result << r }
        expect(result[0].first).to eq 0
        expect(result[1].first).to eq 0
      end

      it "returns 0 if contract_amount is 0" do
        @cil.update_attributes(contract_amount: nil)
        result = []
        ActiveRecord::Base.connection.execute(@qry).each { |r| result << r }
        expect(result[0].first).to eq 0
        expect(result[1].first).to eq 0
      end

      it "returns expected result if contract_amount isn't 0 or NULL" do
        result = ActiveRecord::Base.connection.execute @qry
        result = []
        ActiveRecord::Base.connection.execute(@qry).each { |r| result << r }
        expect(result[0].first).to eq 1.97
        expect(result[1].first).to eq 1.97
      end
    end

    describe "first_sale_difference" do
      before do
        rep = Report.new
        @cil = create(:commercial_invoice_line, contract_amount: 10, value: 5.156)
        create(:commercial_invoice_tariff, commercial_invoice_line: @cil)

        @qry = <<-SQL
                SELECT #{rep.first_sale_difference('cil')}
                FROM entries e
                  INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
                  INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
                  INNER JOIN commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
               SQL
      end

      it "returns 0 if contract_amount is 0" do
        @cil.update_attributes(contract_amount: 0)
        result = ActiveRecord::Base.connection.execute @qry
        expect(result.first[0]).to eq 0
      end

      it "returns 0 if contract_amount is NULL" do
        @cil.update_attributes(contract_amount: nil)
        result = ActiveRecord::Base.connection.execute @qry
        expect(result.first[0]).to eq 0
      end

      it "returns the difference of the contract amount and the invoice value if contract_amount isn't 0 or NULL" do
        result = ActiveRecord::Base.connection.execute @qry
        expect(result.first[0]).to eq 4.84
      end
    end

  end


  describe "SavingsQueryRunner" do
    let(:runner) { described_class::SavingsQueryRunner }

    describe "savings_query" do
      before do
        @cdefs = described_class.prep_custom_definitions [:ord_selling_agent]
        vendor = create(:company, name: "vend")
        factory = create(:company, name: "fact")
        o = create(:order, order_number: "ASCENA-po num", vendor: vendor, factory: factory)
        o.update_custom_value!(@cdefs[:ord_selling_agent], 'agent')
        ent = create(:entry, customer_number: 'ASCE')
        ci = create(:commercial_invoice, entry: ent)
        cil1 = create(:commercial_invoice_line, commercial_invoice: ci, po_number: "po num", contract_amount: 10, value: 7, mid: "MID")
        cil2 = create(:commercial_invoice_line, commercial_invoice: ci, po_number: "po num", contract_amount: 9, value: 5, mid: "MID")
        create(:commercial_invoice_tariff, commercial_invoice_line: cil1, duty_amount: 4.5, duty_rate: 0.2, entered_value: 8)
        create(:commercial_invoice_tariff, commercial_invoice_line: cil2, duty_amount: 3, duty_rate: 0.4, entered_value: 6)
      end

      it "returns expected result" do
        results = ActiveRecord::Base.connection.execute runner.savings_query(@cdefs, "1=1")
        expect(results.count).to eq 1
        expect(results.fields).to eq ['vendor', 'mid', 'seller', 'factory', 'first_sale_flag', 'first_sale_sav', 'first_sale_diff', 'inv_val_contract', 'val_contract_x_tariff_rate']
        expect(results.first).to eq ['vend', 'MID', 'agent', 'fact', 'Y', 3.69, 7, 19, 5.6]
      end
    end

  end


  describe "DetailQueryGenerator" do
    let(:generator) { described_class::DetailQueryGenerator }

    describe "get_detail_queries" do
      it "returns results of detail queries for first sale savings, missed savings, and potential savings" do
        cdefs = double "cdefs"
        fm_range = double "FiscalMonthRange"
        eligible_mids = ["1234", "5678", "9012"]
        first_sale = double "first sale"
        missed = double "missed savings"
        potential = double "potential savings"

        expect(generator).to receive(:detail_query).with(cdefs, fm_range, true, "cil.mid IN ('1234','5678','9012') AND cil.contract_amount > 0").and_return first_sale
        expect(generator).to receive(:detail_query).with(cdefs, fm_range, false, "cil.mid IN ('1234','5678','9012') AND cil.contract_amount <= 0").and_return missed
        expect(generator).to receive(:detail_query).with(cdefs, fm_range, false, "(cil.mid NOT IN ('1234','5678','9012') OR cil.mid IS NULL)").and_return potential

        expect(generator.get_detail_queries cdefs, eligible_mids, fm_range).to eq({first_sale: first_sale, missed: missed, potential: potential})
      end
    end

    describe "detail_query" do

      before do
        create(:company, system_code: "ASCENA")
        @cdefs = described_class.prep_custom_definitions [:ord_type, :ord_selling_agent, :prod_vendor_style, :ord_line_wholesale_unit_price, :prod_reference_number]
        vendor = create(:company, name: 'vend')
        factory = create(:company, name: 'fact')
        @ent = create(:entry, customer_number: 'ASCE', entry_number: 'ent num', entry_filed_date: '2016-01-01', first_release_date: '2016-02-01', fiscal_month: 1)
        ci = create(:commercial_invoice, entry: @ent, invoice_number: 'inv num', invoice_value: 3)
        @cil = create(:commercial_invoice_line, commercial_invoice: ci, mid: 'cil mid', country_origin_code: 'coo', po_number: 'po num', part_number: 'part num', quantity: 6, unit_price: 2, contract_amount: 4, value: 8)
        create(:commercial_invoice_tariff, commercial_invoice_line: @cil, duty_rate: 2, duty_amount: 3, entered_value: 4)
        prod = create(:product, unique_identifier: "ASCENA-part num" )
        prod.update_custom_value!(@cdefs[:prod_vendor_style], 'style')
        @o = create(:order, order_number: "ASCENA-po num", vendor: vendor, factory: factory)
        @o.update_custom_value!(@cdefs[:ord_selling_agent], "agent")
        @o.update_custom_value!(@cdefs[:ord_type], "AGS")
        ol = create(:order_line, order: @o, product: prod)
        ol.update_custom_value!(@cdefs[:ord_line_wholesale_unit_price], 10)

        @fm_range = double "fiscal month range"
        expect(@fm_range).to receive(:range_for_previous_fiscal_month).and_return("1=1")
      end

      it "returns expected result for 'savings' tab" do
        results = ActiveRecord::Base.connection.exec_query generator.detail_query(@cdefs, @fm_range, true, "1=1")
        expect(results.count).to eq 1
        expect(results.columns).to eq ['Entry Number', 'Entry Filed Date', 'Entry First Release Date', 'Fiscal Month', 'AGS Office', 'Vendor Name', 'MID Supplier Name', 'MID',
                                       'Invoice Value - Brand', 'COO', 'Style Number', 'PO Number', 'Invoice Number', 'Quantity', 'Unit Price',
                                       'Invoice Tariff - Duty Rate', 'Invoice Tariff - Duty', 'Invoice Value - Contract', 'Unit Price - 7501',
                                       'Invoice Value - 7501', 'Value Reduction', 'Vendor Margin', 'Invoice Line - First Sale Savings', 'First Sale Flag']

        expect(results.first).to eq({'Entry Number'=> 'ent num', 'Entry Filed Date'=>@ent.entry_filed_date, 'Entry First Release Date'=>@ent.first_release_date,
                                     'Fiscal Month'=> 1, 'AGS Office'=> 'agent', 'Vendor Name'=>'vend', 'MID Supplier Name'=>'fact', 'MID'=>'cil mid',
                                     'Invoice Value - Brand'=>60, 'COO'=>'coo', 'Style Number'=>'style', 'PO Number'=>'po num', 'Invoice Number'=>'inv num',
                                     'Quantity'=>6, 'Unit Price'=>2, 'Invoice Tariff - Duty Rate'=>2, 'Invoice Tariff - Duty'=>3, 'Invoice Value - Contract'=>4,
                                     'Unit Price - 7501'=>BigDecimal(4/3.0, 7), 'Invoice Value - 7501'=>8, 'Value Reduction'=>-4, 'Vendor Margin'=>-1,
                                     'Invoice Line - First Sale Savings'=>-3, 'First Sale Flag'=>'Y'})
      end

      it "returns expected result for 'missed_potential' tabs" do
        results = ActiveRecord::Base.connection.exec_query generator.detail_query(@cdefs, @fm_range, false, "1=1")
        expect(results.count).to eq 1
        expect(results.columns).to eq ['Entry Number', 'Entry Filed Date', 'Entry First Release Date', 'Fiscal Month', 'AGS Office', 'Vendor Name', 'MID Supplier Name', 'MID',
                                       'Invoice Value - Brand', 'COO', 'Style Number', 'PO Number', 'Invoice Number', 'Quantity', 'Unit Price',
                                       'Invoice Tariff - Duty Rate', 'Invoice Tariff - Duty', 'Invoice Value - Contract', 'Unit Price - 7501',
                                       'Invoice Value - 7501', 'First Sale Flag']

        r = results.first
        expect(r).to eq({'Entry Number'=> 'ent num', 'Entry Filed Date'=>@ent.entry_filed_date, 'Entry First Release Date'=>@ent.first_release_date,
                         'Fiscal Month'=> 1, 'AGS Office'=> 'agent', 'Vendor Name'=>'vend', 'MID Supplier Name'=>'fact', 'MID'=>'cil mid',
                         'Invoice Value - Brand'=>60, 'COO'=>'coo', 'Style Number'=>'style', 'PO Number'=>'po num', 'Invoice Number'=>'inv num',
                         'Quantity'=>6, 'Unit Price'=>2, 'Invoice Tariff - Duty Rate'=>2, 'Invoice Tariff - Duty'=>3, 'Invoice Value - Contract'=>4,
                         'Unit Price - 7501'=>BigDecimal(4/3.0, 7), 'Invoice Value - 7501'=>8, 'First Sale Flag'=>'Y'})
      end

      it "returns blank AGS Office if order type is 'NONAGS'" do
        @o.update_custom_value!(@cdefs[:ord_type], "NONAGS")
        results = ActiveRecord::Base.connection.execute generator.detail_query(@cdefs, @fm_range, true, "1=1")
        expect(results.first[4]).to be_blank
      end

      it "return N for First Sale Flag if contract amount is 0 " do
        @cil.update_attributes(contract_amount: 0)
        results = ActiveRecord::Base.connection.execute generator.detail_query(@cdefs, @fm_range, true, "1=1")
        expect(results.first[-1]).to eq "N"
      end

    end
  end


end