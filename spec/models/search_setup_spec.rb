describe SearchSetup do
  describe "result_keys" do
    it "should initialize query" do
      expect_any_instance_of(SearchQuery).to receive(:result_keys).and_return "X"
      expect(SearchSetup.new.result_keys).to eq("X")
    end
  end
  describe "uploadable?" do
    # there are quite a few tests for this in the old test unit structure
    it 'should always reject ENTRY' do
      ss = Factory(:search_setup, :module_type=>'Entry')
      msgs = []
      expect(ss.uploadable?(msgs)).to be_falsey
      expect(msgs.size).to eq(1)
      expect(msgs.first).to eq("Upload functionality is not available for Entries.")
    end
    it 'should always reject BROKER_INVOICE' do
      ss = Factory(:search_setup, :module_type=>'BrokerInvoice')
      msgs = []
      expect(ss.uploadable?(msgs)).to be_falsey
      expect(msgs.size).to eq(1)
      expect(msgs.first).to eq("Upload functionality is not available for Invoices.")
    end
    it "should reject PRODUCT for non-master" do
      u = Factory(:importer_user, :product_edit=>true, :product_view=>true)
      ss = Factory(:search_setup, :module_type=>"Product", :user=>u)
      msgs = []
      expect(ss.uploadable?(msgs)).to be_falsey
      expect(msgs.first.include?("Only users from the master company can upload products.")).to be_truthy
    end
  end
  describe "downloadable?" do
    it "is downloadable if there are search criterions" do
      ss = Factory(:search_criterion, search_setup: Factory(:search_setup)).search_setup
      expect(ss.downloadable?).to be_truthy
    end

    it "is not downloadable if there are no search criterions for multi-page searches" do
      errors = []
      expect(Factory(:search_setup).downloadable? errors).to be_falsey
      expect(errors).to eq ["You must add at least one Parameter to your search setup before downloading a search."]
    end

    it "is not downloadable if there are no search criterions for single page searches" do
      errors = []
      expect(Factory(:search_setup).downloadable? errors, true).to be_truthy
    end
  end
  describe "give_to" do
    let! (:master_setup) {
      stub_master_setup
    }

    before :each do
      @u = Factory(:user, :first_name=>"A", :last_name=>"B")
      @u2 = Factory(:user)
      @s = SearchSetup.create!(:name=>"X", :module_type=>"Product", :user_id=>@u.id)
    end
    it "should copy to another user" do
      @s.update! locked: true
      @s.give_to @u2
      d = SearchSetup.find_by(user: @u2)
      expect(d.name).to eq("X (From #{@u.full_name})")
      expect(d.id).not_to be_nil
      expect(d.locked?).to be false # locked attribute shouldn't be copied
      @s.reload
      expect(@s.name).to eq("X") # we shouldn't modify the original object
      expect(@s.locked?).to be true
    end
    it "should copy to another user including schedules" do
      @s.search_schedules.build
      @s.save
      @s.give_to @u2, true

      d = SearchSetup.find_by(user: @u2)
      expect(d.name).to eq("X (From #{@u.full_name})")
      expect(d.search_schedules.size).to eq(1)
    end
    it "should strip existing '(From X)' values from search names" do
      @s.update_attributes :name => "Search (From David St. Hubbins) (From Nigel Tufnel)"
      @s.give_to @u2
      d = SearchSetup.find_by user: @u2
      expect(d.name).to eq("Search (From #{@u.full_name})")
    end
    it "should create a notification for recipient" do
      @s.give_to @u2
      expect(@u2.messages.count).to eq 1
      msg = @u2.messages.first
      expect(msg.subject).to eq "New Report from #{@u.username}"
      expect(msg.body).to eq "#{@u.username} has sent you a report titled #{@s.name}. Click <a href=\'#{Rails.application.routes.url_helpers.advanced_search_url(SearchSetup.last.id, host: master_setup.request_host, protocol: 'http')}\'>here</a> to view it."
    end

  end
  describe "deep_copy" do
    before :each do
      @u = Factory(:user)
      @s = SearchSetup.create!(:name=>"ABC", :module_type=>"Order", :user=>@u, :simple=>false, :download_format=>'csv', :include_links=>true, :include_rule_links=>true)
    end
    it "should copy basic search setup" do
      d = @s.deep_copy "new"
      expect(d.id).not_to be_nil
      expect(d.id).not_to eq(@s.id)
      expect(d.name).to eq("new")
      expect(d.module_type).to eq("Order")
      expect(d.user).to eq(@u)
      expect(d.simple).to be_falsey
      expect(d.download_format).to eq('csv')
      expect(d.include_links).to be_truthy
      expect(d.include_rule_links).to be_truthy
    end
    it "should copy parameters" do
      @s.search_criterions.create!(:model_field_uid=>'a', :value=>'x', :operator=>'y', :status_rule_id=>1, :custom_definition_id=>2)
      d = @s.deep_copy "new"
      expect(d.search_criterions.size).to eq(1)
      sc = d.search_criterions.first
      expect(sc.model_field_uid).to eq('a')
      expect(sc.value).to eq('x')
      expect(sc.operator).to eq('y')
      expect(sc.status_rule_id).to eq(1)
      expect(sc.custom_definition_id).to eq(2)
    end
    it "should copy columns" do
      @s.search_columns.create!(:model_field_uid=>'a', :rank=>7, :custom_definition_id=>9)
      d = @s.deep_copy "new"
      expect(d.search_columns.size).to eq(1)
      sc = d.search_columns.first
      expect(sc.model_field_uid).to eq('a')
      expect(sc.rank).to eq(7)
      expect(sc.custom_definition_id).to eq(9)
    end
    it "should copy sorts" do
      @s.sort_criterions.create!(:model_field_uid=>'a', :rank=>5, :custom_definition_id=>2, :descending=>true)
      d = @s.deep_copy "new"
      expect(d.sort_criterions.size).to eq(1)
      sc = d.sort_criterions.first
      expect(sc.model_field_uid).to eq('a')
      expect(sc.rank).to eq(5)
      expect(sc.custom_definition_id).to eq(2)
      expect(sc).to be_descending
    end
    it "should not copy schedules" do
      @s.search_schedules.create!
      d = @s.deep_copy "new"
      expect(d.search_schedules).to be_empty
    end
    it "should copy schedules when told to do so" do
      @s.search_schedules.create!
      d = @s.deep_copy "new", true
      expect(d.search_schedules.size).to eq(1)
    end
  end
  describe "values" do
    let (:user) { Factory(:admin_user) }

    before :each do
      ModelField.reload true
    end

    CoreModule.all.each do |cm|
      it "can utilize all '#{cm.label}' core module model fields in a SearchQuery" do
        if cm == CoreModule::PRODUCT
          region = Factory(:region)
          region.countries << Factory(:country)
        end

        if cm.klass.respond_to?(:search_where)
          allow(cm.klass).to receive(:search_where).and_return("1=1")
        end

        cm.model_fields.keys.in_groups_of(20, false) do |uids|
          i = 0
          ss = SearchSetup.new(:module_type=>cm.class_name)
          uids.each do |uid|
            mf = cm.model_fields[uid]
            next unless mf.can_view?(user)
            ss.search_columns.build(:model_field_uid=>uid, :rank=>(i+=1))
            ss.sort_criterions.build(:model_field_uid=>uid, :rank=>i)
            ss.search_criterions.build(:model_field_uid=>uid, :operator=>'null')
          end
          # just making sure each query executes without error
          SearchQuery.new(ss, user).execute
        end
      end
    end
  end
  context "last_accessed" do
    before :each do
      @s = Factory :search_setup
    end

    it "should return the last_accessed time from an associated search run" do
      expect(@s.last_accessed).to be_nil
      now = Time.zone.now
      @s.search_runs.build :last_accessed=>now
      @s.save

      @s.last_accessed.to_i == now.to_i
    end
  end

  describe "max_results" do
    let (:user) { User.new }

    it "returns 25K results by default" do
      expect(subject.max_results user).to eq 25_000
    end

    it "returns 100K results for sys admins" do
      expect(user).to receive(:sys_admin?).and_return true
      expect(subject.max_results user).to eq 100_000
    end

    context "with class level method" do
      it "returns 25K results by default" do
        expect(subject.max_results user).to eq 25_000
      end

      it "returns 100K results for sys admins" do
        expect(user).to receive(:sys_admin?).and_return true
        expect(subject.max_results user).to eq 100_000
      end
    end
  end

  describe "ruby_date_format" do
    it "converts display/xls date format to ruby date format" do
      expect(SearchSetup.ruby_date_format("yyyy-MM-dd")).to eq "%Y-%m-%d"
      expect(SearchSetup.ruby_date_format("mm/DD/YYYY")).to eq "%m/%d/%Y"
      expect(SearchSetup.ruby_date_format(nil)).to eq nil
    end
  end

  describe "create_with_columns" do
    it "creates a search setup based on provided values" do
      user = User.new(default_report_date_format: "MM/DD/YYYY")
      ss = described_class.create_with_columns Entry.new.core_module, [:ent_brok_ref, :ent_entry_num], user, "Alternate Name"
      expect(ss.name).to eq "Alternate Name"
      expect(ss.user).to eq user
      expect(ss.module_type).to eq "Entry"
      expect(ss.simple).to eq false
      expect(ss.date_format).to eq "MM/DD/YYYY"

      expect(ss.search_columns.length).to eq 2
      expect(ss.search_columns[0].rank).to eq 0
      expect(ss.search_columns[0].model_field_uid).to eq "ent_brok_ref"
      expect(ss.search_columns[1].rank).to eq 1
      expect(ss.search_columns[1].model_field_uid).to eq "ent_entry_num"
    end

    it "creates a search setup with a default name" do

    end
  end
end
