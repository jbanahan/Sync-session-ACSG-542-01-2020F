describe OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser do
  describe "extract_check_info" do
    it "extracts check info from file" do
      file = <<-FILE
      APMRGREG-D0-06/22/09
---------- ---------- ------------  ---------- ---------- --- --------- ------------ ------------- ---------- ---- -------------  --
      9801 KINGOCEAN     1615657A              IGM        F   0202-0000 LIOPEV12468      2,295.00  08/12/2014 Adv                 AP
           KING OCEAN SERVICES         Total of Check       9801                         2,295.00

      9801 KINGOCEAN     1615657A              IGM        F   0202-0000 LIOPEV12468      2,295.00- 08/12/2014 Void                RV
           KING OCEAN SERVICES         Total of Check       9801                         2,295.00-

      9802 KINGOCEAN     1615657A              IGM        F   0202-0000 LIOPEV12468      3,000.00  08/12/2014 Adv                 AP
           KING OCEAN SERVICES         Total of Check       9802                         3,000.00


                                                   3 Checks for Bank 02 Totaling         3,000.00
---------- ---------- ------------  ---------- ---------- --- --------- ------------ ------------- ---------- ---- -------------  --
     *****  Grand Total  *****                           Record Count:    108          109,275.95

FILE
      check_info = subject.extract_check_info StringIO.new(file)

      expect(check_info[:total_check_count]).to eq 108
      expect(check_info[:total_check_amount]).to eq BigDecimal.new("109275.95")

      bank_check_info = check_info[:checks]["2"]
      expect(bank_check_info[:check_count]).to eq 3
      expect(bank_check_info[:check_total]).to eq BigDecimal.new("3000")
      checks = bank_check_info[:checks]
      expect(checks.length).to eq 3

      check = checks.first
      expect(check[:bank_number]).to eq "2"
      expect(check[:check_number]).to eq "9801"
      expect(check[:vendor_number]).to eq "KINGOCEAN"
      expect(check[:invoice_number]).to eq "1615657"
      expect(check[:invoice_suffix]).to eq "A"
      expect(check[:customer_number]).to eq "IGM"
      expect(check[:vendor_reference]).to eq "LIOPEV12468"
      expect(check[:check_amount]).to eq BigDecimal.new("2295.00")
      expect(check[:check_date]).to eq Date.new(2014, 8, 12)

      check = checks[1]
      expect(check[:bank_number]).to eq "2"
      expect(check[:check_number]).to eq "9801"
      expect(check[:vendor_number]).to eq "KINGOCEAN"
      expect(check[:invoice_number]).to eq "1615657"
      expect(check[:invoice_suffix]).to eq "A"
      expect(check[:customer_number]).to eq "IGM"
      expect(check[:vendor_reference]).to eq "LIOPEV12468"
      expect(check[:check_amount]).to eq BigDecimal.new("-2295.00")
      expect(check[:check_date]).to eq Date.new(2014, 8, 12)

      check = checks[2]
      expect(check[:bank_number]).to eq "2"
      expect(check[:check_number]).to eq "9802"
      expect(check[:vendor_number]).to eq "KINGOCEAN"
      expect(check[:invoice_number]).to eq "1615657"
      expect(check[:invoice_suffix]).to eq "A"
      expect(check[:customer_number]).to eq "IGM"
      expect(check[:vendor_reference]).to eq "LIOPEV12468"
      expect(check[:check_amount]).to eq BigDecimal.new("3000")
      expect(check[:check_date]).to eq Date.new(2014, 8, 12)
    end

    it "raises an error when file is not of the expected format" do
      # Just change the date format as if it had been updated...this should force a failure
      file = "\n\n\nAPMRGREG-D0-06/22/14\n\n\n"
      expect{check_info = subject.extract_check_info StringIO.new(file)}.to raise_error "Attempted to parse an Alliance Check Register file that is not the correct format. Expected to find 'APMRGREG-D0-06/22/09' on the first non-blank line of the file."
    end

    it "handles blank files" do
      file = <<-FILE
            APMRGREG-D0-06/22/09
      ---------- ---------- ------------  ---------- ---------- --- --------- ------------ ------------- ---------- ---- -------------  --
           *****  Grand Total  *****                           Record Count:    0                  0.00

      FILE

      check_info = subject.extract_check_info StringIO.new(file)

      expect(check_info[:total_check_count]).to eq 0
      expect(check_info[:total_check_amount]).to eq BigDecimal.new("0")
    end
  end

  describe "validate_check_info" do
    it "validates check info is internally consistent" do
      check_info = {
        :total_check_count => 2,
        :total_check_amount => BigDecimal.new("100.00"),
        :checks => {
          "2" => {
            check_count: 2,
            check_total: BigDecimal.new("100.00"),
            checks: [
              {check_amount: BigDecimal.new("25.00")},
              {check_amount: BigDecimal.new("75.00")}
            ]
          }
        }
      }

      errors = subject.validate_check_info check_info
      expect(errors.size).to eq 0
    end

    it "raises an error if total count is missing" do
      expect{subject.validate_check_info({})}.to raise_error "No Check Register Record Count found."
    end

    it "raises an error if total check amount is missing" do
      expect{subject.validate_check_info({total_check_count: 1})}.to raise_error "No Check Register Grand Total amount found."
    end

    it "returns errors when check info is not internally consistent" do
      check_info = {
        :total_check_count => 6,
        :total_check_amount => BigDecimal.new("400.00"),
        :checks => {
          "2" => {
            check_count: 4,
            check_total: BigDecimal.new("200.00"),
            checks: [
              {check_amount: BigDecimal.new("25.00")},
              {check_amount: BigDecimal.new("75.00")}
            ]
          }
        }
      }

      errors = subject.validate_check_info check_info
      expect(errors.size).to eq 4
      expect(errors).to include "Expected 4 checks for Bank 02.  Found 2 checks."
      expect(errors).to include "Expected Check Total Amount of $200.00 for Bank 02.  Found $100.00."
      expect(errors).to include "Expected 6 checks to be in the register file.  Found 2 checks."
      expect(errors).to include "Expected Grand Total of $400.00 to be in the register file.  Found $100.00."
    end

    it "handles negative amounts in validations" do
      file = <<-FILE
      APMRGREG-D0-06/22/09
