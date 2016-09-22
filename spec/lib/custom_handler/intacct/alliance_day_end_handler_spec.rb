require 'spec_helper'

describe OpenChain::CustomHandler::Intacct::AllianceDayEndHandler do

  # A lot of this spec is mocked out since this is mostly like a controller class that's 
  # just handling off datasets between different subsystems that do the heavy lifting.

  describe "process" do
    before :each do
      @invoice_file = CustomFile.create! attached_file_name: "invoice_file.txt"
      @check_file = CustomFile.create! attached_file_name: "check_file.txt"

      @h = described_class.new @check_file, @invoice_file
    end

    it "reads custom files, generates sql proxy requests, kicks off upload, reports errors" do
      user = Factory(:user)
      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      expect(@h).to receive(:read_check_register).with(@check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(@h).to receive(:read_invoices).with(@invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      expect(@h).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(@h).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      expect(@h).to receive(:wait_for_export_updates).with check_results[:exports] + invoice_results[:exports]
      expect(@h).to receive(:wait_for_dimension_uploads)
      expect(@h).to receive(:validate_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 10, 20, 10).and_return({})
      expect(@h).to receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher))
      expect(@h).to receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email]).and_return 0

      @h.process user

      # No messages are generated if everything is good w/ the load
      m = user.messages.first
      @check_file.reload
      @invoice_file.reload
      expect(@check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(@invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(@check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(@invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "handles parsing errors" do
      user = Factory(:user, time_zone: "Hawaii")
      expect(@h).to receive(:read_check_register).with(@check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [["Check Error"], nil]
      expect(@h).to receive(:read_invoices).with(@invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [["Invoice Error"], nil]

      expect(@h).to receive(:send_parser_errors).with(@check_file.attached_file_name, ["Check Error"], @invoice_file.attached_file_name, ["Invoice Error"], [user.email], Time.zone.now.in_time_zone("America/New_York").to_date)

      @h.process user

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "Day End Processing Complete With Errors"
      expect(m.body).to eq "The day end files could not be processed.  A separate report containing the errors will be mailed to you."
      @check_file.reload
      @invoice_file.reload
      expect(@check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(@invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(@check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(@invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "handles upload errors" do
      user = Factory(:user)
      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      expect(@h).to receive(:read_check_register).with(@check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(@h).to receive(:read_invoices).with(@invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      expect(@h).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(@h).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      expect(@h).to receive(:wait_for_export_updates).with check_results[:exports] + invoice_results[:exports]
      expect(@h).to receive(:wait_for_dimension_uploads)
      expect(@h).to receive(:validate_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 10, 20, 10).and_return({})
      expect(@h).to receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher))
      expect(@h).to receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email]).and_return 2

      @h.process user

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "Day End Processing Complete With Errors"
      expect(m.body).to eq "Day End Processing has completed.<br>AR Total: $20.00<br>AP Total: $10.00<br>Check Total: $10.00<br>2 errors were encountered.  A separate report containing errors will be mailed to you."
      @check_file.reload
      @invoice_file.reload
      expect(@check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(@invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(@check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(@invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "handles invalid amount errors" do
      user = Factory(:user, time_zone: "Hawaii")
      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      expect(@h).to receive(:read_check_register).with(@check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(@h).to receive(:read_invoices).with(@invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      expect(@h).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(@h).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      expect(@h).to receive(:wait_for_export_updates).with check_results[:exports] + invoice_results[:exports]
      expect(@h).to receive(:wait_for_dimension_uploads)
      expect(@h).to receive(:validate_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 10, 20, 10).and_return({checks: ["Error", "Error"], invoices: ["Error", "Error"]})
      
      @h.process user

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "Day End Processing Complete With Errors"
      expect(m.body).to eq "Day End Processing has completed.<br>AR Total: $20.00<br>AP Total: $10.00<br>Check Total: $10.00<br>4 errors were encountered.  A separate report containing errors will be mailed to you."
      @check_file.reload
      @invoice_file.reload
      expect(@check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(@invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(@check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(@invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "uses users in accounting group if no user is given" do
      g = Factory(:group, system_code: 'intacct-accounting')
      user = Factory(:user)
      user.groups << g

      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      expect(@h).to receive(:read_check_register).with(@check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(@h).to receive(:read_invoices).with(@invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      expect(@h).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(@h).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      expect(@h).to receive(:wait_for_export_updates).with check_results[:exports] + invoice_results[:exports]
      expect(@h).to receive(:wait_for_dimension_uploads)
      expect(@h).to receive(:validate_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 10, 20, 10).and_return({})
      expect(@h).to receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher))
      expect(@h).to receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email]).and_return 2

      @h.process

      expect(user.messages.first).not_to be_nil
    end
  end

  describe "can_view?" do
    it "allows only people in accounting group to view" do
      ms = MasterSetup.new system_code: 'www-vfitrack-net'
      allow(MasterSetup).to receive(:get).and_return ms
      g = Factory(:group, system_code: 'intacct-accounting')
      user = Factory(:user)
      user.groups << g
      expect(described_class.can_view?(user)).to be_truthy
      expect(described_class.can_view?(Factory(:user, username: "yada-yada"))).to be_falsey
    end

    it "disallows access from other systems" do
      ms = MasterSetup.new system_code: 'other'
      allow(MasterSetup).to receive(:get).and_return ms
      g = Factory(:group, system_code: 'intacct-accounting')
      user = Factory(:user)
      user.groups << g
      expect(described_class.can_view?(user)).to be_falsey
    end
  end

  describe "read_invoices" do
    it "downloads custom file reads and validates the data" do
      cf = double
      expect(cf).to receive(:attached).and_return cf
      expect(cf).to receive(:path).and_return "path"
      io = double

      expect(OpenChain::S3).to receive(:download_to_tempfile).with(OpenChain::S3.bucket_name(:production), "path").and_yield io

      parser = double
      info = {ar_grand_total: 0, ap_grand_total: 0, info: []}
      expect(parser).to receive(:extract_invoices).with(io).and_return info
      expect(parser).to receive(:validate_invoice_data).with(info).and_return ["Errors"]

      errors, inv_info = described_class.new(nil, nil).read_invoices cf, parser
      expect(errors).to eq ["Errors"]
      expect(inv_info).to eq({info: []})
    end
  end

  describe "read_check_register" do
    it "downloads custom file reads and validates the data" do
      cf = double
      expect(cf).to receive(:attached).and_return cf
      expect(cf).to receive(:path).and_return "path"
      io = double

      expect(OpenChain::S3).to receive(:download_to_tempfile).with(OpenChain::S3.bucket_name(:production), "path").and_yield io

      parser = double
      info = {checks: []}
      expect(parser).to receive(:extract_check_info).with(io).and_return info
      expect(parser).to receive(:validate_check_info).with(info).and_return ["Errors"]

      errors, inv_info = described_class.new(nil, nil).read_check_register cf, parser
      expect(errors).to eq ["Errors"]
      expect(inv_info).to eq info
    end
  end

  describe "send_parser_errors" do
    it "puts errors into spreadsheet and emails them" do
      described_class.new(nil, nil).send_parser_errors "check_name", ["E1", "E2"], "invoice_name", ["IE", "IE2"], ["me@there.com"], Date.new(2014, 11, 1)

      mail = ActionMailer::Base.deliveries.pop
      expect(mail).not_to be_nil
      expect(mail.to).to eq ["me@there.com"]
      expect(mail.subject).to eq "Alliance Day End Errors"
      expect(mail.body.raw_source).to include "Errors were encountered while attempting to read the Alliance Day end files.<br>"
      expect(mail.body.raw_source).to include 'Found 2 errors in the Check Register File check_name.<br'
      expect(mail.body.raw_source).to include 'Found 2 errors in the Invoice File invoice_name.<br>'
      attachment = mail.attachments["Day End Errors 2014-11-01.xls"]
      wb = Spreadsheet.open(StringIO.new(attachment.read))
      sheet = wb.worksheet "Check Register Errors"
      expect(sheet.row(0)).to eq ["Error"]
      expect(sheet.row(1)).to eq ["E1"]
      expect(sheet.row(2)).to eq ["E2"]

      sheet = wb.worksheet "Invoice Errors"
      expect(sheet.row(0)).to eq ["Error"]
      expect(sheet.row(1)).to eq ["IE"]
      expect(sheet.row(2)).to eq ["IE2"]
    end
  end

  describe "create_checks" do
    it "calls create checks on the parser and collects errors and export objects returned by the parser" do
      parser = double
      sql_proxy_client = double
      info_1 = "info1"
      info_2 = "info2"

      check = double
      allow(check).to receive(:intacct_alliance_export).and_return "export"

      check2 = double
      allow(check2).to receive(:intacct_alliance_export).and_return "export2"

      expect(parser).to receive(:create_and_request_check).with(info_1, sql_proxy_client).and_return [check, ["Error 1", "Error 2"]]
      expect(parser).to receive(:create_and_request_check).with(info_2, sql_proxy_client).and_return [check2, ["Error 3", "Error 4"]]

      check_info = {checks: {
        "1" => {checks: [info_1]},
        "2" => {checks: [info_2]}
      }}

      output = described_class.new(nil, nil).create_checks check_info, parser, sql_proxy_client
      expect(output[:errors]).to eq ["Error 1", "Error 2", "Error 3", "Error 4"]
      expect(output[:exports]).to eq ["export", "export2"]
    end
  end

  describe "create_invoices" do
    it "creates and validates invoices" do
      invoices = {
        "inv1" => "info",
        "inv2" => "info2"
      }

      parser = double
      proxy = double
      expect(parser).to receive(:create_and_request_invoice).with("info", proxy).and_return ["export", ["Error 1", "Error 2"]]
      expect(parser).to receive(:create_and_request_invoice).with("info2", proxy).and_return [nil, ["Error 3", "Error 4"]]

      output = described_class.new(nil, nil).create_invoices invoices, parser, proxy
      expect(output[:errors]).to eq ["Error 1", "Error 2", "Error 3", "Error 4"]
      expect(output[:exports]).to eq ["export"]
    end
  end

  describe "wait_for_export_updates" do
    it 'waits for alliance exports to all get updated' do
      export = IntacctAllianceExport.create! data_received_date: Time.zone.now
      export2 = IntacctAllianceExport.create! 

      h = described_class.new(nil, nil)
      allow(h).to receive(:all_exports_finished?).with([export.id, export2.id]).and_return false

      t = Thread.new {
        h.wait_for_export_updates [export, export2], 1, 5
      }
      started = Time.zone.now.to_i

      sleep 1
      # Make sure the thread is still sleeping
      expect(t).to be_alive
      allow(h).to receive(:all_exports_finished?).with([export.id, export2.id]).and_return true
      t.join(2)
      stopped = Time.zone.now.to_i
      expect(stopped - started).not_to be > 6
    end

    it "raises an error if too much time has passed" do
      export = IntacctAllianceExport.create! data_received_date: Time.zone.now
      export2 = IntacctAllianceExport.create!
      h = described_class.new(nil, nil)
      allow(h).to receive(:all_exports_finished?).with([export.id, export2.id]).and_return false
      error = nil
      t = Thread.new {
        begin
          h.wait_for_export_updates [export, export2], 1, 2
        rescue => e
          error = e
        end
      }
      t.join(3)
      
      expect(t).not_to be_alive
      expect(error).not_to be_nil
    end
  end

  describe "wait_for_dimension_uploads" do
    it "waits for intacct dimension uploads to finish" do
      h = described_class.new(nil, nil)
      allow(h).to receive(:all_dimension_uploads_finished?).and_return false

      t = Thread.new {
        h.wait_for_dimension_uploads 1, 5
      }
      started = Time.zone.now.to_i

      sleep 1
      # Make sure the thread is still sleeping
      expect(t).to be_alive
      allow(h).to receive(:all_dimension_uploads_finished?).and_return true
      t.join(2)
      stopped = Time.zone.now.to_i
      expect(stopped - started).not_to be > 6
    end

    it "raises an error if too much time has passed" do 
      h = described_class.new(nil, nil)
      allow(h).to receive(:all_dimension_uploads_finished?).and_return false

      error = nil
      t = Thread.new {
        begin
          h.wait_for_dimension_uploads 1, 2
        rescue => e
          error = e
        end
      }
      t.join(3)
      expect(t).not_to be_alive
      expect(error).not_to be_nil
    end
  end

  describe "all_exports_finished?" do
    it "returns true if there are no exports waiting to receive data" do
      h = described_class.new(nil, nil)
      export = IntacctAllianceExport.create! data_received_date: Time.zone.now
      export2 = IntacctAllianceExport.create!
      expect(h.all_exports_finished?([export.id, export2.id])).to be_falsey

      export2.update_attributes! data_received_date: Time.zone.now
      expect(h.all_exports_finished?([export.id, export2.id])).to be_truthy
    end
  end

  describe "all_dimension_uploads_finished?" do
    it "returns true if all dimension upload delayed jobs are finished" do
      h = described_class.new(nil, nil)
      job = Delayed::Job.new
      job.handler = "method_name: :async_send_dimension"
      job.save!
      expect(h.all_dimension_uploads_finished?).to be_falsey
      job.handler = ""
      job.save!

      expect(h.all_dimension_uploads_finished?).to be_truthy
    end
  end

  describe "process_delayed" do
    it "finds referenced custom files and user and calls process" do
      cf1 = CustomFile.create! 
      cf2 = CustomFile.create!
      u = Factory(:user)

      expect_any_instance_of(described_class).to receive(:process).with u
      described_class.process_delayed cf1.id, cf2.id, u.id
    end

    it "accepts nil for user" do
      cf1 = CustomFile.create! 
      cf2 = CustomFile.create!

      expect_any_instance_of(described_class).to receive(:process).with nil
      described_class.process_delayed cf1.id, cf2.id, nil
    end
  end

  describe "validate_export_amounts_received" do
    it "ensures the expected amounts were received" do
      check_export = IntacctAllianceExport.create! ap_total: 10, export_type: 'check', data_received_date: Time.zone.now
      check = IntacctCheck.create! intacct_alliance_export: check_export, amount: 10

      invoice_export = IntacctAllianceExport.create! ap_total: 20, ar_total: 30, export_type: 'invoice', data_received_date: Time.zone.now
      receivable = IntacctReceivable.create! company: 'vfc', intacct_alliance_export: invoice_export
      receivable_line = IntacctReceivableLine.create! amount: 50, intacct_receivable: receivable

      # Create a credit so we know we're handling the sign reversal (credit amounts are stored as positive values internally for Intacct's sake)
      credit_receivable = IntacctReceivable.create! company: 'vfc', receivable_type: 'Credit Note', intacct_alliance_export: invoice_export
      credit_receivable_line = IntacctReceivableLine.create! amount: 20, intacct_receivable: credit_receivable

      # The amount from this receivable should be skipped, since it's something that is not in the invoice report, 
      # we generate it out of thin air for an internal billing process
      lmd_receivable_from_vfi = IntacctReceivable.create! company: 'lmd', customer_number: "VANDE", intacct_alliance_export: invoice_export
      lmd_receivable_from_vfi_line = IntacctReceivableLine.create! amount: 100, intacct_receivable: lmd_receivable_from_vfi

      payable = IntacctPayable.create! company: 'lmd', intacct_alliance_export: invoice_export
      payable_line = IntacctPayableLine.create! amount: 20, intacct_payable: payable

      # This payable should be skipped, since it's something that is not in the invoice report, 
      # we generate it out of thin air for an internal billing process
      vfi_to_lmd_payable = IntacctPayable.create! company: 'vfc', vendor_number: "LMD", intacct_alliance_export: invoice_export
      vfi_to_lmd_payable_line = IntacctPayableLine.create! amount: 50, intacct_payable: vfi_to_lmd_payable

      errors = described_class.new(nil, nil).send(:validate_export_amounts_received, Time.zone.now() - 5.minutes, 10, 30, 20)
      expect(errors.size).to eq 0
    end

    it "returns errors if unexpected values are returned" do
      errors = described_class.new(nil, nil).send(:validate_export_amounts_received, Time.zone.now() - 5.minutes, 10, 30, 20)
      expect(errors.values.flatten.size).to eq 3

      expect(errors[:checks]).to eq ["Expected to retrieve $10.00 in Check data from Alliance.  Received $0.00 instead."]
      expect(errors[:invoices]).to eq ["Expected to retrieve $30.00 in AR lines from Alliance.  Received $0.00 instead.", "Expected to retrieve $20.00 in AP lines from Alliance.  Received $0.00 instead."]
    end
  end
end