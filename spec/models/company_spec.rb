describe Company do

  describe "attachment_archive_enabled" do
    let (:company) { create(:company) }
    let! (:another_company) { create(:company) }

    it "returns companies with attachment archive setups that include start date" do
      company.create_attachment_archive_setup(start_date: Time.zone.now)
      expect(described_class.attachment_archive_enabled.to_a).to eq([company])
    end

    it "does not return company with setup that doesn't have start_date" do
      company.create_attachment_archive_setup
      expect(described_class.attachment_archive_enabled.count).to eq(0)
    end

    it "does not return company without setup" do
      expect(described_class.attachment_archive_enabled.count).to eq(0)
    end
  end

  context "role scopes" do
    before do
      @dont_find = create(:company)
    end

    it "finds carriers" do
      c1 = create(:company, carrier: true)
      c2 = create(:company, carrier: true)
      expect(described_class.carriers).to eq([c1, c2])
    end

    it "finds importers" do
      c1 = create(:company, importer: true)
      c2 = create(:company, importer: true)
      expect(described_class.importers).to eq([c1, c2])
    end

    it "finds customers" do
      c1 = create(:company, customer: true)
      c2 = create(:company, customer: true)
      expect(described_class.customers).to eq([c1, c2])
    end

    it "finds vendors" do
      c1 = create(:company, vendor: true)
      c2 = create(:company, vendor: true)
      expect(described_class.vendors).to eq([c1, c2])
    end
  end

  describe 'linked_companies' do
    it 'creates and retrieve child companies' do
      parent = create(:company)
      child = create(:company)
      parent.linked_companies.push child
      parent = described_class.find parent.id
      expect(parent.linked_companies.size).to eq(1)
      expect(parent.linked_companies.first).to eq(child)
    end
  end

  describe 'unlinked_companies' do
    it 'retrieves companies that are NOT linked to this one' do
      c = create(:company)
      linked_c = create(:company)
      c.linked_companies << linked_c
      unlinked_c = create(:company)
      expect(c.unlinked_companies).to include(unlinked_c) # can't check equals because initializer creates extra "My Company" company
      expect(c.unlinked_companies).not_to include(linked_c)
    end
  end

  describe "active_importers" do
    let (:importer) { create(:importer) }

    it "retrieves any active importers for existing companies based on products" do
      create(:product, importer: importer)
      expect(described_class.active_importers).to include(importer)
    end

    it "retrieves any active importers for existing companies based on entries" do
      create(:entry, importer: importer, file_logged_date: Time.zone.now)
      expect(described_class.active_importers).to include(importer)
    end
  end

  context 'security' do

    let! (:master_setup) do
      ms = stub_master_setup
      allow(ms).to receive(:entry_enabled).and_return true
      allow(ms).to receive(:broker_invoice_enabled).and_return true
      ms
    end

    context "trade lanes" do
      before do
        allow(master_setup).to receive(:trade_lane_enabled?).and_return(true)
      end

      describe '#view_trade_lanes? and #edit_trade_lanes' do
        it "allows for master company" do
          c = create(:master_company)
          expect(c).to be_view_trade_lanes
          expect(c).to be_edit_trade_lanes
        end

        it "sould not allow for non-master company" do
          c = create(:company)
          expect(c).not_to be_view_trade_lanes
          expect(c).not_to be_edit_trade_lanes
        end

        it "does not allow if trade lanes not enabled" do
          allow(master_setup).to receive(:trade_lane_enabled?).and_return(false)
          c = create(:master_company)
          expect(c).not_to be_view_trade_lanes
          expect(c).not_to be_edit_trade_lanes
        end
      end
    end

    context "trade preference programs" do
      it "delegates view to trade_lanes" do
        c = described_class.new
        expect(c).to receive(:view_trade_lanes?).and_return 'ABC'
        expect(c.view_trade_preference_programs?).to eq 'ABC'
      end

      it "delegates edit to trade_lanes" do
        c = described_class.new
        expect(c).to receive(:edit_trade_lanes?).and_return 'ABC'
        expect(c.edit_trade_preference_programs?).to eq 'ABC'
      end
    end

    context "security filings" do
      before do
        allow(master_setup).to receive(:security_filing_enabled?).and_return(true)
      end

      context "view" do
        it "allows for importers" do
          expect(described_class.new(importer: true)).to be_view_security_filings
        end

        it "allows for brokers" do
          expect(described_class.new(broker: true)).to be_view_security_filings
        end

        it "allows for master" do
          expect(described_class.new(master: true)).to be_view_security_filings
        end

        it "does not allow for non importer/broker/master" do
          expect(described_class.new).not_to be_view_security_filings
        end

        it "does not allow if master setup is disabled" do
          allow(master_setup).to receive(:security_filing_enabled?).and_return(false)
          expect(described_class.new(master: true)).not_to be_view_security_filings
        end
      end

      context "edit" do
        it "allows for brokers" do
          expect(described_class.new(broker: true)).to be_edit_security_filings
        end

        it "allows for master" do
          expect(described_class.new(master: true)).to be_edit_security_filings
        end

        it "does not allow for non broker/master" do
          expect(described_class.new).not_to be_edit_security_filings
        end

        it "does not allow if master setup is disabled" do
          allow(master_setup).to receive(:security_filing_enabled?).and_return(false)
          expect(described_class.new(master: true)).not_to be_edit_security_filings
        end
      end

      context "attach/comment" do
        it "is true if view_security_filings is true" do
          c = described_class.new
          expect(c).to receive(:view_security_filings?).twice.and_return(true)
          expect(c).to be_attach_security_filings
          expect(c).to be_comment_security_filings
        end

        it "is false if view_security_filings is false" do
          c = described_class.new
          expect(c).to receive(:view_security_filings?).twice.and_return(false)
          expect(c).not_to be_attach_security_filings
          expect(c).not_to be_comment_security_filings
        end
      end
    end

    context 'entries' do
      it 'does not allow view if master setup is disabled' do
        allow(master_setup).to receive(:entry_enabled).and_return false
        c = create(:company, importer: true)
        expect(c).not_to be_view_entries
        expect(c).not_to be_comment_entries
        expect(c).not_to be_attach_entries
      end

      it 'allows master view/comment/attach' do
        c = create(:company, master: true)
        expect(c).to be_view_entries
        expect(c).to be_comment_entries
        expect(c).to be_attach_entries
      end

      it 'allows importer view/comment/attach' do
        c = create(:company, importer: true)
        expect(c).to be_view_entries
        expect(c).to be_comment_entries
        expect(c).to be_attach_entries
      end

      it 'allows broker view/comment/attach' do
        c = create(:company, broker: true)
        expect(c).to be_view_entries
        expect(c).to be_comment_entries
        expect(c).to be_attach_entries
      end

      it 'does not allow other company view/comment/attach' do
        c = create(:company, importer: false, master: false)
        expect(c).not_to be_view_entries
        expect(c).not_to be_comment_entries
        expect(c).not_to be_attach_entries
      end
    end

    context 'broker invoices' do
      it 'does not allow view if master setup is disabled' do
        allow(master_setup).to receive(:broker_invoice_enabled).and_return false
        c = create(:company, importer: true)
        expect(c).not_to be_view_broker_invoices
      end

      it 'allows master view' do
        c = create(:company, master: true)
        expect(c).to be_view_broker_invoices
      end

      it 'allows importer view' do
        c = create(:company, importer: true)
        expect(c).to be_view_broker_invoices
      end

      it 'does not allow other company view' do
        c = create(:company, importer: false, master: false)
        expect(c).not_to be_view_broker_invoices
      end

      it "allows edit for master" do
        expect(described_class.new(master: true)).to be_edit_broker_invoices
      end

      it "does not allow edit for non-master" do
        expect(described_class.new(master: false)).not_to be_edit_broker_invoices
      end
    end

    context 'customer invoices' do
      it 'allows if invoices are enabled' do
        allow(master_setup).to receive(:invoices_enabled?).and_return true
        expect(described_class.new.view_commercial_invoices?).to eq true
        expect(described_class.new.view_customer_invoices?).to eq true
        expect(described_class.new.edit_commercial_invoices?).to eq true
        expect(described_class.new.edit_customer_invoices?).to eq true
      end

      it 'does not allow if entry is disabled' do
        allow(master_setup).to receive(:invoices_enabled?).and_return false
        expect(described_class.new.view_commercial_invoices?).to eq false
        expect(described_class.new.view_customer_invoices?).to eq false
        expect(described_class.new.edit_commercial_invoices?).to eq false
        expect(described_class.new.edit_customer_invoices?).to eq false
      end
    end
  end

  describe "attachments.create!" do
    it 'allows one or more attachments' do
      c = create(:company)
      c.attachments.create!(attached_file_name: "attachment1.jpg")
      c.attachments.create!(attached_file_name: "attachment2.jpg")
      expect(c.attachments.length).to eq(2)
    end
  end

  describe "can_view?" do
    it "doesn't allow users from other companies to view the company" do
      my_company = create(:company)
      other_company = create(:company)
      user = create(:user, company: my_company)
      expect(other_company).not_to be_can_view(user)
    end

    it "allows user to view linked companies" do
      my_company = create(:company)
      other_company = create(:company)
      user = create(:user, company: my_company)
      my_company.linked_companies << other_company

      expect(other_company).to be_can_view(user)
    end
  end

  describe "search_secure" do
    subject { described_class }

    let (:user) { create(:user) }
    let (:company) { create(:company) }
    let! (:another_company) { create(:company) }

    it "allows me to see myself" do
      expect(subject.search_secure(user, subject).to_a).to eq [user.company]
    end

    it "allows me to see my linked companies" do
      c2 = create(:company)
      user.company.linked_companies << c2
      found = described_class.search_secure(user, described_class).to_a
      expect(found).to include user.company
      expect(found).to include c2
    end

    it "allows me to see all if I'm master" do
      user.company.update! master: true
      create(:company)
      found = described_class.search_secure(user, described_class).to_a
      subject.all.to_a.each {|c| expect(found).to include c }
    end
  end

  describe "can_view_as_vendor?" do
    let (:vendor) { create(:company, vendor: true) }

    it "passes if user can view_vendors? and user is from this company" do
      u = create(:user, vendor_view: true, company: vendor)
      allow(u).to receive(:view_vendors?).and_return true
      expect(vendor).to be_can_view_as_vendor(u)
    end

    it "passes if user can view_vendors? and user's company is linked" do
      u = create(:user, vendor_view: true)
      allow(u).to receive(:view_vendors?).and_return true
      u.company.linked_companies << vendor
      expect(vendor).to be_can_view_as_vendor(u)
    end

    it "passes if user can view_vendors? and user is from master company" do
      u = create(:master_user, vendor_view: true)
      allow(u).to receive(:view_vendors?).and_return true
      expect(vendor).to be_can_view_as_vendor(u)
    end

    it "fails if user can view_vendors? and is from unrelated company" do
      u = create(:user, vendor_view: true)
      allow(u).to receive(:view_vendors?).and_return true
      expect(vendor).not_to be_can_view_as_vendor(u)
    end

    it "fails if user cannot view_vendors?" do
      u = create(:user, vendor_view: false, company: vendor)
      allow(u).to receive(:view_vendors?).and_return false
      expect(vendor).not_to be_can_view_as_vendor(u)
    end

    it "fails if company is not a vendor?" do
      u = create(:user, vendor_view: true)
      allow(u).to receive(:view_vendors?).and_return true
      expect(u.company).not_to be_can_view_as_vendor(u)
    end
  end

  describe "name_with_customer_number" do
    let (:company) { create(:company, name: "My Name")}

    it "returns a string with just the customer number" do
      expect(company.name_with_customer_number).to eq("My Name")
    end

    it "adds Customs Management Number" do
      with_customs_management_id(company, "KEWILL")
      expect(company.name_with_customer_number).to eq("My Name (KEWILL)")
    end

    it "adds Fenix number" do
      with_fenix_id(company, "FENIX")
      expect(company.name_with_customer_number).to eq("My Name (FENIX)")
    end

    it "adds Cargowise Number" do
      with_cargowise_id(company, "CW1")
      expect(company.name_with_customer_number).to eq("My Name (CW1)")
    end
  end

  describe "has_vfi_invoice?" do
    let(:co) { create(:company) }
    let(:inv) { create(:vfi_invoice) }

    it "returns 'true' if company has a vfi invoice" do
      inv.update!(customer: co)
      expect(co.has_vfi_invoice?).to eq true
    end

    it "returns 'true' if there's a linked company with a vfi invoice" do
      linked_co = create(:company)
      co.update!(linked_companies: [linked_co])
      inv.update!(customer: linked_co)
      expect(co.has_vfi_invoice?).to eq true
    end

    it "returns false if neither the company nor any of the linked companies have a vfi invoice" do
      linked_co = create(:company)
      co.update!(linked_companies: [linked_co])
      expect(co.has_vfi_invoice?).to eq false
    end
  end

  describe "slack_channel scope" do
    it 'returns only companies with slack channels' do
      no_slack_channel = create(:company, name: 'Slackless')
      slack_channel = create(:company, name: 'Slackfull', slack_channel: 'a_channel')

      results = described_class.has_slack_channel.to_a
      expect(results).to include(slack_channel)
      expect(results).not_to include(no_slack_channel)
    end
  end

  describe "name_with_system_code" do
    it "returns name concatenated with system_code if it exists" do
      co = create(:company, name: "ACME", system_code: "sys code")
      expect(co.name_with_system_code).to eq "ACME (sys code)"
    end

    it "returns name if system_code doesn't exist" do
      co = create(:company, name: "ACME")
      expect(co.name_with_system_code).to eq "ACME"
    end
  end

  describe "linked_company?" do
    let (:company) { create(:company) }

    it "returns true if companies are linked" do
      linked = create(:company)
      company.linked_companies << linked

      expect(company.linked_company?(linked)).to eq true
    end

    it "returns false if companies are not linked" do
      linked = create(:company)

      expect(company.linked_company?(linked)).to eq false
    end

    it "returns true if company is same" do
      expect(company.linked_company?(company)).to eq true
    end

    it "returns false when an inverse link is not present" do
      linked = create(:company)
      company.linked_companies << linked

      expect(linked.linked_company?(company)).to eq false
    end
  end

  describe "view_statements" do
    let (:master_setup) { stub_master_setup }

    context "with statements enabled" do
      before do
        allow(master_setup).to receive(:customs_statements_enabled?).and_return true
      end

      it "allows master companies to view statements" do
        expect(create(:master_company).view_statements?).to eq true
      end

      it "allows importers to view statements" do
        expect(create(:company, importer: true).view_statements?).to eq true
      end

      it "doesn't allow other company types to view statements" do
        expect(create(:company).view_statements?).to eq false
      end
    end

    it "doesn't allow access to statements if they are disabled" do
      expect(master_setup).to receive(:customs_statements_enabled?).and_return false
      expect(create(:master_company).view_statements?).to eq false
    end
  end

  describe "parent_system_code" do
    let (:company) { create(:company) }
    let! (:parent_company) do
      f = create(:company)
      f.linked_companies << company
      f
    end

    it "returns nil if parent company doesn't have system code" do
      expect(company.parent_system_code).to be_nil
    end

    context "with parental system code configured" do

      before do
        parent_company.update! system_code: "SYSTEM"
      end

      it "returns parent system code" do
        expect(company.parent_system_code).to eq "SYSTEM"
      end

      it "memoizes result" do
        company.parent_system_code
        parent_company.update! system_code: "NOTSYSTEM"
        expect(company.parent_system_code).to eq "SYSTEM"
      end
    end
  end

  describe "find_or_create_company!" do
    subject { described_class }

    it "creates a new company with a system identifier" do
      expect(Lock).to receive(:acquire).with("Company-System-Code").and_yield
      expect(Lock).to receive(:db_lock).with(instance_of(SystemIdentifier)).and_yield

      c = subject.find_or_create_company!("System", "Code", {name: "Name"})
      expect(c).to be_persisted
      expect(c).to have_system_identifier("System", "Code")
      expect(c.name).to eq "Name"
    end

    it "finds an exisiting company" do
      c = create(:company)
      c.system_identifiers.create! system: "System", code: "Code"

      c1 = subject.find_or_create_company!("System", "Code", {name: "Name"})
      expect(c1).to eq c
    end

    it "creates company if identifier doesn't have one yet" do
      id = SystemIdentifier.create! system: "System", code: "Code"

      c = subject.find_or_create_company!("System", "Code", {name: "Name"})
      expect(c.system_identifiers.first).to eq id
    end
  end

  describe "options_for_companies_with_system_identifier" do
    let! (:kewill_company) do
      with_customs_management_id(create(:company, name: "Z Company", system_code: "SYSCODE"), "KEWILL")
    end

    let (:fenix_company) do
      with_fenix_id(create(:company, name: "A Company", system_code: "SYSCODE2"), "FENIX")
    end

    it "returns array of values suitable to be used in options_for_select methods" do
      expect(described_class.options_for_companies_with_system_identifier("Customs Management")).to eq [["Z Company (KEWILL)", kewill_company.id]]
    end

    it "allows using a different code attribute" do
      expect(described_class.options_for_companies_with_system_identifier("Customs Management",
                                                                          code_attribute: :system_code)).to eq [["Z Company (SYSCODE)", kewill_company.id]]
    end

    it "allows using a table + column for code attribute" do
      expect(described_class.options_for_companies_with_system_identifier("Customs Management",
                                                                          code_attribute: [:companies, :system_code])).to eq [["Z Company (SYSCODE)", kewill_company.id]]
    end

    it "allows using a different value attribute" do
      expect(described_class.options_for_companies_with_system_identifier("Customs Management", value_attribute: :system_code)).to eq [["Z Company (KEWILL)", "SYSCODE"]]
    end

    it "allows using a table + column for value attribute" do
      expect(described_class.options_for_companies_with_system_identifier("Customs Management",
                                                                          value_attribute: [:system_identifiers, :code])).to eq [["Z Company (KEWILL)", "KEWILL"]]
    end

    it "allows using an outer join to include companies without the codes specified" do
      fenix_company
      expect(described_class.options_for_companies_with_system_identifier("Customs Management",
                                                                          join_type: :outer)).to eq [["A Company", fenix_company.id],
                                                                                                     ["Z Company (KEWILL)", kewill_company.id]]
    end

    it "allows changing the sort order" do
      fenix_company
      expect(described_class.options_for_companies_with_system_identifier("Customs Management",
                                                                          order: [{name: :desc}], join_type: :outer)).to eq [["Z Company (KEWILL)", kewill_company.id],
                                                                                                                             ["A Company", fenix_company.id]]
    end

    it "allows providing a relation to use to only return results belonging to that relation" do
      with_customs_management_id(create(:company), "KEWILL2")

      expect(described_class.options_for_companies_with_system_identifier("Customs Management",
                                                                          in_relation: described_class.where(id: kewill_company.id))).to eq [["Z Company (KEWILL)",
                                                                                                                                              kewill_company.id]]
    end
  end

  describe "set_system_identifier" do
    let(:company) { create(:company) }

    it "sets a system identifier" do
      company.set_system_identifier("TEST", "TESTING")
      expect(company).to have_system_identifier("TEST", "TESTING")
    end

    it "clears an existing identifier" do
      with_fenix_id(company, "F")
      company.set_system_identifier("Fenix", "")
      expect(company).not_to have_system_identifier("Fenix", "F")
    end
  end
end
