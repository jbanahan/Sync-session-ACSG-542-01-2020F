require 'spec_helper'

describe EntriesController do

  before :each do 
    MasterSetup.get.update_attributes(:entry_enabled=>true)
    c = Factory(:company,:master=>true)
    @u = Factory(:master_user,entry_view:true,:company=>c)

    sign_in_as @u
  end

  describe "sync_records" do
    before :each do
      @ent = Factory(:entry)
    end

    it "should render page" do
      get :sync_records, id: @ent.id
      expect(response).to be_success
      controller.instance_variable_get(:@e).should == @ent
    end
  end

  describe 'validation_results' do 
    before :each do
      @ent = Factory(:entry,entry_number:'123456')
      @rule_result = Factory(:business_validation_rule_result)
      @bvr = @rule_result.business_validation_result
      @bvr.state = 'Fail'
      @bvr.validatable = @ent
      @bvr.save!
    end
    it "should render page" do
      get :validation_results, id: @ent.id
      expect(response).to be_success
      expect(assigns(:entry)).to eq @ent
    end
    it "should render json" do
      @bvr.business_validation_template.update_attributes(name:'myname')
      @rule_result.business_validation_rule.update_attributes(name:'rulename',description:'ruledesc')
      @rule_result.note = 'abc'
      @rule_result.state = 'Pass'
      @rule_result.overridden_by = @u
      @rule_result.overridden_at = Time.now
      @rule_result.save!
      @rule_result.reload #fixes time issue
      get :validation_results, id: @ent.id, format: :json
      expect(response).to be_success
      h = JSON.parse(response.body)['business_validation_result']
      expect(h['object_number']).to eq @ent.entry_number
      expect(h['single_object']).to eq "Entry"
      expect(h['state']).to eq @bvr.state
      bv_results = h['bv_results']
      expect(bv_results.length).to eq 1
      bvr = bv_results.first
      expect(bvr['id']).to eq @bvr.id
      expect(bvr['state']).to eq @bvr.state
      expect(bvr['template']['name']).to eq 'myname'
      expect(bvr['rule_results'].length).to eq 1
      rr = bvr['rule_results'].first
      expect(rr['id']).to eq @rule_result.id
      expect(rr['rule']['name']).to eq 'rulename'
      expect(rr['rule']['description']).to eq 'ruledesc'
      expect(rr['note']).to eq 'abc'
      expect(rr['overridden_by']['full_name']).to eq @u.full_name
      expect(Time.parse(rr['overridden_at'])).to eq @rule_result.overridden_at
    end

  end
  describe 'get_images' do
    it "should request images" do
      #make sure we're not relying on the referrer
      request.env["HTTP_REFERER"] = nil
      entry = Factory(:entry,:source_system=>'Alliance',:broker_reference=>'123456')
      OpenChain::AllianceImagingClient.should_receive(:request_images).with('123456')
      post :get_images, 'id'=>entry.id
      expect(response).to redirect_to(entry)
      flash[:errors].should be_blank
      flash[:notices].first.should == "Updated images for file 123456 have been requested.  Please allow 10 minutes for them to appear."
    end
    it "should not request images for non-alliance entries" do
      entry = Factory(:entry,:source_system=>'Fenix',:broker_reference=>'123456')
      OpenChain::AllianceImagingClient.should_not_receive(:request_images)
      post :get_images, 'id'=>entry.id
      response.should be_redirect
      flash[:errors].first.should == "Images cannot be requested for entries that are not from Alliance."
    end
  end

  describe 'bulk_get_images' do

    it "should handle bulk image requests with a referer" do
      request.env["HTTP_REFERER"] = "blah"
      entry = Factory(:entry,:source_system=>'Alliance',:broker_reference=>'123456')
      OpenChain::AllianceImagingClient.stub(:delay).and_return(OpenChain::AllianceImagingClient)
      OpenChain::AllianceImagingClient.should_receive(:bulk_request_images).with('1234', '123')
      get :bulk_get_images, {'sr_id'=>'1234', 'pk'=>'123'}
      
      response.should redirect_to("blah")
      flash[:errors].should be_blank
      flash[:notices].first.should == "Updated images have been requested.  Please allow 10 minutes for them to appear."
    end

    it "should handle bulk image requests without a referer" do
      request.env["HTTP_REFERER"] = nil
      entry = Factory(:entry,:source_system=>'Alliance',:broker_reference=>'123456')
      OpenChain::AllianceImagingClient.stub(:delay).and_return(OpenChain::AllianceImagingClient)
      OpenChain::AllianceImagingClient.should_receive(:bulk_request_images).with('1234', '123')
      get :bulk_get_images, {'sr_id'=>'1234', 'pk'=>'123'}
      
      response.should redirect_to("/")
      flash[:errors].should be_blank
      flash[:notices].first.should == "Updated images have been requested.  Please allow 10 minutes for them to appear."
    end

  end

  describe 'request data methods' do
    let(:entry) { Factory(:entry,:source_system=>'Alliance',:broker_reference=>'123456') }
    describe 'as a sysadmin' do
      before :each do
        sys_admin_user = Factory(:sys_admin_user,entry_view:true)
        @proxy = OpenChain::SqlProxyClient.new
        sign_in_as sys_admin_user
      end

      describe 'request_entry_data' do
        it "should request data" do
          #make sure we're not relying on the referrer
          request.env["HTTP_REFERER"] = nil
          OpenChain::SqlProxyClient.any_instance.stub(:delay).and_return(@proxy)
          @proxy.should_receive(:request_entry_data).with('123456')
          post :request_entry_data, 'id'=>entry.id
          expect(response).to redirect_to(entry)
          flash[:errors].should be_blank
          flash[:notices].first.should == "Updated entry has been requested.  Please allow 10 minutes for it to appear."
        end
      end

      describe 'bulk_request_entry_data' do

        it "should handle bulk image requests with a referer" do
          request.env["HTTP_REFERER"] = "blah"
          OpenChain::SqlProxyClient.any_instance.stub(:delay).and_return(@proxy)
          @proxy.should_receive(:bulk_request_entry_data).with(['123456'])
          post :bulk_request_entry_data, {'pk'=>{"0"=>entry.id}}

          response.should redirect_to("blah")
          flash[:errors].should be_blank
          flash[:notices].first.should == "Updated entries have been requested.  Please allow 10 minutes for them to appear."
        end

        it "should handle bulk image requests without a referer" do
          request.env["HTTP_REFERER"] = nil
          OpenChain::SqlProxyClient.any_instance.stub(:delay).and_return(@proxy)
          @proxy.should_receive(:bulk_request_entry_data).with(['123456'])
          post :bulk_request_entry_data, {'pk'=>{"0"=>entry.id}}

          response.should redirect_to("/")
          flash[:errors].should be_blank
          flash[:notices].first.should == "Updated entries have been requested.  Please allow 10 minutes for them to appear."
        end
      end
    end
    describe 'as non-sysadmin' do
      describe 'request_entry_data' do
        it 'should do nothing' do
          OpenChain::SqlProxyClient.should_not_receive(:new)
          post :request_entry_data, 'id'=>entry.id
          expect(response).to redirect_to(entry)
          expect(flash[:errors]).to be_blank
          expect(flash[:notices]).to be_blank
        end
      end
      describe 'bulk_request_entry_data' do
        it 'should do nothing' do
          request.env["HTTP_REFERER"] = nil
          OpenChain::SqlProxyClient.should_not_receive(:new)
          post :bulk_request_entry_data, {'pk'=>{"0"=>entry.id}}
          expect(response).to redirect_to("/")
          expect(flash[:errors]).to be_blank
          expect(flash[:notices]).to be_blank
        end
      end
    end
  end

  describe "show" do
    it "should raise a 404 if not found" do
      get :show, :id => -20
      response.should redirect_to("/")
      flash[:errors].should eq ["Entry with id -20 not found."]
    end

    it "should show a US entry" do
      entry = Factory(:entry)
      get :show, :id => entry.id

      response.status.should == 200
      assigns(:entry).id.should eq entry.id
      response.should render_template("show_us")
    end

    it "should show a US simple entry" do
      @u.update_attributes! :simple_entry_mode => true
      entry = Factory(:entry)
      get :show, :id => entry.id

      response.status.should == 200
      assigns(:entry).id.should eq entry.id
      response.should render_template("show_us_simple")
    end

    it "should show a CA entry" do
      country = Factory(:country, :iso_code => 'CA')
      entry = Factory(:entry, :import_country => country)

      get :show, :id => entry.id

      response.status.should == 200
      assigns(:entry).id.should eq entry.id
      response.should render_template("show_ca")
    end

    it "should redirect if user can't view" do
      Entry.any_instance.should_receive(:can_view?).and_return false

      entry = Factory(:entry)
      get :show, :id => entry.id
      response.should redirect_to("/")
      flash[:errors].should eq ["You do not have permission to view this entry."]

    end

    it "sends an xls version of the entry" do
      User.any_instance.stub(:view_broker_invoices?).and_return true
      line = Factory(:commercial_invoice_tariff).commercial_invoice_line
      line.commercial_invoice_tariffs << Factory(:commercial_invoice_tariff, commercial_invoice_line: line)
      line.save!
      e = line.entry
      line2 = Factory(:commercial_invoice_line, commercial_invoice: Factory(:commercial_invoice, entry: e))

      broker_invoice = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: e)).broker_invoice
      Factory(:broker_invoice_line, broker_invoice: broker_invoice)
      broker_invoice_2 = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: e)).broker_invoice

      get :show, :id => e.id, :format=> :xls

      expect(response).to be_success
      expect(response.headers['Content-Type']).to eq Mime::Type.lookup_by_extension("xls").to_s
      response.headers['Content-Disposition'].should == "attachment; filename=\"#{e.broker_reference}.xls\""
      
      wb = Spreadsheet.open StringIO.new(response.body)

      # Also verify this is a US spreadsheet
      eh = wb.worksheet "Entry"
      expect(eh).to_not be_nil
      expect(eh.row(0)).to_not include(ModelField.find_by_uid(:ent_cadex_sent_date).label)
      expect(eh.row(0)).to include(ModelField.find_by_uid(:ent_isf_sent_date).label)

      ci = wb.worksheet "Commercial Invoices"
      expect(ci).to_not be_nil
      expect(ci.row_count).to eq 4
      expect(ci.row(2)[0]).to eq line.commercial_invoice.invoice_number
      expect(ci.row(4)[0]).to eq line2.commercial_invoice.invoice_number

      bi = wb.worksheet "Broker Invoices"
      expect(bi).to_not be_nil
      expect(bi.row_count).to eq 4
      # factory sequence used makes these values ints until loaded from DB (hence to_s)
      expect(bi.row(1)[0]).to eq broker_invoice.invoice_number.to_s
      expect(bi.row(3)[0]).to eq broker_invoice_2.invoice_number.to_s
    end

    it "uses canadian fields in xls file for candian entries" do
      Entry.any_instance.should_receive(:canadian?).exactly(2).times.and_return true
      e = Factory(:entry)

      get :show, :id => e.id, :format=> :xls
      wb = Spreadsheet.open StringIO.new(response.body)
      sheet = wb.worksheet "Entry"
      expect(sheet).to_not be_nil

      # Just check for the presence of a canadian field and non-presence of a US only one in the headers
      expect(sheet.row(0)).to include(ModelField.find_by_uid(:ent_cadex_sent_date).label)
      expect(sheet.row(0)).to_not include(ModelField.find_by_uid(:ent_isf_sent_date).label)
    end

    it "does not show broker invoices to users not capable of seeing them" do
      User.any_instance.stub(:view_broker_invoices?).and_return false
      e = Factory(:entry)

      get :show, :id => e.id, :format=> :xls
      wb = Spreadsheet.open StringIO.new(response.body)
      expect(wb.worksheet("Entry")).to_not be_nil
      expect(wb.worksheet("Broker Invoices")).to be_nil
    end
  end

  describe "by_release_range" do
    before :each do 
      @country = Factory(:country, iso_code: 'US')
    end

    it "validates access and creates a release range query object" do
      get :by_release_range, importer_id: @u.company.id, iso_code: 'US', release_range: '1w'

      response.should be_success
      expect(assigns(:range_descriptions)).to eq [
        ["Released In The Last 7 Days",'1w'],
        ["Released In The Last 28 Days",'4w'],
        ["Filed / Not Released",'op'],
        ["Released Year To Date",'ytd']
      ]

      expect(assigns(:entries).to_sql).to match /SELECT.*FROM/i
    end

    it "handles argument error raised from query call" do
      OpenChain::ActivitySummary.should_receive(:create_by_release_range_query).and_raise ArgumentError.new("Testing")

      get :by_release_range, importer_id: @u.company.id, iso_code: 'US', release_range: '1w'

      response.should redirect_to("/")
      flash[:errors].should eq ["Testing"]
    end

    it "secures action" do
      Entry.should_receive(:can_view_importer?).and_return false

      get :by_release_range, importer_id: @u.company.id, iso_code: 'US', release_range: '1w'
      response.should redirect_to("/")
      flash[:errors].should eq ["You do not have permission to view this entry."]
    end
  end

  describe "by_entry_port" do
    it "validates access and creates an entry port query" do
      get :by_entry_port, port_code: 'ABC', importer_id: @u.company.id

      response.should be_success
      expect(assigns(:entries).to_sql).to match /SELECT.*FROM/i
    end

    it "secures action" do
      Entry.should_receive(:can_view_importer?).and_return false

      get :by_entry_port, port_code: 'ABC', importer_id: @u.company.id
      response.should redirect_to("/")
      flash[:errors].should eq ["You do not have permission to view this entry."]
    end
  end

  describe "purge legacy record" do
    let(:entry) { Factory.create(:entry, broker_reference: "1234567", import_country_id: 1, source_system: "SomeSystem") }

    it 'should copy fields from current entry to entry_purge table' do
      get :purge, id: entry.id
      purge = EntryPurge.last
      expect(purge.broker_reference).to eq "1234567"
      expect(purge.source_sytem).to eq "SomeSystem"
    end

    it 'should give the purge record the country iso corresponding to the entry\'s import_country_id' do
      get :purge, id: entry.id
      purge = EntryPurge.last
      expect(purge.country_iso).to eq "US"
    end

    it 'should give the purge record a date_purged equal to it\'s created_at timestamp' do
      get :purge, id: entry.id
      purge = EntryPurge.last
      expect(purge.date_purged).to eq(purge.created_at)
    end
  end

end
