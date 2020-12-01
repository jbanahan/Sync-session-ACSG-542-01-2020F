describe CustomReportEntryTariffBreakdown do

  let(:user) { FactoryBot(:master_user) }

  describe "column_fields_available" do
    subject { described_class }

    it "should allow columns for all entry, commercial invoice and commercial invoice line fields" do
      expect(subject.column_fields_available(user)).to eq(CoreModule::ENTRY.model_fields(user).values + CoreModule::COMMERCIAL_INVOICE.model_fields(user).values + CoreModule::COMMERCIAL_INVOICE_LINE.model_fields(user).values)
    end
  end

  describe "criterion_fields_available" do
    it "should allow parameters for all entry, commercial invoice and commercial invoice line fields" do
      expect(subject.criterion_fields_available(user)).to eq(CoreModule::ENTRY.model_fields(user).values)
    end
  end

  describe "can_view?" do
    subject { described_class }

    it "should allow users who can view entries" do
      allow(user).to receive(:view_entries?).and_return true
      expect(subject.can_view?(user)).to be_truthy
    end

    it "should not allow users who cannot view entries" do
      allow(user).to receive(:view_entries?).and_return false
      expect(subject.can_view?(user)).to be_falsey
    end
  end

  describe "run" do
    let! (:country_us) { FactoryBot(:country, iso_code:'US') }

    it "should make a row for each invoice line" do
      OfficialTariff.create!(country_id:country_us.id, hts_code:"1234567890", general_rate:"10%")
      OfficialTariff.create!(country_id:country_us.id, hts_code:"1234567891", general_rate:"15%")
      OfficialTariff.create!(country_id:country_us.id, hts_code:"9902123456", general_rate:"1%") # MTB is generally free, but lets make it 1% to make sure the calculation is correct
      OfficialTariff.create!(country_id:country_us.id, hts_code:"9903123456", general_rate:"25% or 24%") # should pick up 25

      ent_a = FactoryBot(:entry, broker_reference:"ABC")
      invoice_1 = FactoryBot(:commercial_invoice, entry:ent_a, invoice_number:"DEF")
      line_1_1 = FactoryBot(:commercial_invoice_line, commercial_invoice:invoice_1, line_number: 1, part_number:"X")
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_1_1, hts_code:"9903123456", entered_value:100, duty_amount:25)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_1_1, hts_code:"9902123456", duty_amount:1)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_1_1, hts_code:"1234567890", duty_amount: 0)

      line_1_2 = FactoryBot(:commercial_invoice_line, commercial_invoice:invoice_1, line_number: 2, part_number:"Y")
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_1_2, hts_code:"9903123456", entered_value:100, duty_amount:25)
      # Non-special tariff lines won't have duty amounts...special ones will
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_1_2, hts_code:"1234567890", duty_amount: 0)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_1_2, hts_code:"1234567891", duty_amount: 0)

      invoice_2 = FactoryBot(:commercial_invoice, entry:ent_a, invoice_number:"GHI")
      line_2 = FactoryBot(:commercial_invoice_line, commercial_invoice:invoice_2, line_number: 1, part_number:"Z")
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_2, hts_code:"1234567890", entered_value:200, duty_amount:20)

      ent_b = FactoryBot(:entry, broker_reference:"CBA")
      invoice_b = FactoryBot(:commercial_invoice, entry:ent_b, invoice_number:"JKL")
      line_b = FactoryBot(:commercial_invoice_line, commercial_invoice:invoice_b, line_number: 1, part_number:"A")
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_b, hts_code:"1234567891", entered_value:300, duty_amount:45)

      subject.search_columns.build(:rank=>0, :model_field_uid=>:ent_brok_ref)
      subject.search_columns.build(:rank=>1, :model_field_uid=>:ci_invoice_number)
      subject.search_columns.build(:rank=>2, :model_field_uid=>:cil_part_number)
      rows = subject.to_arrays user
      expect(rows.size).to eq(5)
      expect(rows[0]).to eq ["Broker Reference", "Invoice - Invoice Number", "Invoice Line - Part Number",
                             "HTS 1 Underlying Classification", "HTS 1 Underlying Classification Rate",
                             "HTS 1 Underlying Classification Duty", "HTS 2 Underlying Classification",
                             "HTS 2 Underlying Classification Rate", "HTS 2 Underlying Classification Duty",
                             "Est Underlying Classification Duty", "MTB Classification", "MTB Classification Rate",
                             "MTB Classification Duty", "301 Classification", "301 Classification Rate",
                             "301 Classification Duty", "Tariff Entered Value", "Total Duty Paid", "MTB Savings"]
      # This row corresponds to line_1_1
      expect(rows[1]).to eq ["ABC", "DEF", "X", "1234.56.7890", BigDecimal("0.10"), BigDecimal("0"), "", "", "", BigDecimal("10"), "9902.12.3456", BigDecimal("0.01"), BigDecimal("1"), "9903.12.3456", BigDecimal("0.25"), BigDecimal("25"), BigDecimal("100"), BigDecimal("26"), BigDecimal("9")]
      # This row corresponds to line_1_2
      expect(rows[2]).to eq ["ABC", "DEF", "Y", "1234.56.7890", BigDecimal("0.10"), BigDecimal("0"), "1234.56.7891", BigDecimal("0.15"), BigDecimal("0"), BigDecimal("25"), "", "", "", "9903.12.3456", BigDecimal("0.25"), BigDecimal("25"), BigDecimal("100"), BigDecimal("25"), 0]
      # This row corresponds to line_2
      expect(rows[3]).to eq ["ABC", "GHI", "Z", "1234.56.7890", BigDecimal("0.10"), BigDecimal("20"), "", "", "", BigDecimal("20"), "", "", "", "", "", "", BigDecimal("200"), BigDecimal("20"), BigDecimal("0")]
      # This row corresponds to line_b
      expect(rows[4]).to eq ["CBA", "JKL", "A", "1234.56.7891", BigDecimal("0.15"), BigDecimal("45"), "", "", "", BigDecimal("45"), "", "", "", "", "", "", BigDecimal("300"), BigDecimal("45"), BigDecimal("0")]
    end

    it "should limit rows" do
      OfficialTariff.create!(country_id:country_us.id, hts_code:"1234567890", general_rate:"10%")
      OfficialTariff.create!(country_id:country_us.id, hts_code:"9902123456", general_rate:"1%") # MTB is generally free, but lets make it 1% to make sure the calculation is correct

      ent = FactoryBot(:entry, broker_reference:"ABC")
      invoice = FactoryBot(:commercial_invoice, entry:ent, invoice_number:"DEF")
      line_1 = FactoryBot(:commercial_invoice_line, commercial_invoice:invoice, line_number: 1, part_number:"X")
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_1, hts_code:"9902123456", entered_value:100, duty_amount:1)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_1, hts_code:"1234567890", duty_amount: 0)

      # This one should appear on the report, but doesn't because of the row limitation...it needs to be on
      # another invoice because we don't want to cut off mid entry..so we allow the full entry to appear on the report
      # before the limit is reached and cut off
      ent_2 = FactoryBot(:entry, broker_reference:"DEF")
      invoice_2 = FactoryBot(:commercial_invoice, entry:ent_2, invoice_number:"DEF")
      line_2 = FactoryBot(:commercial_invoice_line, commercial_invoice:invoice_2, line_number: 2)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line:line_2, hts_code:"1234567890", entered_value:30, duty_amount:57.68)

      subject.search_columns.build(:rank=>0, :model_field_uid=>:ent_brok_ref)
      rows = subject.to_arrays user, row_limit: 1
      expect(rows.size).to eq(2)
      expect(rows[0]).to eq ["Broker Reference", "Underlying Classification", "Underlying Classification Rate",
                             "Underlying Classification Duty",
                             "Est Underlying Classification Duty", "MTB Classification", "MTB Classification Rate",
                             "MTB Classification Duty", "301 Classification", "301 Classification Rate",
                             "301 Classification Duty", "Tariff Entered Value", "Total Duty Paid", "MTB Savings"]
      expect(rows[1]).to eq ["ABC", "1234.56.7890", BigDecimal("0.10"), BigDecimal("0"), BigDecimal("10"), "9902.12.3456", BigDecimal("0.01"), BigDecimal("1"), "", "", "", BigDecimal("100"), BigDecimal("1"), BigDecimal("9")]
    end

    it "raises an error when country not found" do
      country_us.destroy
      subject.search_columns.build(:rank=>0, :model_field_uid=>:ent_brok_ref)
      expect { subject.send(:country_us) }.to raise_error "US country record not found."
    end
  end

end