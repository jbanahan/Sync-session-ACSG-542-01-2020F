describe OpenChain::CustomHandler::Intacct::AllianceDayEndHandler do

  # A lot of this spec is mocked out since this is mostly like a controller class that's
  # just handling off datasets between different subsystems that do the heavy lifting.

  describe "process" do
    let (:invoice_file) { CustomFile.create! attached_file_name: "invoice_file.txt" }
    let (:check_file) { CustomFile.create! attached_file_name: "check_file.txt" }

    it "reads custom files, generates sql proxy requests, kicks off upload" do
      user = FactoryBot(:user, email: "st-hubbins@hellhole.co.uk")
      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      expect(subject).to receive(:read_check_register).with(check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(subject).to receive(:read_invoices).with(invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      expect(subject).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(subject).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      expect(subject).to receive(:wait_for_export_updates).with [user], check_results[:exports] + invoice_results[:exports]
      expect(subject).to receive(:wait_for_dimension_uploads)
      expect(subject).to receive(:validate_check_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 10).and_return({})
      expect(subject).to receive(:validate_ar_ap_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 20, 10).and_return({})
      expect(subject).to receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher), checks_only: false, invoices_only: false)
      expect(subject).to receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email]).and_return 0

      subject.process check_file, invoice_file, user

      m = user.messages.first
      expect(m).to be_nil

      expect(ActionMailer::Base.deliveries.count).to eq 1

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["st-hubbins@hellhole.co.uk"]
      expect(mail.subject).to eq "Day End Processing Complete"
      expect(mail.body.raw_source).to match(/Day End Processing has completed./)

      check_file.reload
      invoice_file.reload
      expect(check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "reports errors for checks that have already been sent" do
      user = FactoryBot(:user, email: "st-hubbins@hellhole.co.uk")
      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      expect(subject).to receive(:read_check_register).with(check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(subject).to receive(:read_invoices).with(invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)], errors: ["Check # 1234 for $500.00"]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      expect(subject).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(subject).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      subject.process check_file, invoice_file, user

      expect(ActionMailer::Base.deliveries.count).to eq 1

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["st-hubbins@hellhole.co.uk", described_class::ERROR_EMAIL]
      expect(mail.subject).to eq "Error creating Intacct-Alliance check(s)"
      expect(mail.body.raw_source).to match(/The following checks have already been sent to Intacct/)
      expect(mail.body.raw_source).to match(/Check # 1234 for \$500.00/)

      check_file.reload
      invoice_file.reload
      expect(check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "reports errors for invoices that have already been sent" do
      user = FactoryBot(:user, email: "st-hubbins@hellhole.co.uk")
      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      expect(subject).to receive(:read_check_register).with(check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(subject).to receive(:read_invoices).with(invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)], errors: ["An invoice error for File # 123"]}

      expect(subject).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(subject).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      subject.process check_file, invoice_file, user

      expect(ActionMailer::Base.deliveries.count).to eq 1

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["st-hubbins@hellhole.co.uk", described_class::ERROR_EMAIL]
      expect(mail.subject).to eq "Error creating Intacct-Alliance invoice(s)"
      expect(mail.body.raw_source).to match(/The following invoices have already been sent to Intacct/)
      expect(mail.body.raw_source).to match(/An invoice error for File # 123/)

      check_file.reload
      invoice_file.reload
      expect(check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "handles parsing errors" do
      user = FactoryBot(:user, time_zone: "Hawaii")
      expect(subject).to receive(:read_check_register).with(check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [["Check Error"], nil]
      expect(subject).to receive(:read_invoices).with(invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [["Invoice Error"], nil]

      expect(subject).to receive(:send_parser_errors).with(check_file.attached_file_name, ["Check Error"], invoice_file.attached_file_name, ["Invoice Error"], [user.email], Time.zone.now.in_time_zone("America/New_York").to_date)

      subject.process check_file, invoice_file, user

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "Day End Processing Complete With Errors"
      expect(m.body).to eq "The day end files could not be processed.  A separate report containing the errors will be mailed to you."
      check_file.reload
      invoice_file.reload
      expect(check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "handles upload errors" do
      group = FactoryBot(:group, system_code: "intacct-accounting")
      user = FactoryBot(:user)
      user.groups << group
      user_2 = FactoryBot(:user)
      user_2.groups << group

      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      expect(subject).to receive(:read_check_register).with(check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(subject).to receive(:read_invoices).with(invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      expect(subject).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(subject).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      expect(subject).to receive(:wait_for_export_updates).with [user, user_2], check_results[:exports] + invoice_results[:exports]
      expect(subject).to receive(:wait_for_dimension_uploads)
      expect(subject).to receive(:validate_check_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 10).and_return({})
      expect(subject).to receive(:validate_ar_ap_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 20, 10).and_return({})
      expect(subject).to receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher), checks_only: false, invoices_only: false)
      expect(subject).to receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email, user_2.email]).and_return 2

      subject.process check_file, invoice_file, user

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "Day End Processing Complete With Errors"
      expect(m.body).to eq "Day End Processing has completed.<br>AR Total: $20.00<br>AP Total: $10.00<br>Check Total: $10.00<br>2 errors were encountered.  A separate report containing errors will be mailed to you."
      check_file.reload
      invoice_file.reload
      expect(check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "handles invalid amount errors" do
      user = FactoryBot(:user, time_zone: "Hawaii")
      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      expect(subject).to receive(:read_check_register).with(check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(subject).to receive(:read_invoices).with(invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      expect(subject).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(subject).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      expect(subject).to receive(:wait_for_export_updates).with [user], check_results[:exports] + invoice_results[:exports]
      expect(subject).to receive(:wait_for_dimension_uploads)
      expect(subject).to receive(:validate_check_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 10).and_return({checks: ["Error", "Error"]})
      expect(subject).to receive(:validate_ar_ap_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 20, 10).and_return({invoices: ["Error", "Error"]})

      subject.process check_file, invoice_file, user

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "Day End Processing Complete With Errors"
      expect(m.body).to eq "Day End Processing has completed.<br>AR Total: $20.00<br>AP Total: $10.00<br>Check Total: $10.00<br>4 errors were encountered.  A separate report containing errors will be mailed to you."
      check_file.reload
      invoice_file.reload
      expect(check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(check_file.finish_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "uses users in accounting group if no user is given" do
      g = FactoryBot(:group, system_code: 'intacct-accounting')
      user = FactoryBot(:user)
      user.groups << g

      check_info = {checks: ""}
      invoice_info = {invoices: ""}
      expect(subject).to receive(:read_check_register).with(check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(subject).to receive(:read_invoices).with(invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}

      expect(subject).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(subject).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      expect(subject).to receive(:wait_for_export_updates).with [user], check_results[:exports] + invoice_results[:exports]
      expect(subject).to receive(:wait_for_dimension_uploads)
      expect(subject).to receive(:validate_check_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 10).and_return({})
      expect(subject).to receive(:validate_ar_ap_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 20, 10).and_return({})
      expect(subject).to receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher), checks_only: false, invoices_only: false)
      expect(subject).to receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email]).and_return 2

      subject.process check_file, invoice_file

      expect(user.messages.first).not_to be_nil
    end

    it "processes check file only if missing invoice file" do
      user = FactoryBot(:user, email: "st-hubbins@hellhole.co.uk")
      check_info = {checks: ""}
      expect(subject).to receive(:read_check_register).with(check_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser)).and_return [[], check_info]
      expect(subject).not_to receive(:read_invoices)

      check_results = {exports: [IntacctAllianceExport.new(ap_total: 10)]}
      expect(subject).to receive(:create_checks).with(check_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser), OpenChain::KewillSqlProxyClient).and_return check_results
      expect(subject).not_to receive(:create_invoices)

      expect(subject).to receive(:wait_for_export_updates).with [user], check_results[:exports]
      expect(subject).to receive(:wait_for_dimension_uploads)
      expect(subject).to receive(:validate_check_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 10).and_return({})
      expect(subject).not_to receive(:validate_ar_ap_export_amounts_received)
      expect(subject).to receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher), checks_only: true, invoices_only: false)
      expect(subject).to receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email]).and_return 0

      subject.process check_file, nil, user

      m = user.messages.first
      expect(m).to be_nil

      expect(ActionMailer::Base.deliveries.count).to eq 1

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["st-hubbins@hellhole.co.uk"]
      expect(mail.subject).to eq "Day End Processing Complete"
      expect(mail.body.raw_source).to match(/Day End Processing has completed./)

      check_file.reload
      expect(check_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(check_file.finish_at.to_date).to eq Time.zone.now.to_date
    end

    it "processes invoice file only if missing check file" do
      user = FactoryBot(:user, email: "st-hubbins@hellhole.co.uk")
      invoice_info = {invoices: ""}
      expect(subject).not_to receive(:read_check_register)
      expect(subject).to receive(:read_invoices).with(invoice_file, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser)).and_return [[], invoice_info]

      invoice_results = {exports: [IntacctAllianceExport.new(ap_total: 10, ar_total: 20)]}
      expect(subject).not_to receive(:create_checks)
      expect(subject).to receive(:create_invoices).with(invoice_info, instance_of(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser), OpenChain::KewillSqlProxyClient).and_return invoice_results

      expect(subject).to receive(:wait_for_export_updates).with [user], invoice_results[:exports]
      expect(subject).to receive(:wait_for_dimension_uploads)
      expect(subject).not_to receive(:validate_check_export_amounts_received)
      expect(subject).to receive(:validate_ar_ap_export_amounts_received).with(instance_of(ActiveSupport::TimeWithZone), 20, 10).and_return({})
      expect(subject).to receive(:upload_intacct_data).with(instance_of(OpenChain::CustomHandler::Intacct::IntacctDataPusher), checks_only: false, invoices_only: true)
      expect(subject).to receive(:run_exception_report).with(instance_of(OpenChain::Report::IntacctExceptionReport), [user.email]).and_return 0

      subject.process nil, invoice_file, user

      m = user.messages.first
      expect(m).to be_nil

      expect(ActionMailer::Base.deliveries.count).to eq 1

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["st-hubbins@hellhole.co.uk"]
      expect(mail.subject).to eq "Day End Processing Complete"
      expect(mail.body.raw_source).to match(/Day End Processing has completed./)

      invoice_file.reload
      expect(invoice_file.start_at.to_date).to eq Time.zone.now.to_date
      expect(invoice_file.finish_at.to_date).to eq Time.zone.now.to_date
    end
  end

  describe "can_view?" do
    let (:user) { User.new }

    it "uses intaccter errors controller to determine if user can view" do
      expect(IntacctErrorsController).to receive(:allowed_user?).with(user).and_return true
      expect(described_class.can_view?(user)).to eq true
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

      errors, inv_info = subject.read_invoices cf, parser
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
      expect(parser).to receive(:validate_and_remove_duplicate_check_references).with(info).and_return ["More Errors"]

      errors, inv_info = subject.read_check_register cf, parser
      expect(errors).to eq ["Errors", "More Errors"]
      expect(inv_info).to eq info
    end
  end

  describe "send_parser_errors" do
    it "puts errors into spreadsheet and emails them" do
      subject.send_parser_errors "check_name", ["E1", "E2"], "invoice_name", ["IE", "IE2"], ["me@there.com"], Date.new(2014, 11, 1)

      mail = ActionMailer::Base.deliveries.pop
      expect(mail).not_to be_nil
      expect(mail.to).to eq ["me@there.com", described_class::ERROR_EMAIL]
      expect(mail.subject).to eq "Alliance Day End Errors"
      expect(mail.body.raw_source).to include "Errors were encountered while attempting to read the Alliance Day end files.<br>"
      expect(mail.body.raw_source).to include 'Found 2 errors in the Check Register File check_name.<br'
      expect(mail.body.raw_source).to include 'Found 2 errors in the Invoice File invoice_name.<br>'
      attachment = mail.attachments["Day End Errors 2014-11-01.xlsx"]

      xlsx = XlsxTestReader.new StringIO.new(attachment.read)

      errors = xlsx.raw_data "Check Register Errors"

      expect(errors[0]).to eq ["Error"]
      expect(errors[1]).to eq ["E1"]
      expect(errors[2]).to eq ["E2"]

      errors = xlsx.raw_data "Invoice Errors"

      expect(errors[0]).to eq ["Error"]
      expect(errors[1]).to eq ["IE"]
      expect(errors[2]).to eq ["IE2"]
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

      output = subject.create_checks check_info, parser, sql_proxy_client
      expect(output[:errors]).to eq ["Error 1", "Error 2", "Error 3", "Error 4"]
      expect(output[:exports]).to eq ["export", "export2"]
    end

    it "handles situations where no checks were loaded" do
      expect(subject.create_checks({}, nil, nil)).to eq({errors: [], exports: []})
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

      output = subject.create_invoices invoices, parser, proxy
      expect(output[:errors]).to eq ["Error 1", "Error 2", "Error 3", "Error 4"]
      expect(output[:exports]).to eq ["export"]
    end
  end

  describe "wait_for_export_updates" do
    let(:u) { FactoryBot(:user, email: "tufnel@stonehenge.biz") }
    let(:u2) { FactoryBot(:user, email: "tufnel@stonehenge.xyz") }

    it 'waits for alliance exports to all get updated' do
      export = IntacctAllianceExport.create! data_received_date: Time.zone.now
      export2 = IntacctAllianceExport.create!

      allow(subject).to receive(:unfinished_exports).with([export.id, export2.id]).and_return [export2]

      t = Thread.new {
        subject.wait_for_export_updates [u], [export, export2], 1, 5
      }
      started = Time.zone.now.to_i

      sleep 1
      # Make sure the thread is still sleeping
      expect(t).to be_alive
      allow(subject).to receive(:unfinished_exports).with([export.id, export2.id]).and_return []
      t.join(2)
      stopped = Time.zone.now.to_i
      expect(stopped - started).not_to be > 6
      expect(ActionMailer::Base.deliveries.count).to eq 0
    end

    it "emails a list of IntacctAllianceExport objects missing data after the timeout" do
      export = IntacctAllianceExport.create! data_received_date: Time.zone.now
      export2 = IntacctAllianceExport.create! export_type: IntacctAllianceExport::EXPORT_TYPE_CHECK, ap_total: 1, check_number: "cnum 1", file_number: "fnum 1"
      export3 = IntacctAllianceExport.create! export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE, ap_total: 2, ar_total: 3, check_number: "cnum 2", file_number: "fnum 2", suffix: "ABC"
      allow(subject).to receive(:unfinished_exports).with([export.id, export2.id, export3.id]).and_return [export2, export3]
      t = Thread.new { subject.wait_for_export_updates [u2], [export, export2, export3], 1, 2 }
      t.join(3)

      expect(t).not_to be_alive

      expect(ActionMailer::Base.deliveries.count).to eq 1
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["tufnel@stonehenge.xyz", described_class::ERROR_EMAIL]
      expect(mail.subject).to eq "Intacct-Alliance data not received"
      expect(mail.body.raw_source).to match(/\$1.00 for check cnum 1 \/ file fnum 1 could not be retrieved\./)
      expect(mail.body.raw_source).to match(/\$3.00 AR \/ 2.00 AP for Invoice fnum 2ABC could not be retrieved\./)
    end
  end

  describe "wait_for_dimension_uploads" do
    it "waits for intacct dimension uploads to finish" do
      allow(subject).to receive(:all_dimension_uploads_finished?).and_return false

      t = Thread.new {
        subject.wait_for_dimension_uploads 1, 5
      }
      started = Time.zone.now.to_i

      sleep 1
      # Make sure the thread is still sleeping
      expect(t).to be_alive
      allow(subject).to receive(:all_dimension_uploads_finished?).and_return true
      t.join(2)
      stopped = Time.zone.now.to_i
      expect(stopped - started).not_to be > 6
    end

    it "raises an error if too much time has passed" do
      allow(subject).to receive(:all_dimension_uploads_finished?).and_return false

      error = nil
      t = Thread.new {
        begin
          subject.wait_for_dimension_uploads 1, 2
        rescue => e
          error = e
        end
      }
      t.join(3)
      expect(t).not_to be_alive
      expect(error).not_to be_nil
    end
  end

  describe "unfinished_exports" do
    it "returns list of exports waiting to receive data" do
      export = IntacctAllianceExport.create! data_received_date: Time.zone.now
      export2 = IntacctAllianceExport.create!
      expect(subject.unfinished_exports([export.id, export2.id])).to eq [export2]

      export2.update_attributes! data_received_date: Time.zone.now
      expect(subject.unfinished_exports([export.id, export2.id])).to be_empty
    end
  end

  describe "all_dimension_uploads_finished?" do
    it "returns true if all dimension upload delayed jobs are finished" do
      job = Delayed::Job.new
      job.handler = "method_name: :async_send_dimension"
      job.save!
      expect(subject.all_dimension_uploads_finished?).to eq false
      job.handler = ""
      job.save!

      expect(subject.all_dimension_uploads_finished?).to eq true
    end
  end

  describe "process_delayed" do
    it "finds referenced custom files and user and calls process" do
      cf1 = CustomFile.create!
      cf2 = CustomFile.create!
      u = FactoryBot(:user)

      expect_any_instance_of(described_class).to receive(:process).with cf1, cf2, u
      described_class.process_delayed cf1.id, cf2.id, u.id
    end

    it "accepts nil for user" do
      cf1 = CustomFile.create!
      cf2 = CustomFile.create!

      expect_any_instance_of(described_class).to receive(:process).with cf1, cf2, nil
      described_class.process_delayed cf1.id, cf2.id, nil
    end

    it "accepts nil for check file" do
      cf = CustomFile.create!
      u = FactoryBot(:user)

      expect_any_instance_of(described_class).to receive(:process).with nil, cf, u
      described_class.process_delayed nil, cf.id, u.id
    end

    it "accepts nil for invoice file" do
      cf = CustomFile.create!
      u = FactoryBot(:user)

      expect_any_instance_of(described_class).to receive(:process).with cf, nil, u
      described_class.process_delayed cf.id, nil, u.id
    end
  end

  describe "validate_check_export_amounts_received" do
    it "ensures the expected amounts were received" do
      check_export = IntacctAllianceExport.create! ap_total: 10, export_type: 'check', data_received_date: Time.zone.now
      check = IntacctCheck.create! intacct_alliance_export: check_export, amount: 10

      errors = subject.send(:validate_check_export_amounts_received, Time.zone.now() - 5.minutes, 10)
      expect(errors.size).to eq 0
    end

    it "returns errors if unexpected values are returned" do
      errors = subject.send(:validate_check_export_amounts_received, Time.zone.now() - 5.minutes, 10)
      expect(errors.values.flatten.size).to eq 1

      expect(errors[:checks]).to eq ["Expected to retrieve $10.00 in Check data from Alliance.  Received $0.00 instead."]
    end
  end

  describe "validate_ar_ap_export_amounts_received" do
    it "ensures the expected amounts were received" do
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

      errors = subject.send(:validate_ar_ap_export_amounts_received, Time.zone.now() - 5.minutes, 30, 20)
      expect(errors.size).to eq 0
    end

    it "returns errors if unexpected values are returned" do
      errors = subject.send(:validate_ar_ap_export_amounts_received, Time.zone.now() - 5.minutes, 30, 20)
      expect(errors.values.flatten.size).to eq 2

      expect(errors[:invoices]).to eq ["Expected to retrieve $30.00 in AR lines from Alliance.  Received $0.00 instead.", "Expected to retrieve $20.00 in AP lines from Alliance.  Received $0.00 instead."]
    end
  end
end
