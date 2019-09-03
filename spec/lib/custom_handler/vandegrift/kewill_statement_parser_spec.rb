describe OpenChain::CustomHandler::Vandegrift::KewillStatementParser do

  let (:daily_statement) {
    {"statement"=>
        {"statement_number"=>"04118319AQ9",
         "status"=>"P",
         "customer_number" => "TEST",
         "received_date"=>20171101,
         "due_date"=>20171115,
         "paid_date"=>20171111,
         "payment_accepted_date"=>20171114,
         "port_code"=>4103,
         "payment_type"=>7,
         "monthly_statement_number" => "0411P128031",
         "extract_time" => "2017-11-17t12:18:56-05:00",
         "details"=>
          [{"broker_reference"=>"002316567",
            "entry_number"=>23165672,
            "port_code"=>4103,
            "duty_amount"=>100,
            "tax_amount"=>200,
            "cvd_amount"=>300,
            "add_amount"=>400,
            "fee_amount"=>500,
            "interest_amount"=>600,
            "total_amount"=>2100,
            "fees"=>
             [{"entry_number"=>23165672,
               "code"=>499,
               "description"=>"Merchandise Fee",
               "amount"=>500}]},
           {"broker_reference"=>"002317459",
            "entry_number"=>23174591,
            "port_code"=>4103,
            "duty_amount"=>1000,
            "tax_amount"=>1100,
            "cvd_amount"=>1200,
            "add_amount"=>1300,
            "fee_amount"=>1400,
            "interest_amount"=>1500,
            "total_amount"=>7500,
            "fees"=>
             [{"entry_number"=>23174591,
               "code"=>499,
               "description"=>"Merchandise Fee",
               "amount"=>1400}]}]}}
  }

  let (:monthly_statement) {
    {
      "monthly_statement"=> {
        "statement_number" => "0411P128031",
        "status" => "P",
        "customer_number" => "TEST",
        "received_date" => 20171116,
        "due_date" => 20171117,
        "paid_date" => 20171118,
        "port_code" => 4103,
        "payment_type" => 7,
        "extract_time" => "2017-11-20t16:37:04-05:00"
      }
    }
  }

  let (:test_importer) { with_customs_management_id(Factory(:importer), "TEST") }
  let (:user) { Factory(:user) }
  let (:port) { Factory(:port, schedule_d_code: "4103")}
  let (:log) { InboundFile.new }

  describe "process_daily_statement" do

    let (:statement) {
      daily_statement
    }

    let! (:entry) { Factory(:entry, source_system: Entry::KEWILL_SOURCE_SYSTEM, broker_reference: "2316567") }
    let! (:broker_invoice) {
      inv_line = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: entry), charge_code: "0001", charge_amount: 100)
      inv_line = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: entry), charge_code: "0002", charge_amount: 100)
      inv_line.broker_invoice
    }
    let! (:monthly_statement) { MonthlyStatement.create! statement_number: "0411P128031", importer_id: test_importer.id}

    let (:existing_statement) {
      DailyStatement.create!(statement_number: "04118319AQ9", preliminary_duty_amount: 2, preliminary_tax_amount: 4, preliminary_cvd_amount: 6, preliminary_add_amount: 8, preliminary_fee_amount: 10, preliminary_interest_amount: 12, preliminary_total_amount: 42,
        duty_amount: 2, tax_amount: 4, cvd_amount: 6, add_amount: 8, fee_amount: 10, interest_amount: 12, total_amount: 42, status: "P", monthly_statement_number: "0411P128031")
    }

    let (:existing_statement_entry) {
      existing_statement.daily_statement_entries.create!(broker_reference: "2316567", entry_id: entry.id, preliminary_duty_amount: 2, preliminary_tax_amount: 4, preliminary_cvd_amount: 6, preliminary_add_amount: 8, preliminary_fee_amount: 10, preliminary_interest_amount: 12, preliminary_total_amount: 42,
        duty_amount: 2, tax_amount: 4, cvd_amount: 6, add_amount: 8, fee_amount: 10, interest_amount: 12, total_amount: 42)
    }

    let (:existing_statement_entry_fee) {
      existing_statement_entry.daily_statement_entry_fees.create! code: "499", amount: 10000, preliminary_amount: 15000
    }

    before :each do 
      user
      test_importer
      port
    end

    it "reads statement data from json and saves it" do
      s = subject.process_daily_statement user, statement, log, "bucket", "path"
      expect(s).not_to be_nil
      s.reload

      expect(s.statement_number).to eq "04118319AQ9"
      expect(s.status).to eq "P"
      expect(s.importer).to eq test_importer
      expect(s.port_code).to eq "4103"
      expect(s.port).to eq port
      expect(s.pay_type).to eq "7"
      expect(s.monthly_statement_number).to eq "0411P128031"
      expect(s.monthly_statement).to eq monthly_statement
      expect(s.received_date).to eq Date.new(2017, 11, 01)
      expect(s.final_received_date).to be_nil
      expect(s.paid_date).to eq Date.new(2017, 11, 11)
      expect(s.payment_accepted_date).to eq Date.new(2017, 11, 14)
      expect(s.due_date).to eq Date.new(2017, 11, 15)
      expect(s.final_received_date).to be_nil
      expect(s.last_file_bucket).to eq "bucket"
      expect(s.last_file_path).to eq "path"
      expect(s.last_exported_from_source).to eq Time.zone.parse("2017-11-17 17:18:56")
      expect(s.customer_number).to eq "TEST"

      expect(s.preliminary_duty_amount).to eq BigDecimal("11")
      expect(s.preliminary_tax_amount).to eq BigDecimal("13")
      expect(s.preliminary_cvd_amount).to eq BigDecimal("15")
      expect(s.preliminary_add_amount).to eq BigDecimal("17")
      expect(s.preliminary_fee_amount).to eq BigDecimal("19")
      expect(s.preliminary_interest_amount).to eq BigDecimal("21")
      expect(s.preliminary_total_amount).to eq BigDecimal("96")

      expect(s.duty_amount).to eq BigDecimal("11")
      expect(s.tax_amount).to eq BigDecimal("13")
      expect(s.cvd_amount).to eq BigDecimal("15")
      expect(s.add_amount).to eq BigDecimal("17")
      expect(s.fee_amount).to eq BigDecimal("19")
      expect(s.interest_amount).to eq BigDecimal("21")
      expect(s.total_amount).to eq BigDecimal("96")

      expect(s.entity_snapshots.length).to eq 1
      snap = s.entity_snapshots.first
      expect(snap.user).to eq user
      expect(snap.context).to eq "path"

      expect(s.daily_statement_entries.length).to eq 2
      e = s.daily_statement_entries.first

      expect(e.broker_reference).to eq "2316567"
      expect(e.entry).to eq entry
      expect(e.billed_amount).to eq BigDecimal("100")
      expect(e.port_code).to eq "4103"
      expect(e.port).to eq port
      expect(e.preliminary_duty_amount).to eq BigDecimal("1")
      expect(e.preliminary_tax_amount).to eq BigDecimal("2")
      expect(e.preliminary_cvd_amount).to eq BigDecimal("3")
      expect(e.preliminary_add_amount).to eq BigDecimal("4")
      expect(e.preliminary_fee_amount).to eq BigDecimal("5")
      expect(e.preliminary_interest_amount).to eq BigDecimal("6")
      expect(e.preliminary_total_amount).to eq BigDecimal("21")

      expect(e.duty_amount).to eq BigDecimal("1")
      expect(e.tax_amount).to eq BigDecimal("2")
      expect(e.cvd_amount).to eq BigDecimal("3")
      expect(e.add_amount).to eq BigDecimal("4")
      expect(e.fee_amount).to eq BigDecimal("5")
      expect(e.interest_amount).to eq BigDecimal("6")
      expect(e.total_amount).to eq BigDecimal("21")

      expect(e.daily_statement_entry_fees.length).to eq 1
      f = e.daily_statement_entry_fees.first

      expect(f.code).to eq "499"
      expect(f.description).to eq "Merchandise Fee"
      expect(f.preliminary_amount).to eq BigDecimal("5")
      expect(f.amount).to eq BigDecimal("5")

      expect(log.company).to be_nil
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_DAILY_STATEMENT_NUMBER)[0].value).to eq "04118319AQ9"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_DAILY_STATEMENT_NUMBER)[0].module_type).to eq "DailyStatement"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_DAILY_STATEMENT_NUMBER)[0].module_id).to eq s.id
    end

    it "handles updates to statements" do
      existing_statement_entry_fee

      s = subject.process_daily_statement user, statement, log, "bucket", "path"
      expect(s).to eq existing_statement
      expect(s.last_exported_from_source).to eq Time.zone.parse("2017-11-17 17:18:56")

      expect(s.daily_statement_entries.length).to eq 2

      # The major point here is that we want to make sure the existing details and fees are retained and re-used
      # If they were destroyed, then the reload call below would raise an error
      expect { existing_statement_entry.reload }.not_to raise_error
      expect { existing_statement_entry_fee.reload }.not_to raise_error

      # Make sure the amount data was updated
      expect(s.preliminary_duty_amount).to eq BigDecimal("11")
      expect(s.preliminary_tax_amount).to eq BigDecimal("13")
      expect(s.preliminary_cvd_amount).to eq BigDecimal("15")
      expect(s.preliminary_add_amount).to eq BigDecimal("17")
      expect(s.preliminary_fee_amount).to eq BigDecimal("19")
      expect(s.preliminary_interest_amount).to eq BigDecimal("21")
      expect(s.preliminary_total_amount).to eq BigDecimal("96")

      expect(s.duty_amount).to eq BigDecimal("11")
      expect(s.tax_amount).to eq BigDecimal("13")
      expect(s.cvd_amount).to eq BigDecimal("15")
      expect(s.add_amount).to eq BigDecimal("17")
      expect(s.fee_amount).to eq BigDecimal("19")
      expect(s.interest_amount).to eq BigDecimal("21")
      expect(s.total_amount).to eq BigDecimal("96")

      e = existing_statement_entry
      expect(e.preliminary_duty_amount).to eq BigDecimal("1")
      expect(e.preliminary_tax_amount).to eq BigDecimal("2")
      expect(e.preliminary_cvd_amount).to eq BigDecimal("3")
      expect(e.preliminary_add_amount).to eq BigDecimal("4")
      expect(e.preliminary_fee_amount).to eq BigDecimal("5")
      expect(e.preliminary_interest_amount).to eq BigDecimal("6")
      expect(e.preliminary_total_amount).to eq BigDecimal("21")
      expect(e.duty_amount).to eq BigDecimal("1")
      expect(e.tax_amount).to eq BigDecimal("2")
      expect(e.cvd_amount).to eq BigDecimal("3")
      expect(e.add_amount).to eq BigDecimal("4")
      expect(e.fee_amount).to eq BigDecimal("5")
      expect(e.interest_amount).to eq BigDecimal("6")
      expect(e.total_amount).to eq BigDecimal("21")

      f = existing_statement_entry_fee

      expect(f.code).to eq "499"
      expect(f.description).to eq "Merchandise Fee"
      expect(f.preliminary_amount).to eq BigDecimal("5")
      expect(f.amount).to eq BigDecimal("5")
    end

    it "only updates preliminary amount fields when update is preliminary data and statement is already final" do
      existing_statement_entry_fee
      existing_statement.update_attributes! status: "F"

      s = subject.process_daily_statement user, statement, log, "bucket", "path"

      expect(s.daily_statement_entries.length).to eq 2

      e = s.daily_statement_entries.first
      expect(e.preliminary_duty_amount).to eq BigDecimal("1")
      expect(e.preliminary_tax_amount).to eq BigDecimal("2")
      expect(e.preliminary_cvd_amount).to eq BigDecimal("3")
      expect(e.preliminary_add_amount).to eq BigDecimal("4")
      expect(e.preliminary_fee_amount).to eq BigDecimal("5")
      expect(e.preliminary_interest_amount).to eq BigDecimal("6")
      expect(e.preliminary_total_amount).to eq BigDecimal("21")

      # The non-preliminary fields should not have changed on the existing statement entry
      expect(e.duty_amount).to eq BigDecimal("2")
      expect(e.tax_amount).to eq BigDecimal("4")
      expect(e.cvd_amount).to eq BigDecimal("6")
      expect(e.add_amount).to eq BigDecimal("8")
      expect(e.fee_amount).to eq BigDecimal("10")
      expect(e.interest_amount).to eq BigDecimal("12")
      expect(e.total_amount).to eq BigDecimal("42")

      f = e.daily_statement_entry_fees.first

      # Only the preliminary on the fee should update
      expect(f.preliminary_amount).to eq BigDecimal("5")
      expect(f.amount).to eq BigDecimal("10000")

      #only the preliminary amounts should be updated, since the existing statement was marked as final
      expect(s.preliminary_duty_amount).to eq BigDecimal("11")
      expect(s.preliminary_tax_amount).to eq BigDecimal("13")
      expect(s.preliminary_cvd_amount).to eq BigDecimal("15")
      expect(s.preliminary_add_amount).to eq BigDecimal("17")
      expect(s.preliminary_fee_amount).to eq BigDecimal("19")
      expect(s.preliminary_interest_amount).to eq BigDecimal("21")
      expect(s.preliminary_total_amount).to eq BigDecimal("96")

      # Since the data was for a prelim and the statement is marked final, the amounts from the second 
      # statement entry will be blank - ergo only the first statement data is reflected in the sum'ed amounts
      # This is a situation that really should never happen in real life.
      expect(s.duty_amount).to eq BigDecimal("2")
      expect(s.tax_amount).to eq BigDecimal("4")
      expect(s.cvd_amount).to eq BigDecimal("6")
      expect(s.add_amount).to eq BigDecimal("8")
      expect(s.fee_amount).to eq BigDecimal("10")
      expect(s.interest_amount).to eq BigDecimal("12")
      expect(s.total_amount).to eq BigDecimal("42")
    end

    it "only updates final amounts when the statement switches from preliminary to final" do
      existing_statement_entry_fee
      # The final statement does not update several fields, so make sure we test that
      existing_statement.update_attributes! paid_date: Date.new(2017, 12, 1), payment_accepted_date: Date.new(2017, 12, 2), received_date: Date.new(2017, 12, 3)
      statement["statement"]["status"] = "F"
      statement["statement"]["monthly_statement_number"] = ""

      s = subject.process_daily_statement user, statement, log, "bucket", "path"

      expect(s.status).to eq "F"
      expect(s.received_date).to eq Date.new(2017, 12, 3)
      expect(s.final_received_date).to eq Date.new(2017, 11, 1)
      # The final statement recrods in Kewill do not have monthly statement numbers associated with them...therefore do not blank out the monthly number
      expect(s.monthly_statement_number).to eq "0411P128031"

      expect(s.daily_statement_entries.length).to eq 2

      e = s.daily_statement_entries.first
      expect(e.preliminary_duty_amount).to eq BigDecimal("2")
      expect(e.preliminary_tax_amount).to eq BigDecimal("4")
      expect(e.preliminary_cvd_amount).to eq BigDecimal("6")
      expect(e.preliminary_add_amount).to eq BigDecimal("8")
      expect(e.preliminary_fee_amount).to eq BigDecimal("10")
      expect(e.preliminary_interest_amount).to eq BigDecimal("12")
      expect(e.preliminary_total_amount).to eq BigDecimal("42")

      # The preliminary fields should not have changed on the existing statement entry
      expect(e.duty_amount).to eq BigDecimal("1")
      expect(e.tax_amount).to eq BigDecimal("2")
      expect(e.cvd_amount).to eq BigDecimal("3")
      expect(e.add_amount).to eq BigDecimal("4")
      expect(e.fee_amount).to eq BigDecimal("5")
      expect(e.interest_amount).to eq BigDecimal("6")
      expect(e.total_amount).to eq BigDecimal("21")

      f = e.daily_statement_entry_fees.first

      # Only the final fee should update
      expect(f.preliminary_amount).to eq BigDecimal("15000")
      expect(f.amount).to eq BigDecimal("5")


      #only the final amounts should be updated, since the data from the json marks the entry as final
      expect(s.preliminary_duty_amount).to eq BigDecimal("2")
      expect(s.preliminary_tax_amount).to eq BigDecimal("4")
      expect(s.preliminary_cvd_amount).to eq BigDecimal("6")
      expect(s.preliminary_add_amount).to eq BigDecimal("8")
      expect(s.preliminary_fee_amount).to eq BigDecimal("10")
      expect(s.preliminary_interest_amount).to eq BigDecimal("12")
      expect(s.preliminary_total_amount).to eq BigDecimal("42")

      # Since the data was for a prelim and the statement is marked final, the amounts from the second 
      # statement entry will be blank - ergo only the first statement data is reflected in the sum'ed amounts
      # This is a situation that really should never happen in real life.
      expect(s.duty_amount).to eq BigDecimal("11")
      expect(s.tax_amount).to eq BigDecimal("13")
      expect(s.cvd_amount).to eq BigDecimal("15")
      expect(s.add_amount).to eq BigDecimal("17")
      expect(s.fee_amount).to eq BigDecimal("19")
      expect(s.interest_amount).to eq BigDecimal("21")
      expect(s.total_amount).to eq BigDecimal("96")
    end

    it "raises an error if the statement entry is missing broker reference" do
      statement["statement"]["details"].first["broker_reference"] = ""

      expect { subject.process_daily_statement user, statement, log, "bucket", "path" }.to raise_error "Statement '04118319AQ9' contains a detail without a broker reference number."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Statement '04118319AQ9' contains a detail without a broker reference number."
    end

    it "raises an error if the statement entry fee is missing a code" do
      statement["statement"]["details"].first["fees"].first["code"] = ""

      expect { subject.process_daily_statement user, statement, log, "bucket", "path" }.to raise_error "Statement # '04118319AQ9' / File # '2316567' has a fee line missing a code."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Statement # '04118319AQ9' / File # '2316567' has a fee line missing a code."
    end

    it "skips a statement with stale info" do
      existing_statement
      existing_statement.update_attributes! last_exported_from_source: Time.zone.parse("2018-11-17 17:18:56")

      subject.process_daily_statement user, statement, log, "bucket", "path"

      # Existing statement should not have been updated.
      existing_statement.reload
      expect(existing_statement.last_exported_from_source).to eq Time.zone.parse("2018-11-17 17:18:56")

      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_INFO)[0].message).to eq "Daily statement '04118319AQ9' not updated: file contained outdated info."
    end
  end


  describe "process_monthly_statement" do

    let(:statement) { monthly_statement }

    let!(:daily_statement_1) { DailyStatement.create!(statement_number: "04118319AQ9", preliminary_duty_amount: 20, preliminary_tax_amount: 40, preliminary_cvd_amount: 60, preliminary_add_amount: 80, preliminary_fee_amount: 100, preliminary_interest_amount: 120, preliminary_total_amount: 420,
        duty_amount: 1, tax_amount: 2, cvd_amount: 3, add_amount: 4, fee_amount: 5, interest_amount: 6, total_amount: 21, status: "P", monthly_statement_number: "0411P128031") }
    let!(:daily_statement_2) { DailyStatement.create!(statement_number: "04718318A1H", preliminary_duty_amount: 1, preliminary_tax_amount: 2, preliminary_cvd_amount: 3, preliminary_add_amount: 4, preliminary_fee_amount: 5, preliminary_interest_amount: 6, preliminary_total_amount: 21,
        duty_amount: 2, tax_amount: 4, cvd_amount: 6, add_amount: 8, fee_amount: 10, interest_amount: 12, total_amount: 42, status: "P", monthly_statement_number: "0411P128031") }

    before :each do 
      user
      test_importer
      port
    end

    it "creates a monthly statement" do
      s = subject.process_monthly_statement user, statement, log, "bucket", "file.json"
      s.reload

      expect(s.statement_number).to eq "0411P128031"
      expect(s.status).to eq "P"
      expect(s.importer).to eq test_importer
      expect(s.port_code).to eq "4103"
      expect(s.port).to eq port
      expect(s.pay_type).to eq "7"
      expect(s.received_date).to eq Date.new(2017, 11, 16)
      expect(s.final_received_date).to be_nil
      # Monthly prelims paid date is always nil
      expect(s.paid_date).to be_nil
      expect(s.due_date).to eq Date.new(2017, 11, 17)
      expect(s.final_received_date).to be_nil
      expect(s.last_file_bucket).to eq "bucket"
      expect(s.last_file_path).to eq "file.json"
      expect(s.last_exported_from_source).to eq Time.zone.parse("2017-11-20 21:37:04")

      expect(s.daily_statements.length).to eq 2
      expect(s.daily_statements.map(&:statement_number).sort).to eq ["04118319AQ9", "04718318A1H"]

      expect(s.duty_amount).to eq 3
      expect(s.tax_amount).to eq 6
      expect(s.cvd_amount).to eq 9
      expect(s.add_amount).to eq 12
      expect(s.fee_amount).to eq 15
      expect(s.interest_amount).to eq 18
      expect(s.total_amount).to eq 63

      expect(s.preliminary_duty_amount).to eq 21
      expect(s.preliminary_tax_amount).to eq 42
      expect(s.preliminary_cvd_amount).to eq 63
      expect(s.preliminary_add_amount).to eq 84
      expect(s.preliminary_fee_amount).to eq 105
      expect(s.preliminary_interest_amount).to eq 126
      expect(s.preliminary_total_amount).to eq 441

      expect(s.entity_snapshots.length).to eq 1
      snap = s.entity_snapshots.first
      expect(snap.user).to eq user
      expect(snap.context).to eq "file.json"

      expect(log.company).to be_nil
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_MONTHLY_STATEMENT_NUMBER)[0].value).to eq "0411P128031"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_MONTHLY_STATEMENT_NUMBER)[0].module_type).to eq "MonthlyStatement"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_MONTHLY_STATEMENT_NUMBER)[0].module_id).to eq s.id
    end

    it "updates statement as final" do
      statement["monthly_statement"]["status"] = "F"

      existing = MonthlyStatement.create! statement_number: "0411P128031"

      s = subject.process_monthly_statement user, statement, log, "bucket", "file.json"
      s.reload

      expect(s).to eq existing

      expect(s.statement_number).to eq "0411P128031"
      expect(s.status).to eq "F"
      expect(s.importer).to eq test_importer
      expect(s.port_code).to eq "4103"
      expect(s.port).to eq port
      expect(s.pay_type).to eq "7"
      expect(s.received_date).to be_nil
      expect(s.final_received_date).to eq Date.new(2017, 11, 16)
      expect(s.paid_date).to eq Date.new(2017, 11, 18)
      expect(s.due_date).to eq Date.new(2017, 11, 17)
      expect(s.last_file_bucket).to eq "bucket"
      expect(s.last_file_path).to eq "file.json"
      expect(s.last_exported_from_source).to eq Time.zone.parse("2017-11-20 21:37:04")
      expect(s.customer_number).to eq "TEST"
    end

    it "skips a statement with stale info" do
      existing = MonthlyStatement.create! statement_number: "0411P128031", last_exported_from_source: Time.zone.parse("2018-11-17 17:18:56")

      subject.process_monthly_statement user, statement, log, "bucket", "file.json"

      # Existing statement should not have been updated.
      existing.reload
      expect(existing.last_exported_from_source).to eq Time.zone.parse("2018-11-17 17:18:56")

      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_INFO)[0].message).to eq "Monthly statement '0411P128031' not updated: file contained outdated info."
    end
  end

  describe "parse_file" do
    subject { described_class }

    let (:document) {
      {
        "daily_statements" => [
          daily_statement
        ],
        "monthly_statements" => [
          monthly_statement
        ]}
    }

    let (:json) {
      document.to_json
    }

    it "parses daily and monthly statements from the json file" do
      subject.parse_file json, log, {bucket: "bucket", key: "file.json"}

      expect(DailyStatement.where(statement_number: "04118319AQ9").first).not_to be_nil
      expect(MonthlyStatement.where(statement_number: "0411P128031").first).not_to be_nil
    end
  end
end