---------- ---------- ------------  ---------- ---------- --- --------- ------------ ------------- ---------- ---- -------------  --
      9801 KINGOCEAN     1615657A              IGM        F   0202-0000 LIOPEV12468      2,295.00- 08/12/2014 Void                RV
           KING OCEAN SERVICES         Total of Check       9801                         2,295.00-

                                                   1 Checks for Bank 02 Totaling         2,295.00-
---------- ---------- ------------  ---------- ---------- --- --------- ------------ ------------- ---------- ---- -------------  --
     *****  Grand Total  *****                           Record Count:    1              2,295.00-

FILE
      check_info = subject.extract_check_info StringIO.new(file)
      errors = subject.validate_check_info check_info
      expect(errors.size).to eq 0
    end

    it "handles missing checks data when no checks were found" do
      check_info = {
        :total_check_count => 0,
        :total_check_amount => BigDecimal.new("0.00")
      }

      errors = subject.validate_check_info check_info
      expect(errors.size).to eq 0
    end
  end

  describe "create_and_request_check" do
    let (:sql_proxy_client) {
      c = instance_double(OpenChain::KewillSqlProxyClient)
      allow(c).to receive(:delay).and_return c
      c
    }

    let (:check_info) {
      {
        check_number: "987", vendor_number: "VEND", invoice_number: "123", invoice_suffix: "", customer_number: "CUST",
        vendor_reference: "VEND_REF", check_amount: BigDecimal.new("100.00"), check_date: Date.new(2014, 11, 1), bank_number: "1",
        file_number: "123"
      }
    }

    it "creates a check and export object" do
      bank_name = DataCrossReference.create! key: check_info[:bank_number], value: "BANK NAME", cross_reference_type: DataCrossReference::ALLIANCE_BANK_ACCOUNT_TO_INTACCT
      xref = DataCrossReference.create! key: "BANK NAME", value: "1234", cross_reference_type: DataCrossReference::INTACCT_BANK_CASH_GL_ACCOUNT

      expect(sql_proxy_client).to receive(:request_check_details).with check_info[:invoice_number], check_info[:check_number], check_info[:check_date], check_info[:bank_number], check_info[:check_amount].to_s
      check, errors = subject.create_and_request_check check_info, sql_proxy_client
      expect(errors.length).to eq 0

      expect(check).to be_persisted
      expect(check.file_number).to eq check_info[:invoice_number]
      expect(check.suffix).to be_nil
      expect(check.check_number).to eq check_info[:check_number]
      expect(check.check_date).to eq check_info[:check_date]
      expect(check.bank_number).to eq check_info[:bank_number]
      expect(check.customer_number).to eq check_info[:customer_number]
      expect(check.bill_number).to eq check_info[:invoice_number]
      expect(check.vendor_number).to eq check_info[:vendor_number]
      expect(check.vendor_reference).to eq check_info[:vendor_reference]
      expect(check.amount).to eq check_info[:check_amount]
      expect(check.gl_account).to eq "2021"
      expect(check.bank_cash_gl_account).to eq xref.value

      export = check.intacct_alliance_export
      expect(export).to be_persisted

      expect(export.customer_number).to eq check_info[:customer_number]
      expect(export.data_requested_date.to_date).to eq Time.zone.now.to_date
      expect(export.data_received_date).to be_nil
      expect(export.ap_total).to eq check.amount
      expect(export.invoice_date).to eq check.check_date
      expect(export.check_number).to eq check.check_number
    end

    it "updates existing check / export objects" do
      check_info[:invoice_suffix] = "A"
      existing_check = IntacctCheck.create! file_number: check_info[:invoice_number], suffix: check_info[:invoice_suffix], check_number: check_info[:check_number], check_date: check_info[:check_date], bank_number: check_info[:bank_number], amount: check_info[:check_amount], voided: false
      existing_export = IntacctAllianceExport.create! file_number: check_info[:invoice_number], suffix: check_info[:invoice_suffix], check_number: check_info[:check_number], export_type: IntacctAllianceExport::EXPORT_TYPE_CHECK, data_received_date: Time.zone.now, ap_total: check_info[:check_amount], intacct_checks: [existing_check]

      expect(sql_proxy_client).to receive(:request_check_details).with check_info[:invoice_number], check_info[:check_number], check_info[:check_date], check_info[:bank_number], check_info[:check_amount].to_s
      check, errors = subject.create_and_request_check check_info, sql_proxy_client
      expect(errors.length).to eq 0

      expect(check).to eq existing_check
      expect(check.intacct_alliance_export).to eq existing_export
      expect(check.intacct_alliance_export.data_received_date).to be_nil
    end

    it "errors if check has already been sent to intacct" do
      check_info[:invoice_suffix] = "A"
      IntacctCheck.create! file_number: check_info[:invoice_number], suffix: check_info[:invoice_suffix], check_number: check_info[:check_number], check_date: check_info[:check_date], bank_number: check_info[:bank_number], intacct_upload_date: Time.zone.now, intacct_key: "Key", amount: check_info[:check_amount], voided: false
      check, errors = subject.create_and_request_check check_info, nil
      expect(check).to be_nil
      expect(errors.length).to eq 1
      expect(errors).to include "Bank # 1 / Check # 987 for $100.00"
    end

    it "creates a single check when multiple rows reference the same check number with different file number" do
      # This is testing that an error condition is handled correctly by re-using the same check object (and not creating two distinct ones)
      existing_check = IntacctCheck.create! file_number: check_info[:invoice_number], suffix: check_info[:invoice_suffix], check_number: check_info[:check_number], check_date: check_info[:check_date], bank_number: check_info[:bank_number], amount: check_info[:check_amount], voided: false
      
      check_info[:invoice_number] = "987654"
      check_info[:suffix] = "A"
      check_info[:check_amount] = BigDecimal.new("200")


      expect(sql_proxy_client).to receive(:request_check_details).with check_info[:invoice_number], check_info[:check_number], check_info[:check_date], check_info[:bank_number], check_info[:check_amount].to_s
      check, errors = subject.create_and_request_check check_info, sql_proxy_client
      expect(errors.length).to eq 0

      expect(check).to eq existing_check
      expect(check.intacct_alliance_export).not_to be_nil
      expect(check.file_number).to eq "987654"
      expect(check.amount).to eq BigDecimal.new("200")
    end

     it "creates a single check when multiple rows reference the same info except vendor reference" do
      # This is another error case..the only information that differed across lines in the registry for these
      # were the vendor reference.  This should still only create a single reference.
      existing_check = IntacctCheck.create! file_number: check_info[:invoice_number], suffix: check_info[:invoice_suffix], check_number: check_info[:check_number], check_date: check_info[:check_date], bank_number: check_info[:bank_number], amount: check_info[:check_amount], voided: false
      
      check_info[:vendor_reference] = "DIFFERENT REFERENCE"


      expect(sql_proxy_client).to receive(:request_check_details).with check_info[:invoice_number], check_info[:check_number], check_info[:check_date], check_info[:bank_number], check_info[:check_amount].to_s
      check, errors = subject.create_and_request_check check_info, sql_proxy_client
      expect(errors.length).to eq 0

      expect(check).to eq existing_check
      expect(check.intacct_alliance_export).not_to be_nil
      expect(check.vendor_reference).to eq "DIFFERENT REFERENCE"
    end

    it "no-ops if same check has been previously sent to intacct" do
      # Note that the check is created with a different check date than the report data..
      existing_check = IntacctCheck.create!(bank_number: check_info[:bank_number], check_number: check_info[:check_number], amount: check_info[:check_amount], voided: false,
                                            file_number: check_info[:file_number], suffix: nil, customer_number: check_info[:customer_number], 
                                            vendor_number: check_info[:vendor_number], check_date: Time.zone.now.to_date, intacct_upload_date: Time.zone.now)

      check, errors = subject.create_and_request_check check_info, sql_proxy_client
      expect(errors.length).to eq 0
      expect(check).to be_nil
    end
  end

  describe "process_from_s3" do
    before :each do
      @tempfile = Tempfile.new ["check_register", ".rpt"]
      @tempfile << "This is a test"
      @tempfile.flush
      @bucket = "bucket"
      @path = 'path/to/file.txt'
      allow(OpenChain::S3).to receive(:download_to_tempfile).with(@bucket, @path, original_filename: "file.txt").and_yield @tempfile
    end

    after :each do
      @tempfile.close! unless @tempfile.closed?
    end

    it "saves given file, checks for check register file and runs day end process" do
      # Block the attachment setting so we're not saving to S3
      expect_any_instance_of(CustomFile).to receive(:attached=).with @tempfile

      invoice_file = CustomFile.create! file_type: "OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser", uploaded_by: User.integration

      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler).to receive(:delay).and_return OpenChain::CustomHandler::Intacct::AllianceDayEndHandler
      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler).to receive(:process_delayed) do |check_id, invoice_id, user_id|
        expect(CustomFile.find(check_id).file_type).to eq "OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser"
        expect(invoice_id).to eq invoice_file.id
        expect(user_id).to be_nil
      end

      OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.process_from_s3(@bucket, @path)

      saved = CustomFile.where(file_type: "OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser").first
      expect(saved).not_to be_nil
      expect(DataCrossReference.where(key: Digest::MD5.hexdigest("This is a test"), value: "file.txt", cross_reference_type: DataCrossReference::ALLIANCE_CHECK_REPORT_CHECKSUM).first).not_to be_nil
    end

    it "saves given file, but doesn't call day end process without a check file existing" do
      # Block the attachment setting so we're not saving to S3
      expect_any_instance_of(CustomFile).to receive(:attached=).with @tempfile
      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler).not_to receive(:delay)

      OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.process_from_s3(@bucket, @path)
      saved = CustomFile.where(file_type: "OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser").first
      expect(saved).not_to be_nil
    end

    it "does not kick off day end process if invoice file has already been processed" do
      # Block the attachment setting so we're not saving to S3
      expect_any_instance_of(CustomFile).to receive(:attached=).with @tempfile
      check_file = CustomFile.create! file_type: "OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser", uploaded_by: User.integration, start_at: Time.zone.now

      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler).not_to receive(:delay)

      OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.process_from_s3(@bucket, @path)
      saved = CustomFile.where(file_type: "OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser").first
      expect(saved).not_to be_nil
    end

    it "recognizes duplicate check file content and does not launch day end" do
      DataCrossReference.create!(key: Digest::MD5.hexdigest("This is a test"), value: "existing.txt", cross_reference_type: DataCrossReference::ALLIANCE_CHECK_REPORT_CHECKSUM)

       # Block the attachment setting so we're not saving to S3
      expect_any_instance_of(CustomFile).to receive(:attached=).with @tempfile
      invoice_file = CustomFile.create! file_type: "OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser", uploaded_by: User.integration
      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler).not_to receive(:delay)

      OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.process_from_s3(@bucket, @path)

      saved = CustomFile.where(file_type: "OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser").first
      expect(saved).not_to be_nil

      expect(saved.error_message).to eq "Another file named existing.txt has already been received with this information."
      expect(saved.start_at).not_to be_nil
      expect(saved.finish_at).not_to be_nil
      expect(saved.error_at).not_to be_nil
    end

    it "ignores checksums over 1 month old" do
      DataCrossReference.create!(key: Digest::MD5.hexdigest("This is a test"), value: "existing.txt", cross_reference_type: DataCrossReference::ALLIANCE_CHECK_REPORT_CHECKSUM, created_at: Time.zone.now - 32.days)

       # Block the attachment setting so we're not saving to S3
      expect_any_instance_of(CustomFile).to receive(:attached=).with @tempfile

      invoice_file = CustomFile.create! file_type: "OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser", uploaded_by: User.integration

      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler).to receive(:delay).and_return OpenChain::CustomHandler::Intacct::AllianceDayEndHandler
      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler).to receive(:process_delayed)

      OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.process_from_s3(@bucket, @path)
    end

    it "does not queue day end job if one is already on the queue" do
      invoice_file = CustomFile.create! file_type: "OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser", uploaded_by: User.integration
      dj = Delayed::Job.new
      dj.handler = "OpenChain::CustomHandler::Intacct::AllianceDayEndHandler--process_delayed"
      dj.save!
      
      expect_any_instance_of(CustomFile).to receive(:attached=).with @tempfile
      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndHandler).not_to receive(:delay)

      OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.process_from_s3(@bucket, @path)

      saved = CustomFile.where(file_type: "OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser").first
      expect(saved).not_to be_nil
    end
  end

  describe "validate_and_remove_duplicate_check_references" do
    let (:check_data) {
      {
        bank_number: "1", check_number: "12345", check_date: Date.new(2018, 12, 12), 
        check_amount: BigDecimal("100"), customer_number: "CUST", invoice_number: "INV", invoice_suffix: "A", vendor_number: "VEN"
      }
    }

    let (:check_info) {
      {
        checks: {
          "1" => {
            checks: [
              check_data
            ]
          }  
        }
      }
    }

    it "validates data and repopulates the totals for the bank when duplicate check references are found" do
      # add a duplicate check data, make sure it gets removed and the totals are recalculated to only have data for the single check
      check_info[:checks]["1"][:checks] << check_data

      errors = subject.validate_and_remove_duplicate_check_references check_info
      expect(errors).to be_blank
      data = check_info[:checks]["1"]

      expect(data[:checks].length).to eq 1
      expect(data[:check_total]).to eq BigDecimal("100")
      expect(data[:check_count]).to eq 1
    end

    [:check_date, :check_amount, :customer_number, :invoice_number, :invoice_suffix, :vendor_number].each do |key|
      # This is checking that if any of the above values don't match we catch the duplicate bank/check as an error
      it "errors if there are two checks with the same bank / check number with different #{key}" do
        bad_check = check_data.dup
        bad_check[key] = key.to_s
        check_info[:checks]["1"][:checks] << bad_check

        errors = subject.validate_and_remove_duplicate_check_references check_info
        expect(errors).to include "Multiple different checks found for Bank # 1 / Check # 12345."
      end
    end

    it "does not error or remove as a duplicate if there's a voided version of the check" do
      voided_check = check_data.dup
      voided_check[:check_amount] = voided_check[:check_amount] * -1
      check_info[:checks]["1"][:checks] << voided_check

      errors = subject.validate_and_remove_duplicate_check_references check_info
      expect(errors).to be_blank
      data = check_info[:checks]["1"]

      expect(data[:checks].length).to eq 2
      expect(data[:check_total]).to eq 0
      expect(data[:check_count]).to eq 2
    end
    
    it "handles missing check data on blank check files" do
      errors = subject.validate_and_remove_duplicate_check_references({})
      expect(errors).to be_blank
    end
  end
end
