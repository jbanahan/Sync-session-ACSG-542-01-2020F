describe EntriesController do

  let! (:master_setup) do
    ms = stub_master_setup
    allow(ms).to receive(:entry_enabled).and_return true
    ms
  end

  let!(:user) do
    create(:master_user, entry_view: true, company: create(:company, master: true, show_business_rules: true))
  end

  before do
    sign_in_as user
  end

  describe "sync_records" do
    let (:entry) { create(:entry) }

    it "renders page" do
      get :sync_records, id: entry.id
      expect(response).to be_success
      expect(assigns(:base_object)).to eq(entry)
      expect(assigns(:back_url)).to include "entries/#{entry.id}"
    end
  end

  describe 'validation_results' do
    let(:ent) { create(:entry, broker_reference: '123456', importer: create(:importer)) }
    let(:rule_result) { create(:business_validation_rule_result) }
    let(:bvr) { rule_result.business_validation_result }

    before do
      bvr.state = 'Fail'
      bvr.validatable = ent
      bvr.save!
    end

    it "renders page" do
       get :validation_results, id: ent.id
       expect(response).to be_success
       expect(assigns(:validation_object)).to eq ent
    end

    it "renders json" do
      bvr.business_validation_template.update(name: 'myname')
      rule_result.business_validation_rule.update(name: 'rulename', description: 'ruledesc')
      rule_result.note = 'abc'
      rule_result.state = 'Pass'
      rule_result.overridden_by = user
      rule_result.overridden_at = Time.zone.now
      rule_result.save!
      rule_result.reload # fixes time issue
      get :validation_results, id: ent.id, format: :json
      expect(response).to be_success
      h = JSON.parse(response.body)['business_validation_result']
      expect(h['object_number']).to eq ent.broker_reference
      expect(h['single_object']).to eq "Entry"
      expect(h['state']).to eq bvr.state
      bv_results = h['bv_results']
      expect(bv_results.length).to eq 1
      bvr1 = bv_results.first
      expect(bvr1['id']).to eq bvr.id
      expect(bvr1['state']).to eq bvr.state
      expect(bvr1['template']['name']).to eq 'myname'
      expect(bvr1['rule_results'].length).to eq 1
      rr = bvr1['rule_results'].first
      expect(rr['id']).to eq rule_result.id
      expect(rr['rule']['name']).to eq 'rulename'
      expect(rr['rule']['description']).to eq 'ruledesc'
      expect(rr['note']).to eq 'abc'
      expect(rr['overridden_by']['full_name']).to eq user.full_name
      expect(Time.zone.parse(rr['overridden_at'])).to eq rule_result.overridden_at
    end
  end

  describe 'get_images' do
    it "requests images" do
      # make sure we're not relying on the referrer
      request.env["HTTP_REFERER"] = nil
      entry = create(:entry, source_system: 'Alliance', broker_reference: '123456')
      expect(OpenChain::AllianceImagingClient).to receive(:request_images).with('123456')
      post :get_images, 'id' => entry.id
      expect(response).to redirect_to(entry)
      expect(flash[:errors]).to be_blank
      expect(flash[:notices].first).to eq("Updated images for file 123456 have been requested.  Please allow 10 minutes for them to appear.")
    end

    it "does not request images for non-alliance entries" do
      entry = create(:entry, source_system: 'Fenix', broker_reference: '123456')
      expect(OpenChain::AllianceImagingClient).not_to receive(:request_images)
      post :get_images, 'id' => entry.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq("Images cannot be requested for entries that are not from Alliance.")
    end
  end

  describe 'bulk_get_images' do

    it "handles bulk image requests with a referer" do
      request.env["HTTP_REFERER"] = "blah"
      create(:entry, source_system: 'Alliance', broker_reference: '123456')
      expect(OpenChain::AllianceImagingClient).to receive(:delayed_bulk_request_images).with('1234', '123')
      get :bulk_get_images, {'sr_id' => '1234', 'pk' => '123'}

      expect(response).to redirect_to("blah")
      expect(flash[:errors]).to be_blank
      expect(flash[:notices].first).to eq("Updated images have been requested.  Please allow 10 minutes for them to appear.")
    end

    it "handles bulk image requests without a referer" do
      request.env["HTTP_REFERER"] = nil
      create(:entry, source_system: 'Alliance', broker_reference: '123456')
      expect(OpenChain::AllianceImagingClient).to receive(:delayed_bulk_request_images).with('1234', '123')
      get :bulk_get_images, {'sr_id' => '1234', 'pk' => '123'}

      expect(response).to redirect_to("/")
      expect(flash[:errors]).to be_blank
      expect(flash[:notices].first).to eq("Updated images have been requested.  Please allow 10 minutes for them to appear.")
    end

  end

  describe 'request data methods' do
    let(:entry) { create(:entry, source_system: 'Alliance', broker_reference: '123456', importer: create(:importer)) }
    let(:sys_admin_user) { create(:sys_admin_user, entry_view: true) }

    describe 'as a sysadmin' do
      before do
        sign_in_as sys_admin_user
      end

      describe 'request_entry_data' do
        it "requests data" do
          # make sure we're not relying on the referrer
          request.env["HTTP_REFERER"] = nil
          expect(OpenChain::KewillSqlProxyClient).to receive(:delayed_bulk_entry_data).with(nil, [entry.id])

          post :request_entry_data, 'id' => entry.id
          expect(response).to redirect_to(entry)
          expect(flash[:errors]).to be_blank
          expect(flash[:notices].first).to eq("Updated entry has been requested.  Please allow 10 minutes for it to appear.")
        end
      end

      describe 'bulk_request_entry_data' do

        it "handles bulk image requests with a referer" do
          request.env["HTTP_REFERER"] = "blah"
          expect(OpenChain::KewillSqlProxyClient).to receive(:delayed_bulk_entry_data).with(nil, {"0" => entry.id.to_s})

          post :bulk_request_entry_data, {'pk' => {"0" => entry.id}}

          expect(response).to redirect_to("blah")
          expect(flash[:errors]).to be_blank
          expect(flash[:notices].first).to eq("Updated entries have been requested.  Please allow 10 minutes for them to appear.")
        end

        it "handles bulk image requests without a referer" do
          request.env["HTTP_REFERER"] = nil
          expect(OpenChain::KewillSqlProxyClient).to receive(:delayed_bulk_entry_data).with(nil, {"0" => entry.id.to_s})

          post :bulk_request_entry_data, {'pk' => {"0" => entry.id}}

          expect(response).to redirect_to("/")
          expect(flash[:errors]).to be_blank
          expect(flash[:notices].first).to eq("Updated entries have been requested.  Please allow 10 minutes for them to appear.")
        end

        context "with a search run id" do
          let(:sr) do
            create(:search_setup, module_type: "Entry", user: sys_admin_user).search_runs.create!
          end

          before do
            entry # initiallize the let value above
          end

          it "sends a search run id to the bulk request method" do
            expect(OpenChain::KewillSqlProxyClient).to receive(:delayed_bulk_entry_data).with(sr.id.to_s, nil)
            post :bulk_request_entry_data, {'sr_id' => sr.id}
            expect(flash[:errors]).to be_blank
            expect(flash[:notices].first).to eq("Updated entries have been requested.  Please allow 10 minutes for them to appear.")
          end
        end
      end
    end

    describe 'as non-sysadmin' do
      describe 'request_entry_data' do
        it 'allows access to users under master account' do
          expect(OpenChain::KewillSqlProxyClient).to receive(:delayed_bulk_entry_data).with(nil, [entry.id])

          post :request_entry_data, 'id' => entry.id
          expect(response).to redirect_to(entry)
          expect(flash[:errors]).to be_blank
          expect(flash[:notices]).to include("Updated entry has been requested.  Please allow 10 minutes for it to appear.")
        end

        it 'does not allow access to users not under master account' do
          user.company.update! master: false
          expect(OpenChain::KewillSqlProxyClient).not_to receive(:delayed_bulk_entry_data)
          post :request_entry_data, 'id' => entry.id
          expect(response).to redirect_to(entry)
          expect(flash[:errors]).to be_blank
          expect(flash[:notices]).to be_blank
        end
      end

      describe 'bulk_request_entry_data' do
        it 'does nothing' do
          request.env["HTTP_REFERER"] = nil
          expect(OpenChain::KewillSqlProxyClient).not_to receive(:delayed_bulk_entry_data)
          post :bulk_request_entry_data, {'pk' => {"0" => entry.id}}
          expect(response).to redirect_to("/")
          expect(flash[:errors]).to be_blank
          expect(flash[:notices]).to be_blank
        end
      end
    end
  end

  describe "show" do
    it "raises a 404 if not found" do
      get :show, id: -20
      expect(response).to redirect_to("/")
      expect(flash[:errors]).to eq ["Entry with id -20 not found."]
    end

    it "shows a US entry" do
      entry = create(:entry, importer: create(:importer))
      get :show, id: entry.id

      expect(response.status).to eq(200)
      expect(assigns(:entry).id).to eq entry.id
      expect(response).to render_template("show_us")
    end

    it "shows a US simple entry" do
      user.update! simple_entry_mode: true
      entry = create(:entry, importer: create(:importer))
      get :show, id: entry.id

      expect(response.status).to eq(200)
      expect(assigns(:entry).id).to eq entry.id
      expect(response).to render_template("show_us_simple")
    end

    it "shows a CA entry" do
      country = create(:country, iso_code: 'CA')
      entry = create(:entry, import_country: country, importer: create(:importer))

      get :show, id: entry.id

      expect(response.status).to eq(200)
      expect(assigns(:entry).id).to eq entry.id
      expect(response).to render_template("show_ca")
    end

    it "redirects if user can't view" do
      expect_any_instance_of(Entry).to receive(:can_view?).and_return false

      entry = create(:entry)
      get :show, id: entry.id
      expect(response).to redirect_to("/")
      expect(flash[:errors]).to eq ["You do not have permission to view this entry."]

    end

    it "sends an xls version of the entry" do
      allow_any_instance_of(User).to receive(:view_broker_invoices?).and_return true

      e = create(:entry, importer: create(:importer))
      line = create(:commercial_invoice_line, commercial_invoice: create(:commercial_invoice, entry: e))
      create(:commercial_invoice_tariff, commercial_invoice_line: line)
      line.commercial_invoice_tariffs << create(:commercial_invoice_tariff, commercial_invoice_line: line)
      line.save!
      line2 = create(:commercial_invoice_line, commercial_invoice: create(:commercial_invoice, entry: e))

      broker_invoice = create(:broker_invoice_line, broker_invoice: create(:broker_invoice, entry: e)).broker_invoice
      create(:broker_invoice_line, broker_invoice: broker_invoice)
      broker_invoice_2 = create(:broker_invoice_line, broker_invoice: create(:broker_invoice, entry: e)).broker_invoice

      get :show, id: e.id, format: :xls

      expect(response).to be_success
      expect(response.headers['Content-Type']).to eq Mime::Type.lookup_by_extension("xls").to_s
      expect(response.headers['Content-Disposition']).to eq("attachment; filename=\"#{e.broker_reference}.xls\"")

      wb = Spreadsheet.open StringIO.new(response.body)

      # Also verify this is a US spreadsheet
      eh = wb.worksheet "Entry"
      expect(eh).not_to be_nil
      expect(eh.row(0)).not_to include(ModelField.by_uid(:ent_cadex_sent_date).label)
      expect(eh.row(0)).to include(ModelField.by_uid(:ent_isf_sent_date).label)

      ci = wb.worksheet "Commercial Invoices"
      expect(ci).not_to be_nil
      expect(ci.row_count).to eq 4
      expect(ci.row(2)[0]).to eq line.commercial_invoice.invoice_number
      expect(ci.row(4)[0]).to eq line2.commercial_invoice.invoice_number

      bi = wb.worksheet "Broker Invoices"
      expect(bi).not_to be_nil
      expect(bi.row_count).to eq 4
      # factory sequence used makes these values ints until loaded from DB (hence to_s)
      expect(bi.row(1)[0]).to eq broker_invoice.invoice_number.to_s
      expect(bi.row(3)[0]).to eq broker_invoice_2.invoice_number.to_s
    end

    it "uses canadian fields in xls file for canadian entries" do
      expect_any_instance_of(Entry).to receive(:canadian?).twice.and_return true
      e = create(:entry, importer: create(:importer))

      get :show, id: e.id, format: :xls
      wb = Spreadsheet.open StringIO.new(response.body)
      sheet = wb.worksheet "Entry"
      expect(sheet).not_to be_nil

      # Just check for the presence of a canadian field and non-presence of a US only one in the headers
      expect(sheet.row(0)).to include(ModelField.by_uid(:ent_cadex_sent_date).label)
      expect(sheet.row(0)).not_to include(ModelField.by_uid(:ent_isf_sent_date).label)
    end

    it "does not show broker invoices to users not capable of seeing them" do
      allow_any_instance_of(User).to receive(:view_broker_invoices?).and_return false
      e = create(:entry, importer: create(:importer))

      get :show, id: e.id, format: :xls
      wb = Spreadsheet.open StringIO.new(response.body)
      expect(wb.worksheet("Entry")).not_to be_nil
      expect(wb.worksheet("Broker Invoices")).to be_nil
    end
  end

  context "country activity summaries" do
    describe "ca_activity_summary" do
      # before(:each) do
      #   @ca_1 = with_fenix_id(create(:company), "1")
      #   @ca_2 = with_fenix_id(create(:company), "2")
      #   @ca_3 = with_fenix_id(create(:company), "3")

      #   @iso = 'ca'
      #   @ca_companies = [@ca_1, @ca_2, @ca_3]
      # end

      it "renders activity_summary if called with an importer_id" do
        get :ca_activity_summary, {importer_id: 1}
        expect(response).to render_template :activity_summary
      end

      it "renders activity_summary_portal if there are multiple CA importers" do
        ca1 = with_fenix_id(create(:company), "1")
        ca2 = with_fenix_id(create(:company), "2")
        get :ca_activity_summary
        expect(response).to render_template :act_summary_portal
        expect(assigns(:iso)).to eq "ca"
        expect(assigns(:importers)).to include ca1
        expect(assigns(:importers)).to include ca2
      end

      it "redirects to the CA importer if there is only one" do
        co = with_fenix_id(create(:company), "1")
        get :ca_activity_summary
        expect(response).to redirect_to "/entries/importer/#{co.id}/activity_summary/ca"
      end

      it "redirects to the user's importer if there are no CA importers" do
        get :ca_activity_summary
        expect(response).to redirect_to "/entries/importer/#{user.company.id}/activity_summary/ca"
      end
    end

    describe "us_activity_summary" do
      it "renders activity_summary if called with an importer_id" do
        get :us_activity_summary, {importer_id: 1}
        expect(response).to render_template :activity_summary
      end

      it "renders activity_summary_portal if there are multiple US importers" do
        co1 = with_customs_management_id(create(:company), "1")
        co2 = with_customs_management_id(create(:company), "2")
        get :us_activity_summary
        expect(response).to render_template :act_summary_portal
        expect(assigns(:iso)).to eq "us"
        expect(assigns(:importers)).to include co1
        expect(assigns(:importers)).to include co2
      end

      it "redirects to the US importer if there is only one" do
        co1 = with_customs_management_id(create(:company), "1")
        get :us_activity_summary
        expect(response).to redirect_to "/entries/importer/#{co1.id}/activity_summary/us"
      end

      it "redirects to the user's importer if there are no US importers" do
        get :us_activity_summary
        expect(response).to redirect_to "/entries/importer/#{user.company.id}/activity_summary/us"
      end
    end
  end

  describe "by_release_range" do
    before do
      @country = create(:country, iso_code: 'US')
    end

    it "validates access and creates a release range query object" do
      get :by_release_range, importer_id: user.company.id, iso_code: 'US', release_range: '1w'

      expect(response).to be_success
      expect(assigns(:range_descriptions)).to eq [
        ["Released In The Last 7 Days", '1w'],
        ["Released In The Last 28 Days", '4w'],
        ["Filed / Not Released", 'op'],
        ["Released Year To Date", 'ytd'],
        ["Entries On Hold", 'holds']
      ]

      expect(assigns(:entries).to_sql).to match(/SELECT.*FROM/i)
      expect(assigns(:date_uid)).to eq :ent_first_release_received_date
    end

    it "assigns :ent_hold_date if flag is set in release_range" do
      get :by_release_range, importer_id: user.company.id, iso_code: 'US', release_range: 'holds'
      expect(assigns(:date_uid)).to eq :ent_hold_date
    end

    it "handles argument error raised from query call" do
      expect_any_instance_of(OpenChain::ActivitySummary::USEntrySummaryGenerator).to receive(:create_by_release_range_query).and_raise ArgumentError.new("Testing")

      get :by_release_range, importer_id: user.company.id, iso_code: 'US', release_range: '1w'

      expect(response).to redirect_to("/")
      expect(flash[:errors]).to eq ["Testing"]
    end

    it "secures action" do
      expect(Entry).to receive(:can_view_importer?).and_return false

      get :by_release_range, importer_id: user.company.id, iso_code: 'US', release_range: '1w'
      expect(response).to redirect_to("/")
      expect(flash[:errors]).to eq ["You do not have permission to view this entry."]
    end
  end

  describe "by_entry_port" do
    it "validates access and creates an entry port query" do
      get :by_entry_port, importer_id: user.company.id, port_code: 'ABC', iso_code: 'US'

      expect(response).to be_success
      expect(assigns(:entries).to_sql).to match(/SELECT.*FROM/i)
      expect(assigns(:date_uid)).to eq :ent_first_release_received_date
    end

    it "secures action" do
      expect(Entry).to receive(:can_view_importer?).and_return false

      get :by_entry_port, importer_id: user.company.id, port_code: 'ABC', iso_code: "US"
      expect(response).to redirect_to("/")
      expect(flash[:errors]).to eq ["You do not have permission to view this entry."]
    end
  end

  describe "purge" do
    let(:entry) do
      create(:entry,
                     broker_reference: "1234567",
                     import_country_id: create(:country).id,
                     source_system: "SomeSystem")

    end

    context "as a purge group member" do
      before do
        group = Group.use_system_group("Entry Purge")
        user.groups << group
        user.save!
      end

      it 'copies fields from current entry to entry_purge table along with the iso' do
        get :purge, id: entry
        purged = EntryPurge.last
        c = Country.last
        expect(purged.broker_reference).to eq "1234567"
        expect(purged.source_system).to eq "SomeSystem"
        expect(purged.country_iso).to eq(c.iso_code)
      end

      it 'deletes the purged entry' do
        get :purge, id: entry
        expect(Entry.find_by(id: entry)).to be_nil
      end

      it 'displays a confirmation and redirect' do
        get :purge, id: entry
        expect(flash[:notices]).to include("Entry purged")
        expect(response).to redirect_to entries_path
      end
    end

    context "as a non-purge group member" do
      it 'does nothing' do
        get :purge, id: entry
        expect(EntryPurge.count).to eq 0
        expect(Entry.find_by(id: entry)).not_to be_nil
        expect(flash[:notice]).to be_blank
      end

      it 'displays an error message and reload the page' do
        get :purge, id: entry
        expect(flash[:errors]).to eq ["Only members of the 'Entry Purge' group can do this."]
      end
    end

  end

  describe "us_duty_detail" do
    let(:company) {  create(:company) }
    let(:user) { create(:user, company: company) }

    before do
      sign_in_as user
    end

    it "does not allow users without permission to view entries" do
      allow_any_instance_of(Company).to receive(:can_view?).with(user).and_return(true)

      allow(Entry).to receive(:can_view_importer?).with(instance_of(Company), user).and_return(false)
      get :us_duty_detail, importer_id: company.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "does not allow users without permission to company" do
      allow(Entry).to receive(:can_view_importer?).with(instance_of(Company), user).and_return(true)

      allow_any_instance_of(Company).to receive(:can_view?).with(user).and_return(false)
      get :us_duty_detail, importer_id: company.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "renders page" do
      allow(Entry).to receive(:can_view_importer?).with(instance_of(Company), user).and_return(true)
      allow_any_instance_of(Company).to receive(:can_view?).with(user).and_return(true)

      single_company_report = instance_double('report')

      linked_company_reports = [instance_double('linked report 1'),
                                instance_double('linked report 2'),
                                instance_double('linked report 3')]

      expect_any_instance_of(OpenChain::ActivitySummary::USEntrySummaryGenerator)
        .to receive(:create_digest)
        .with(user, company)
        .and_return single_company_report

      expect_any_instance_of(OpenChain::ActivitySummary::USEntrySummaryGenerator)
        .to receive(:create_linked_digests)
        .with(user, company)
        .and_return linked_company_reports

      get :us_duty_detail, importer_id: company.id
      expect(response).to be_success
      expect(assigns(:reports)).to eq [single_company_report].concat(linked_company_reports)
    end
  end

  describe "by_release_range_download" do
    before do
      create(:country, iso_code: "US")
    end

    it "returns XLS file" do
      get :by_release_range_download, importer_id: user.company.id, iso_code: "US", release_range: "1w"

      expect(response).to be_success
      Tempfile.open("temp") do |t|
        t.binmode
        t.write response.body
        wb = Spreadsheet.open t
        expect(wb.worksheets[0].name).to eq "Released In The Last 7 Days"
      end
    end

    it "rejects unauthorized users" do
      u = create(:user)
      sign_in_as u
      get :by_release_range_download, importer_id: user.company.id, iso_code: "US", release_range: "1w"
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to download this file."
    end
  end

  describe "generate_delivery_order" do
    let (:user) { create(:master_user) }

    before do
      sign_in_as user
    end

    it "generates a delivery order for US entry" do
      entry = create(:entry)
      expect_any_instance_of(Entry).to receive(:can_view?).with(user).and_return true
      expect(OpenChain::CustomHandler::DeliveryOrderSpreadsheetGenerator).to receive(:delay).and_return OpenChain::CustomHandler::DeliveryOrderSpreadsheetGenerator
      expect(OpenChain::CustomHandler::DeliveryOrderSpreadsheetGenerator).to receive(:generate_and_send_delivery_orders).with(user.id, entry.id)
      post :generate_delivery_order, {id: entry.id}
      expect(response).to redirect_to(entry)
      expect(flash[:notices]).to include "The Delivery Order will be generated shortly and emailed to #{user.email}."
    end

    it "redirects to error for canadian entries" do
      entry = create(:entry, import_country: create(:country, iso_code: "CA"))
      expect_any_instance_of(Entry).to receive(:can_view?).with(user).and_return true
      expect(OpenChain::CustomHandler::DeliveryOrderSpreadsheetGenerator).not_to receive(:delay)
      post :generate_delivery_order, {id: entry.id}
      expect(response).to redirect_to(entry)
      expect(flash[:errors]).to include "You do not have permission to view this report."
    end
  end

end
