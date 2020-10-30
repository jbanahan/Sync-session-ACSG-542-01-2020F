describe SearchSetup do
  describe "result_keys" do
    it "initializes query" do
      expect_any_instance_of(SearchQuery).to receive(:result_keys).and_return "X"
      expect(described_class.new.result_keys).to eq("X")
    end
  end

  describe "uploadable?" do
    # there are quite a few tests for this in the old test unit structure
    it 'always rejects ENTRY' do
      ss = Factory(:search_setup, module_type: 'Entry')
      msgs = []
      expect(ss.uploadable?(msgs)).to be_falsey
      expect(msgs.size).to eq(1)
      expect(msgs.first).to eq("Upload functionality is not available for Entries.")
    end

    it 'always rejects BROKER_INVOICE' do
      ss = Factory(:search_setup, module_type: 'BrokerInvoice')
      msgs = []
      expect(ss.uploadable?(msgs)).to be_falsey
      expect(msgs.size).to eq(1)
      expect(msgs.first).to eq("Upload functionality is not available for Invoices.")
    end

    it "rejects PRODUCT for non-master" do
      u = Factory(:importer_user, product_edit: true, product_view: true)
      ss = Factory(:search_setup, module_type: "Product", user: u)
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
      expect(Factory(:search_setup).downloadable?(errors)).to be_falsey
      expect(errors).to eq ["You must add at least one Parameter to your search setup before downloading a search."]
    end

    it "is not downloadable if there are no search criterions for single page searches" do
      errors = []
      expect(Factory(:search_setup).downloadable?(errors, true)).to be_truthy
    end
  end

  describe "give_to" do
    let! (:master_setup) do
      stub_master_setup
    end

    let(:user) { Factory(:user, first_name: "A", last_name: "B") }
    let(:user2) { Factory(:user) }
    let(:search_setup) { described_class.create!(name: "X", module_type: "Product", user_id: user.id) }

    it "copies to another user" do
      search_setup.update! locked: true
      search_setup.give_to user2
      d = described_class.find_by(user: user2)
      expect(d.name).to eq("X (From #{user.full_name})")
      expect(d.id).not_to be_nil
      expect(d.locked?).to be false # locked attribute shouldn't be copied
      search_setup.reload
      expect(search_setup.name).to eq("X") # we shouldn't modify the original object
      expect(search_setup.locked?).to be true
    end

    it "copies to another user including schedules" do
      search_setup.search_schedules.build
      search_setup.save
      search_setup.give_to user2, true

      d = described_class.find_by(user: user2)
      expect(d.name).to eq("X (From #{user.full_name})")
      expect(d.search_schedules.size).to eq(1)
    end

    it "strips existing '(From X)' values from search names" do
      search_setup.update name: "Search (From David St. Hubbins) (From Nigel Tufnel)"
      search_setup.give_to user2
      d = described_class.find_by user: user2
      expect(d.name).to eq("Search (From #{user.full_name})")
    end

    it "creates a notification for recipient" do
      search_setup.give_to user2
      expect(user2.messages.count).to eq 1
      msg = user2.messages.first
      expect(msg.subject).to eq "New Report from #{user.username}"
      # rubocop:disable Layout/LineLength
      expect(msg.body).to eq "#{user.username} has sent you a report titled #{search_setup.name}. Click <a href=\'#{Rails.application.routes.url_helpers.advanced_search_url(described_class.last.id, host: master_setup.request_host, protocol: 'http')}\'>here</a> to view it."
      # rubocop:enable Layout/LineLength
    end
  end

  describe "deep_copy" do
    let(:user) { Factory(:user) }

    let(:search_setup) do
      described_class.create!(name: "ABC", module_type: "Order", user: user, simple: false, download_format: 'csv', include_links: true, include_rule_links: true)
    end

    it "copies basic search setup" do
      d = search_setup.deep_copy "new"
      expect(d.id).not_to be_nil
      expect(d.id).not_to eq(search_setup.id)
      expect(d.name).to eq("new")
      expect(d.module_type).to eq("Order")
      expect(d.user).to eq(user)
      expect(d.simple).to be_falsey
      expect(d.download_format).to eq('csv')
      expect(d.include_links).to be_truthy
      expect(d.include_rule_links).to be_truthy
    end

    it "copies parameters" do
      search_setup.search_criterions.create!(model_field_uid: 'a', value: 'x', operator: 'y', status_rule_id: 1, custom_definition_id: 2)
      d = search_setup.deep_copy "new"
      expect(d.search_criterions.size).to eq(1)
      sc = d.search_criterions.first
      expect(sc.model_field_uid).to eq('a')
      expect(sc.value).to eq('x')
      expect(sc.operator).to eq('y')
      expect(sc.status_rule_id).to eq(1)
      expect(sc.custom_definition_id).to eq(2)
    end

    it "copies columns" do
      search_setup.search_columns.create!(model_field_uid: 'a', rank: 7, custom_definition_id: 9)
      d = search_setup.deep_copy "new"
      expect(d.search_columns.size).to eq(1)
      sc = d.search_columns.first
      expect(sc.model_field_uid).to eq('a')
      expect(sc.rank).to eq(7)
      expect(sc.custom_definition_id).to eq(9)
    end

    it "copies sorts" do
      search_setup.sort_criterions.create!(model_field_uid: 'a', rank: 5, custom_definition_id: 2, descending: true)
      d = search_setup.deep_copy "new"
      expect(d.sort_criterions.size).to eq(1)
      sc = d.sort_criterions.first
      expect(sc.model_field_uid).to eq('a')
      expect(sc.rank).to eq(5)
      expect(sc.custom_definition_id).to eq(2)
      expect(sc).to be_descending
    end

    it "does not copy schedules" do
      search_setup.search_schedules.create!
      d = search_setup.deep_copy "new"
      expect(d.search_schedules).to be_empty
    end

    it "copies schedules when told to do so" do
      search_setup.search_schedules.create!
      d = search_setup.deep_copy "new", true
      expect(d.search_schedules.size).to eq(1)
    end
  end

  describe "values" do
    let (:user) { Factory(:admin_user) }

    before do
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
          ss = described_class.new(module_type: cm.class_name)
          uids.each do |uid|
            mf = cm.model_fields[uid]
            next unless mf.can_view?(user)
            ss.search_columns.build(model_field_uid: uid, rank: (i += 1))
            ss.sort_criterions.build(model_field_uid: uid, rank: i)
            ss.search_criterions.build(model_field_uid: uid, operator: 'null')
          end
          # just making sure each query executes without error
          SearchQuery.new(ss, user).execute
        end
      end
    end
  end

  context "last_accessed" do
    let(:search_setup) { Factory :search_setup }

    it "returns the last_accessed time from an associated search run" do
      expect(search_setup.last_accessed).to be_nil
      now = Time.zone.now
      search_setup.search_runs.build last_accessed: now
      search_setup.save

      search_setup.last_accessed.to_i == now.to_i
    end
  end

  describe "max_results" do
    let (:user) { User.new }

    it "returns 25K results by default" do
      expect(subject.max_results(user)).to eq 25_000
    end

    it "returns 100K results for sys admins" do
      expect(user).to receive(:sys_admin?).and_return true
      expect(subject.max_results(user)).to eq 100_000
    end

    context "with class level method" do
      it "returns 25K results by default" do
        expect(subject.max_results(user)).to eq 25_000
      end

      it "returns 100K results for sys admins" do
        expect(user).to receive(:sys_admin?).and_return true
        expect(subject.max_results(user)).to eq 100_000
      end
    end
  end

  describe "ruby_date_format" do
    it "converts display/xls date format to ruby date format" do
      expect(described_class.ruby_date_format("yyyy-MM-dd")).to eq "%Y-%m-%d"
      expect(described_class.ruby_date_format("mm/DD/YYYY")).to eq "%m/%d/%Y"
      expect(described_class.ruby_date_format(nil)).to eq nil
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
