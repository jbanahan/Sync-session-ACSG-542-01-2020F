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
      @h.should_receive(:read_check_register).with(@check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      @h.should_receive(:read_invoices).with(@invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      @h.should_receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::SqlProxyClient).and_return check_results
      @h.should_receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::SqlProxyClient).and_return invoice_results

      @h.should_receive(:wait_for_export_updates).with check_results[:exports] + invoice_results[:exports]
      @h.should_receive(:wait_for_dimension_uploads)
      @h.should_receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher))
      @h.should_receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email]).and_return 0

      @h.process user

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "Day End Processing Complete"
      expect(m.body).to eq "Day End Processing has completed.<br>AR Total: $20.00<br>AP Total: $10.00<br>Check Total: $10.00"
      @check_file.reload
      @invoice_file.reload
      expect(@check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(@invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(@check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(@invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "handles parsing errors" do
      user = Factory(:user, time_zone: "Hawaii")
      @h.should_receive(:read_check_register).with(@check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [["Check Error"], nil]
      @h.should_receive(:read_invoices).with(@invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [["Invoice Error"], nil]

      @h.should_receive(:send_parser_errors).with(@check_file.attached_file_name, ["Check Error"], @invoice_file.attached_file_name, ["Invoice Error"], [user.email], Time.zone.now.in_time_zone("Hawaii").to_date)

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
      @h.should_receive(:read_check_register).with(@check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      @h.should_receive(:read_invoices).with(@invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      @h.should_receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::SqlProxyClient).and_return check_results
      @h.should_receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::SqlProxyClient).and_return invoice_results

      @h.should_receive(:wait_for_export_updates).with check_results[:exports] + invoice_results[:exports]
      @h.should_receive(:wait_for_dimension_uploads)
      @h.should_receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher))
      @h.should_receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email]).and_return 2

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

    it "uses users in accounting group if no user is given" do
      g = Group.create! system_code: 'intacct-accounting'
      user = Factory(:user)
      user.groups << g

      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      @h.should_receive(:read_check_register).with(@check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      @h.should_receive(:read_invoices).with(@invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      @h.should_receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::SqlProxyClient).and_return check_results
      @h.should_receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::SqlProxyClient).and_return invoice_results

      @h.should_receive(:wait_for_export_updates).with check_results[:exports] + invoice_results[:exports]
      @h.should_receive(:wait_for_dimension_uploads)
      @h.should_receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher))
      @h.should_receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email]).and_return 2

      @h.process

      expect(user.messages.first).not_to be_nil
    end
  end

  describe "can_view?" do
    it "allows only people in accounting group to view" do
      ms = MasterSetup.new system_code: 'www-vfitrack-net'
      MasterSetup.stub(:get).and_return ms
      g = Group.create! system_code: 'intacct-accounting'
      user = Factory(:user)
      user.groups << g
      expect(described_class.can_view?(user)).to be_true
      expect(described_class.can_view?(Factory(:user, username: "yada-yada"))).to be_false
    end

    it "disallows access from other systems" do
      ms = MasterSetup.new system_code: 'other'
      MasterSetup.stub(:get).and_return ms
      g = Group.create! system_code: 'intacct-accounting'
      user = Factory(:user)
      user.groups << g
      expect(described_class.can_view?(user)).to be_false
    end
  end

  describe "read_invoices" do
    it "downloads custom file reads and validates the data" do
      cf = double
      cf.should_receive(:attached).and_return cf
      cf.should_receive(:path).and_return "path"
      io = double

      OpenChain::S3.should_receive(:download_to_tempfile).with(OpenChain::S3.bucket_name(:production), "path").and_yield io

      parser = double
      info = {ar_grand_total: 0, ap_grand_total: 0, info: []}
      parser.should_receive(:extract_invoices).with(io).and_return info
      parser.should_receive(:validate_invoice_data).with(info).and_return ["Errors"]

      errors, inv_info = described_class.new(nil, nil).read_invoices cf, parser
      expect(errors).to eq ["Errors"]
      expect(inv_info).to eq({info: []})
    end
  end

  describe "read_check_register" do
    it "downloads custom file reads and validates the data" do
      cf = double
      cf.should_receive(:attached).and_return cf
      cf.should_receive(:path).and_return "path"
      io = double

      OpenChain::S3.should_receive(:download_to_tempfile).with(OpenChain::S3.bucket_name(:production), "path").and_yield io

      parser = double
      info = {checks: []}
      parser.should_receive(:extract_check_info).with(io).and_return info
      parser.should_receive(:validate_check_info).with(info).and_return ["Errors"]

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
      check.stub(:intacct_alliance_export).and_return "export"

      check2 = double
      check2.stub(:intacct_alliance_export).and_return "export2"

      parser.should_receive(:create_and_request_check).with(info_1, sql_proxy_client).and_return [check, ["Error 1", "Error 2"]]
      parser.should_receive(:create_and_request_check).with(info_2, sql_proxy_client).and_return [check2, ["Error 3", "Error 4"]]

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
      parser.should_receive(:create_and_request_invoice).with("info", proxy).and_return ["export", ["Error 1", "Error 2"]]
      parser.should_receive(:create_and_request_invoice).with("info2", proxy).and_return [nil, ["Error 3", "Error 4"]]

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
      h.stub(:all_exports_finished?).with([export.id, export2.id]).and_return false

      t = Thread.new {
        h.wait_for_export_updates [export, export2], 1, 5
      }
      started = Time.zone.now.to_i

      sleep 1
      # Make sure the thread is still sleeping
      expect(t).to be_alive
      h.stub(:all_exports_finished?).with([export.id, export2.id]).and_return true
      t.join(2)
      stopped = Time.zone.now.to_i
      expect(stopped - started).not_to be > 6
    end

    it "raises an error if too much time has passed" do
      export = IntacctAllianceExport.create! data_received_date: Time.zone.now
      export2 = IntacctAllianceExport.create!
      h = described_class.new(nil, nil)
      h.stub(:all_exports_finished?).with([export.id, export2.id]).and_return false
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
      h.stub(:all_dimension_uploads_finished?).and_return false

      t = Thread.new {
        h.wait_for_dimension_uploads 1, 5
      }
      started = Time.zone.now.to_i

      sleep 1
      # Make sure the thread is still sleeping
      expect(t).to be_alive
      h.stub(:all_dimension_uploads_finished?).and_return true
      t.join(2)
      stopped = Time.zone.now.to_i
      expect(stopped - started).not_to be > 6
    end

    it "raises an error if too much time has passed" do 
      h = described_class.new(nil, nil)
      h.stub(:all_dimension_uploads_finished?).and_return false

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
      expect(h.all_exports_finished?([export.id, export2.id])).to be_false

      export2.update_attributes! data_received_date: Time.zone.now
      expect(h.all_exports_finished?([export.id, export2.id])).to be_true
    end
  end

  describe "all_dimension_uploads_finished?" do
    it "returns true if all dimension upload delayed jobs are finished" do
      h = described_class.new(nil, nil)
      job = Delayed::Job.new
      job.handler = "method_name: :async_send_dimension"
      job.save!
      expect(h.all_dimension_uploads_finished?).to be_false
      job.handler = ""
      job.save!

      expect(h.all_dimension_uploads_finished?).to be_true
    end
  end

  describe "process_delayed" do
    it "finds referenced custom files and user and calls process" do
      cf1 = CustomFile.create! 
      cf2 = CustomFile.create!
      u = Factory(:user)

      described_class.any_instance.should_receive(:process).with u
      described_class.process_delayed cf1.id, cf2.id, u.id
    end

    it "accepts nil for user" do
      cf1 = CustomFile.create! 
      cf2 = CustomFile.create!

      described_class.any_instance.should_receive(:process).with nil
      described_class.process_delayed cf1.id, cf2.id, nil
    end
  end
end