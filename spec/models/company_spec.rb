describe Company do
  describe "migrate_accounts" do
    before :each do
      @c1 = Factory(:company)
      @c2 = Factory(:company)
    end
    it "should move user accounts" do
      u1 = Factory(:user,company_id:@c1.id,updated_at:10.days.ago)
      u2 = Factory(:user,company_id:@c1.id)
      Factory(:user)
      @c1.migrate_accounts @c2
      @c2.reload
      expect(@c2.users.order(:id).count).to eq 2
      u1.reload
      u2.reload
      expect(u1.company).to eq @c2
      expect(u1.updated_at).to be > 5.seconds.ago
      expect(u2.company).to eq @c2
    end
    it "should move surveys" do
      s = Factory(:survey,company_id:@c1.id)
      @c1.migrate_accounts @c2
      s.reload
      expect(s.company).to eq @c2
    end
  end
  describe "attachment_archive_enabled" do
    before :each do
      @c = Factory(:company)
      dont_find = Factory(:company)
    end
    it "should return companies with attachment archive setups that include start date" do
      @c.create_attachment_archive_setup(:start_date=>Time.now)
      expect(Company.attachment_archive_enabled.to_a).to eq([@c])
    end
    it "should not return company with setup that doesn't have start_date" do
      @c.create_attachment_archive_setup()
      expect(Company.attachment_archive_enabled.count).to eq(0)
    end
    it "should not return company without setup" do
      expect(Company.attachment_archive_enabled.count).to eq(0)
    end
  end
  context "role scopes" do
    before :each do
      @dont_find = Factory(:company)
    end
    it "should find carriers" do
      c1 = Factory(:company,:carrier=>true)
      c2 = Factory(:company,:carrier=>true)
      expect(Company.carriers).to eq([c1,c2])
    end
    it "should find importers" do
      c1 = Factory(:company,:importer=>true)
      c2 = Factory(:company,:importer=>true)
      expect(Company.importers).to eq([c1,c2])
    end
    it "should find customers" do
      c1 = Factory(:company,:customer=>true)
      c2 = Factory(:company,:customer=>true)
      expect(Company.customers).to eq([c1,c2])
    end
    it "should find vendors" do
      c1 = Factory(:company,:vendor=>true)
      c2 = Factory(:company,:vendor=>true)
      expect(Company.vendors).to eq([c1,c2])
    end
  end
  describe 'linked_companies' do
    it 'should create and retrieve child companies' do
      parent = Factory(:company)
      child = Factory(:company)
      parent.linked_companies.push child
      parent = Company.find parent.id
      expect(parent.linked_companies.size).to eq(1)
      expect(parent.linked_companies.first).to eq(child)
    end
  end
  describe 'unlinked_companies' do
    it 'should retrieve companies that are NOT linked to this one' do
      c = Factory(:company)
      linked_c = Factory(:company)
      c.linked_companies << linked_c
      unlinked_c = Factory(:company)
      expect(c.unlinked_companies).to include(unlinked_c) #can't check equals because initializer creates extra "My Company" company
      expect(c.unlinked_companies).not_to include(linked_c)
    end
  end
  describe "active_importers" do
    it "should retrieve any active importers for existing companies based on products" do
      @importer = Factory(:company, importer: true)
      @product = Factory(:product, importer: @importer)
      expect(Company.active_importers).to include(@importer)
    end
    it "should retrieve any active importers for existing companies based on entries" do
      @importer = Factory(:company, importer: true)
      @entry = Factory(:entry, importer: @importer, file_logged_date: Time.now)
      expect(Company.active_importers).to include(@importer)
    end
  end
  context 'security' do
    before :each do
      MasterSetup.get.update_attributes(:entry_enabled=>true,:broker_invoice_enabled=>true)
    end
    it 'should not allow duplicate alliance_customer_number' do
      c1 = Factory(:company,:alliance_customer_number=>'123')
      c2 = Company.new(:name=>'abc',:alliance_customer_number => c1.alliance_customer_number)
      expect(c2.save).to be_falsey
      expect(c2.errors.full_messages.first).to eq("Alliance customer number is already taken.")
    end
    context "trade lanes" do
      before :each do
        allow_any_instance_of(MasterSetup).to receive(:trade_lane_enabled?).and_return(true)
      end
      context '#view_trade_lanes? and #edit_trade_lanes' do
        it "should allow for master company" do
          c = Factory(:master_company)
          expect(c.view_trade_lanes?).to be_truthy
          expect(c.edit_trade_lanes?).to be_truthy
        end
        it "sould not allow for non-master company" do
          c = Factory(:company)
          expect(c.view_trade_lanes?).to be_falsey
          expect(c.edit_trade_lanes?).to be_falsey
        end
        it "should not allow if trade lanes not enabled" do
          allow_any_instance_of(MasterSetup).to receive(:trade_lane_enabled?).and_return(false)
          c = Factory(:master_company)
          expect(c.view_trade_lanes?).to be_falsey
          expect(c.edit_trade_lanes?).to be_falsey
        end
      end
    end
    context "trade preference programs" do
      it "should delegate view to trade_lanes" do
        c = Company.new
        expect(c).to receive(:view_trade_lanes?).and_return 'ABC'
        expect(c.view_trade_preference_programs?).to eq 'ABC'
      end
      it "should delegate edit to trade_lanes" do
        c = Company.new
        expect(c).to receive(:edit_trade_lanes?).and_return 'ABC'
        expect(c.edit_trade_preference_programs?).to eq 'ABC'
      end
    end
    context "security filings" do
      before :each do
        allow_any_instance_of(MasterSetup).to receive(:security_filing_enabled?).and_return(true)
      end
      context "view" do
        it "should allow for importers" do
          expect(Company.new(:importer=>true).view_security_filings?).to be_truthy
        end
        it "should allow for brokers" do
          expect(Company.new(:broker=>true).view_security_filings?).to be_truthy
        end
        it "should allow for master" do
          expect(Company.new(:master=>true).view_security_filings?).to be_truthy
        end
        it "should not allow for non importer/broker/master" do
          expect(Company.new.view_security_filings?).to be_falsey
        end
        it "should not allow if master setup is disabled" do
          allow_any_instance_of(MasterSetup).to receive(:security_filing_enabled?).and_return(false)
          expect(Company.new(:master=>true).view_security_filings?).to be_falsey
        end
      end
      context "edit" do
        it "should allow for brokers" do
          expect(Company.new(:broker=>true).edit_security_filings?).to be_truthy
        end
        it "should allow for master" do
          expect(Company.new(:master=>true).edit_security_filings?).to be_truthy
        end
        it "should not allow for non broker/master" do
          expect(Company.new.edit_security_filings?).to be_falsey
        end
        it "should not allow if master setup is disabled" do
          allow_any_instance_of(MasterSetup).to receive(:security_filing_enabled?).and_return(false)
          expect(Company.new(:master=>true).edit_security_filings?).to be_falsey
        end
      end
      context "attach/comment" do
        it "should be true if view_security_filings is true" do
          c = Company.new
          expect(c).to receive(:view_security_filings?).twice.and_return(true)
          expect(c.attach_security_filings?).to be_truthy
          expect(c.comment_security_filings?).to be_truthy
        end
        it "should be false if view_security_filings is false" do
          c = Company.new
          expect(c).to receive(:view_security_filings?).twice.and_return(false)
          expect(c.attach_security_filings?).to be_falsey
          expect(c.comment_security_filings?).to be_falsey
        end
      end
    end
    context 'entries' do
      it 'should not allow view if master setup is disabled' do
        MasterSetup.get.update_attributes(:entry_enabled=>false)
        c = Factory(:company,:importer=>true)
        expect(c.view_entries?).to be_falsey
        expect(c.comment_entries?).to be_falsey
        expect(c.attach_entries?).to be_falsey
      end
      it 'should allow master view/comment/attach' do
        c = Factory(:company,:master=>true)
        expect(c.view_entries?).to be_truthy
        expect(c.comment_entries?).to be_truthy
        expect(c.attach_entries?).to be_truthy
      end
      it 'should allow importer view/comment/attach' do
        c = Factory(:company,:importer=>true)
        expect(c.view_entries?).to be_truthy
        expect(c.comment_entries?).to be_truthy
        expect(c.attach_entries?).to be_truthy
      end
      it 'should not allow other company view/comment/attach' do
        c = Factory(:company,:importer=>false,:master=>false)
        expect(c.view_entries?).to be_falsey
        expect(c.comment_entries?).to be_falsey
        expect(c.attach_entries?).to be_falsey
      end
    end
    context 'broker invoices' do
      it 'should not allow view if master setup is disabled' do
        MasterSetup.get.update_attributes(:broker_invoice_enabled=>false)
        c = Factory(:company,:importer=>true)
        expect(c.view_broker_invoices?).to be_falsey
      end
      it 'should allow master view' do
        c = Factory(:company,:master=>true)
        expect(c.view_broker_invoices?).to be_truthy
      end
      it 'should allow importer view' do
        c = Factory(:company,:importer=>true)
        expect(c.view_broker_invoices?).to be_truthy
      end
      it 'should not allow other company view' do
        c = Factory(:company,:importer=>false,:master=>false)
        expect(c.view_broker_invoices?).to be_falsey
      end
      it "should allow edit for master" do
        expect(Company.new(:master=>true).edit_broker_invoices?).to be_truthy
      end
      it "should not allow edit for non-master" do
        expect(Company.new(:master=>false).edit_broker_invoices?).to be_falsey
      end
    end
    context 'customer invoices' do
      it 'should allow if invoices are enabled' do
        MasterSetup.get.update_attributes(:invoices_enabled=>true)
        expect(Company.new.view_commercial_invoices?).to eq true
        expect(Company.new.view_customer_invoices?).to eq true
        expect(Company.new.edit_commercial_invoices?).to eq true
        expect(Company.new.edit_customer_invoices?).to eq true
      end
      it 'should not allow if entry is disabled' do
        MasterSetup.get.update_attributes(:invoices_enabled=>false)
        expect(Company.new.view_commercial_invoices?).to eq false
        expect(Company.new.view_customer_invoices?).to eq false
        expect(Company.new.edit_commercial_invoices?).to eq false
        expect(Company.new.edit_customer_invoices?).to eq false
      end
    end
    context 'projects' do
      it 'should allow for master company' do
        MasterSetup.get.update_attributes(project_enabled:true)
        expect(Company.new(master:true).view_projects?).to be_truthy
        expect(Company.new(master:true).edit_projects?).to be_truthy
      end
      it 'should not allow for non-master Company' do
        MasterSetup.get.update_attributes(project_enabled:true)
        expect(Company.new(master:false).view_projects?).to be_falsey
        expect(Company.new(master:false).edit_projects?).to be_falsey
      end
      it "should not allow if module disabled" do
        MasterSetup.get.update_attributes(project_enabled:false)
        expect(Company.new(master:true).view_projects?).to be_falsey
        expect(Company.new(master:true).edit_projects?).to be_falsey
      end
    end
  end

  describe "attachments.create!" do
    it 'should allow one or more attachments' do
      c = Factory(:company)
      c.attachments.create!(attached_file_name:"attachment1.jpg")
      c.attachments.create!(attached_file_name:"attachment2.jpg")
      expect(c.attachments.length).to eq(2)
    end
  end

  describe "can_view?" do
    it "doesn't allow users from other companies to view the company" do
      my_company = Factory(:company)
      other_company = Factory(:company)
      user = Factory(:user, company: my_company)
      expect(other_company.can_view?(user)).to be_falsey
    end

    it "allows user to view linked companies" do
      my_company = Factory(:company)
      other_company = Factory(:company)
      user = Factory(:user, company: my_company)
      my_company.linked_companies << other_company

      expect(other_company.can_view?(user)).to be_truthy
    end
  end

  describe "search_secure" do
    it "allows me to see myself" do
      u = Factory(:user)
      dont_find = Factory(:company)
      expect(Company.search_secure(u,Company).to_a).to eq [u.company]
    end
    it "allows me to see my linked companies" do
      u = Factory(:user)
      c2 = Factory(:company)
      u.company.linked_companies << c2
      dont_find = Factory(:company)
      expect(Company.search_secure(u,Company).to_a).to eq [u.company,c2]
    end
    it "allows me to see all if I'm master" do
      u = Factory(:master_user)
      c2 = Factory(:company)
      expect(Company.search_secure(u,Company).to_a).to eq Company.all.to_a
    end
  end

  describe "can_view_as_vendor?" do
    before :each do
      @c = Factory(:company,vendor:true)
    end
    it "should pass if user can view_vendors? and user is from this company" do
      u = Factory(:user,vendor_view:true,company:@c)
      allow(u).to receive(:view_vendors?).and_return true
      expect(@c.can_view_as_vendor?(u)).to be_truthy
    end
    it "should pass if user can view_vendors? and user's company is linked" do
      u = Factory(:user,vendor_view:true)
      allow(u).to receive(:view_vendors?).and_return true
      u.company.linked_companies << @c
      expect(@c.can_view_as_vendor?(u)).to be_truthy
    end
    it "should pass if user can view_vendors? and user is from master company" do
      u = Factory(:master_user,vendor_view:true)
      allow(u).to receive(:view_vendors?).and_return true
      expect(@c.can_view_as_vendor?(u)).to be_truthy
    end
    it "should fail if user can view_vendors? and is from unrelated company" do
      u = Factory(:user,vendor_view:true)
      allow(u).to receive(:view_vendors?).and_return true
      expect(@c.can_view_as_vendor?(u)).to be_falsey
    end
    it "should fail if user cannot view_vendors?" do
      u = Factory(:user,vendor_view:false,company:@c)
      allow(u).to receive(:view_vendors?).and_return false
      expect(@c.can_view_as_vendor?(u)).to be_falsey
    end
    it "should fail if company is not a vendor?" do
      u = Factory(:user,vendor_view:true)
      allow(u).to receive(:view_vendors?).and_return true
      expect(u.company.can_view_as_vendor?(u)).to be_falsey
    end
  end

  describe "name_with_customer_number" do
    it "returns a string with the appropriate customer numbers appended to the name" do
      c = Factory(:company, name: "My Name")
      expect(c.name_with_customer_number).to eq("My Name")

      c.fenix_customer_number = "12345"
      expect(c.name_with_customer_number).to eq("My Name (12345)")

      c.fenix_customer_number = nil
      expect(c.name_with_customer_number).to eq("My Name")

      c.alliance_customer_number = "7890"
      expect(c.name_with_customer_number).to eq("My Name (7890)")

      c.fenix_customer_number = "ABCD"
      expect(c.name_with_customer_number).to eq("My Name (ABCD) (7890)")
    end
  end

  describe "has_vfi_invoice?" do
    let(:co) { Factory(:company) }
    let(:inv) { Factory(:vfi_invoice) }

    it "returns 'true' if company has a vfi invoice" do
      inv.update_attributes(customer: co)
      expect(co.has_vfi_invoice?).to eq true
    end

    it "returns 'true' if there's a linked company with a vfi invoice" do
      linked_co = Factory(:company)
      co.update_attributes(linked_companies: [linked_co])
      inv.update_attributes(customer: linked_co)
      expect(co.has_vfi_invoice?).to eq true
    end

    it "returns false if neither the company nor any of the linked companies have a vfi invoice" do
      linked_co = Factory(:company)
      co.update_attributes(linked_companies: [linked_co])
      expect(co.has_vfi_invoice?).to eq false
    end
  end

  describe "slack_channel scope" do
    it 'returns only companies with slack channels' do
      no_slack_channel = Factory(:company, name: 'Slackless')
      slack_channel = Factory(:company, name: 'Slackfull', slack_channel: 'a_channel')

      results = Company.has_slack_channel.to_a
      expect(results).to include(slack_channel)
      expect(results).to_not include(no_slack_channel)
    end
  end

  describe "name_with_system_code" do
    it "returns name concatenated with system_code if it exists" do
      co = Factory(:company, name: "ACME", system_code: "sys code")
      expect(co.name_with_system_code).to eq "ACME (sys code)"
    end

    it "returns name if system_code doesn't exist" do
      co = Factory(:company, name: "ACME")
      expect(co.name_with_system_code).to eq "ACME"
    end
  end

  describe "linked_company?" do
    let (:company) { Factory(:company) }

    it "returns true if companies are linked" do
      linked = Factory(:company)
      company.linked_companies << linked

      expect(company.linked_company? linked).to eq true
    end

    it "returns false if companies are not linked" do
      linked = Factory(:company)

      expect(company.linked_company? linked).to eq false
    end

    it "returns true if company is same" do
      expect(company.linked_company? company).to eq true
    end

    it "returns false when an inverse link is not present" do
      linked = Factory(:company)
      company.linked_companies << linked

      expect(linked.linked_company? company).to eq false
    end
  end
  
  describe "view_statements" do 
    let (:master_setup) { stub_master_setup }

    context "with statements enabled" do
      before :each do 
        allow(master_setup).to receive(:customs_statements_enabled?).and_return true
      end

      it "allows master companies to view statements" do
        expect(Factory(:master_company).view_statements?).to eq true
      end

      it "allows importers to view statements" do
        expect(Factory(:company, importer: true).view_statements?).to eq true
      end

      it "doesn't allow other company types to view statements" do
        expect(Factory(:company).view_statements?).to eq false
      end
    end

    it "doesn't allow access to statements if they are disabled" do
      expect(master_setup).to receive(:customs_statements_enabled?).and_return false
      expect(Factory(:master_company).view_statements?).to eq false
    end
  end
end
