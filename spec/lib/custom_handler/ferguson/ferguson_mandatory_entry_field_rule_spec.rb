describe OpenChain::CustomHandler::Ferguson::FergusonMandatoryEntryFieldRule do

  describe "run_validation" do
    let(:entry) do
      entry = Entry.new(entry_number: "X", release_date: Date.new(2020, 8, 10), export_country_codes: "X",
                        entered_value: 5, total_duty: 5)
      inv_1 = entry.commercial_invoices.build(currency: "X", invoice_date: Date.new(2020, 8, 11))
      cil_1 = inv_1.commercial_invoice_lines.build(country_origin_code: "X", currency: "X")
      cil_1.commercial_invoice_tariffs.build(hts_code: "X", duty_advalorem: 5, entered_value_7501: 5)
      cil_1.commercial_invoice_tariffs.build(hts_code: "X", duty_advalorem: 5, entered_value_7501: 5)
      cil_2 = inv_1.commercial_invoice_lines.build(country_origin_code: "X", currency: "X")
      cil_2.commercial_invoice_tariffs.build(hts_code: "X", duty_advalorem: 5, entered_value_7501: 5)

      inv_2 = entry.commercial_invoices.build(currency: "X", invoice_date: Date.new(2020, 8, 11))
      cil_2 = inv_2.commercial_invoice_lines.build(country_origin_code: "X", currency: "X")
      cil_2.commercial_invoice_tariffs.build(hts_code: "X", duty_advalorem: 5, entered_value_7501: 5)

      entry
    end

    it "does not error when all mandatory fields have values" do
      expect(subject.run_validation(entry)).to be_nil
    end

    it "errors if an invoice line is missing tariffs" do
      entry.commercial_invoices[0].commercial_invoice_lines[1].commercial_invoice_tariffs.clear

      expect(subject.run_validation(entry)).to eq "One or more Invoice Line has no tariffs."
    end

    it "errors if an invoice is missing lines" do
      entry.commercial_invoices[0].commercial_invoice_lines.clear

      expect(subject.run_validation(entry)).to eq "One or more Invoice has no lines."
    end

    it "errors if the entry has no invoices" do
      entry.commercial_invoices.clear

      expect(subject.run_validation(entry)).to eq "Entry has no Invoices."
    end

    it "errors if entry is missing entry number" do
      entry.entry_number = nil

      expect(subject.run_validation(entry)).to eq "Entry Number is required."
    end

    it "errors if entry has a blank entry number" do
      entry.entry_number = ' '

      expect(subject.run_validation(entry)).to eq "Entry Number is required."
    end

    it "errors if entry is missing release date" do
      entry.release_date = nil

      expect(subject.run_validation(entry)).to eq "Release Date is required."
    end

    it "errors if entry is missing export country codes" do
      entry.export_country_codes = nil

      expect(subject.run_validation(entry)).to eq "Country Export Codes is required."
    end

    it "errors if entry has a blank export country codes" do
      entry.export_country_codes = ' '

      expect(subject.run_validation(entry)).to eq "Country Export Codes is required."
    end

    it "errors if entry is missing entered value" do
      entry.entered_value = nil

      expect(subject.run_validation(entry)).to eq "Total Entered Value is required."
    end

    it "errors if entry is missing total duty" do
      entry.total_duty = nil

      expect(subject.run_validation(entry)).to eq "Total Duty is required."
    end

    it "does not error if numeric fields are zero" do
      entry.entered_value = 0
      entry.total_duty = 0
      entry.commercial_invoices[0].commercial_invoice_lines[0].commercial_invoice_tariffs[1].duty_advalorem = 0
      entry.commercial_invoices[0].commercial_invoice_lines[0].commercial_invoice_tariffs[1].entered_value_7501 = 0

      expect(subject.run_validation(entry)).to be_nil
    end

    it "errors if an invoice is missing currency" do
      entry.commercial_invoices[1].currency = nil

      expect(subject.run_validation(entry)).to eq "Invoice - Currency is required."
    end

    it "errors if an invoice has a blank currency" do
      entry.commercial_invoices[1].currency = ' '

      expect(subject.run_validation(entry)).to eq "Invoice - Currency is required."
    end

    it "errors if all invoices are missing invoice date" do
      entry.commercial_invoices[0].invoice_date = nil
      entry.commercial_invoices[1].invoice_date = nil

      expect(subject.run_validation(entry)).to eq "Invoice - Invoice Date is required."
    end

    it "does not error if only one invoice is missing invoice date" do
      entry.commercial_invoices[0].invoice_date = nil

      expect(subject.run_validation(entry)).to be_nil
    end

    it "errors if an invoice line is missing country origin code" do
      entry.commercial_invoices[0].commercial_invoice_lines[1].country_origin_code = nil

      expect(subject.run_validation(entry)).to eq "Invoice Line - Country Origin Code is required."
    end

    it "errors if an invoice line has a blank country origin code" do
      entry.commercial_invoices[0].commercial_invoice_lines[1].country_origin_code = ' '

      expect(subject.run_validation(entry)).to eq "Invoice Line - Country Origin Code is required."
    end

    it "errors if an invoice line is missing currency" do
      entry.commercial_invoices[0].commercial_invoice_lines[1].currency = nil

      expect(subject.run_validation(entry)).to eq "Invoice Line - Currency is required."
    end

    it "errors if an invoice line has a blank currency" do
      entry.commercial_invoices[0].commercial_invoice_lines[1].currency = ' '

      expect(subject.run_validation(entry)).to eq "Invoice Line - Currency is required."
    end

    it "errors if a tariff is missing HTS code" do
      entry.commercial_invoices[0].commercial_invoice_lines[0].commercial_invoice_tariffs[1].hts_code = nil

      expect(subject.run_validation(entry)).to eq "Invoice Tariff - HTS Code is required."
    end

    it "errors if a tariff has a blank HTS code" do
      entry.commercial_invoices[0].commercial_invoice_lines[0].commercial_invoice_tariffs[1].hts_code = ' '

      expect(subject.run_validation(entry)).to eq "Invoice Tariff - HTS Code is required."
    end

    it "errors if a tariff is missing ad valorem duty" do
      entry.commercial_invoices[0].commercial_invoice_lines[0].commercial_invoice_tariffs[1].duty_advalorem = nil

      expect(subject.run_validation(entry)).to eq "Invoice Tariff - Ad Valorem Duty is required."
    end

    it "errors if a tariff is missing 7501 entered value" do
      entry.commercial_invoices[0].commercial_invoice_lines[0].commercial_invoice_tariffs[1].entered_value_7501 = nil

      expect(subject.run_validation(entry)).to eq "Invoice Tariff - 7501 Entered Value is required."
    end

    it "handles multiple errors" do
      entry.entry_number = nil
      entry.release_date = nil
      entry.export_country_codes = nil
      entry.entered_value = nil
      entry.total_duty = nil
      entry.commercial_invoices[1].currency = nil
      entry.commercial_invoices[0].invoice_date = nil
      entry.commercial_invoices[1].invoice_date = nil
      entry.commercial_invoices[0].commercial_invoice_lines[1].country_origin_code = nil
      entry.commercial_invoices[0].commercial_invoice_lines[1].currency = nil
      entry.commercial_invoices[0].commercial_invoice_lines[0].commercial_invoice_tariffs[1].hts_code = nil
      entry.commercial_invoices[0].commercial_invoice_lines[0].commercial_invoice_tariffs[1].duty_advalorem = nil
      entry.commercial_invoices[0].commercial_invoice_lines[0].commercial_invoice_tariffs[1].entered_value_7501 = nil

      expect(subject.run_validation(entry)).to eq "Entry Number is required. Release Date is required. " +
                                                  "Country Export Codes is required. Total Entered Value is required. " +
                                                  "Total Duty is required. Invoice - Currency is required. " +
                                                  "Invoice - Invoice Date is required. " +
                                                  "Invoice Line - Country Origin Code is required. " +
                                                  "Invoice Line - Currency is required. " +
                                                  "Invoice Tariff - HTS Code is required. " +
                                                  "Invoice Tariff - Ad Valorem Duty is required. " +
                                                  "Invoice Tariff - 7501 Entered Value is required."
    end
  end

end