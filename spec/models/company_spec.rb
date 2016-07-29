require 'spec_helper'

describe Company do
  describe :migrate_accounts do
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
  describe :attachment_archive_enabled do
    before :each do
      @c = Factory(:company)
      dont_find = Factory(:company)
    end
    it "should return companies with attachment archive setups that include start date" do
      @c.create_attachment_archive_setup(:start_date=>Time.now)
      Company.attachment_archive_enabled.to_a.should == [@c]
    end
    it "should not return company with setup that doesn't have start_date" do
      @c.create_attachment_archive_setup()
      Company.attachment_archive_enabled.count.should == 0
    end
    it "should not return company without setup" do
      Company.attachment_archive_enabled.count.should == 0
    end
  end
  context "role scopes" do
    before :each do
      @dont_find = Factory(:company)
    end
    it "should find carriers" do
      c1 = Factory(:company,:carrier=>true)
      c2 = Factory(:company,:carrier=>true)
      Company.carriers.should == [c1,c2]
    end
    it "should find importers" do
      c1 = Factory(:company,:importer=>true)
      c2 = Factory(:company,:importer=>true)
      Company.importers.should == [c1,c2]
    end
    it "should find customers" do
      c1 = Factory(:company,:customer=>true)
      c2 = Factory(:company,:customer=>true)
      Company.customers.should == [c1,c2]
    end
    it "should find vendors" do
      c1 = Factory(:company,:vendor=>true)
      c2 = Factory(:company,:vendor=>true)
      Company.vendors.should == [c1,c2]
    end
  end
  describe 'linked_companies' do
    it 'should create and retrieve child companies' do
      parent = Factory(:company)
      child = Factory(:company)
      parent.linked_companies.push child
      parent = Company.find parent.id
      parent.linked_companies.should have(1).company
      parent.linked_companies.first.should == child
    end
  end
  describe 'unlinked_companies' do
    it 'should retrieve companies that are NOT linked to this one' do
      c = Factory(:company)
      linked_c = Factory(:company)
      c.linked_companies << linked_c
      unlinked_c = Factory(:company)
      c.unlinked_companies.should include(unlinked_c) #can't check equals because initializer creates extra "My Company" company
      c.unlinked_companies.should_not include(linked_c)
    end
  end
  describe "active_importers" do
    it "should retrieve any active importers for existing companies based on products" do
      @importer = Factory(:company, importer: true)
      @product = Factory(:product, importer: @importer)
      Company.active_importers.should include(@importer)
    end
    it "should retrieve any active importers for existing companies based on entries" do
      @importer = Factory(:company, importer: true)
      @entry = Factory(:entry, importer: @importer, file_logged_date: Time.now)
      Company.active_importers.should include(@importer)
    end
  end
  context 'security' do
    before :each do
      MasterSetup.get.update_attributes(:entry_enabled=>true,:broker_invoice_enabled=>true)
    end
    it 'should not allow duplicate alliance_customer_number' do
      c1 = Factory(:company,:alliance_customer_number=>'123')
      c2 = Company.new(:name=>'abc',:alliance_customer_number => c1.alliance_customer_number)
      c2.save.should be_false
      c2.errors.full_messages.first.should == "Alliance customer number is already taken."
    end
    context "trade lanes" do
      before :each do
        MasterSetup.any_instance.stub(:trade_lane_enabled?).and_return(true)
      end
      context '#view_trade_lanes? and #edit_trade_lanes' do
        it "should allow for master company" do
          c = Factory(:master_company)
          expect(c.view_trade_lanes?).to be_true
          expect(c.edit_trade_lanes?).to be_true
        end
        it "sould not allow for non-master company" do
          c = Factory(:company)
          expect(c.view_trade_lanes?).to be_false
          expect(c.edit_trade_lanes?).to be_false
        end
        it "should not allow if trade lanes not enabled" do
          MasterSetup.any_instance.stub(:trade_lane_enabled?).and_return(false)
          c = Factory(:master_company)
          expect(c.view_trade_lanes?).to be_false
          expect(c.edit_trade_lanes?).to be_false
        end
      end
    end
    context "trade preference programs" do
      it "should delegate view to trade_lanes" do
        c = Company.new
        c.should_receive(:view_trade_lanes?).and_return 'ABC'
        expect(c.view_trade_preference_programs?).to eq 'ABC'
      end
      it "should delegate edit to trade_lanes" do
        c = Company.new
        c.should_receive(:edit_trade_lanes?).and_return 'ABC'
        expect(c.edit_trade_preference_programs?).to eq 'ABC'
      end
    end
    context "security filings" do
      before :each do
        MasterSetup.any_instance.stub(:security_filing_enabled?).and_return(true)
      end
      context "view" do
        it "should allow for importers" do
          Company.new(:importer=>true).view_security_filings?.should be_true
        end
        it "should allow for brokers" do
          Company.new(:broker=>true).view_security_filings?.should be_true
        end
        it "should allow for master" do
          Company.new(:master=>true).view_security_filings?.should be_true
        end
        it "should not allow for non importer/broker/master" do
          Company.new.view_security_filings?.should be_false
        end
        it "should not allow if master setup is disabled" do
          MasterSetup.any_instance.stub(:security_filing_enabled?).and_return(false)
          Company.new(:master=>true).view_security_filings?.should be_false
        end
      end
      context "edit" do
        it "should allow for brokers" do
          Company.new(:broker=>true).edit_security_filings?.should be_true
        end
        it "should allow for master" do
          Company.new(:master=>true).edit_security_filings?.should be_true
        end
        it "should not allow for non broker/master" do
          Company.new.edit_security_filings?.should be_false
        end
        it "should not allow if master setup is disabled" do
          MasterSetup.any_instance.stub(:security_filing_enabled?).and_return(false)
          Company.new(:master=>true).edit_security_filings?.should be_false
        end
      end
      context "attach/comment" do
        it "should be true if view_security_filings is true" do
          c = Company.new
          c.should_receive(:view_security_filings?).twice.and_return(true)
          c.attach_security_filings?.should be_true
          c.comment_security_filings?.should be_true
        end
        it "should be false if view_security_filings is false" do
          c = Company.new
          c.should_receive(:view_security_filings?).twice.and_return(false)
          c.attach_security_filings?.should be_false
          c.comment_security_filings?.should be_false
        end
      end
    end
    context 'entries' do
      it 'should not allow view if master setup is disabled' do
        MasterSetup.get.update_attributes(:entry_enabled=>false)
        c = Factory(:company,:importer=>true)
        c.view_entries?.should be_false
        c.comment_entries?.should be_false
        c.attach_entries?.should be_false
      end
      it 'should allow master view/comment/attach' do
        c = Factory(:company,:master=>true)
        c.view_entries?.should be_true
        c.comment_entries?.should be_true
        c.attach_entries?.should be_true
      end
      it 'should allow importer view/comment/attach' do
        c = Factory(:company,:importer=>true)
        c.view_entries?.should be_true
        c.comment_entries?.should be_true
        c.attach_entries?.should be_true
      end
      it 'should not allow other company view/comment/attach' do
        c = Factory(:company,:importer=>false,:master=>false)
        c.view_entries?.should be_false
        c.comment_entries?.should be_false
        c.attach_entries?.should be_false
      end
    end
    context 'broker invoices' do
      it 'should not allow view if master setup is disabled' do
        MasterSetup.get.update_attributes(:broker_invoice_enabled=>false)
        c = Factory(:company,:importer=>true)
        c.view_broker_invoices?.should be_false
      end
      it 'should allow master view' do
        c = Factory(:company,:master=>true)
        c.view_broker_invoices?.should be_true
      end
      it 'should allow importer view' do
        c = Factory(:company,:importer=>true)
        c.view_broker_invoices?.should be_true
      end
      it 'should not allow other company view' do
        c = Factory(:company,:importer=>false,:master=>false)
        c.view_broker_invoices?.should be_false
      end
      it "should allow edit for master" do
        Company.new(:master=>true).edit_broker_invoices?.should be_true
      end
      it "should not allow edit for non-master" do
        Company.new(:master=>false).edit_broker_invoices?.should be_false
      end
    end
    context 'commercial invoices' do
      it 'should allow if entry is enabled' do
        Company.new.should be_view_commercial_invoices
        Company.new.should be_edit_commercial_invoices
      end
      it 'should not allow if entry is disabled' do
        MasterSetup.get.update_attributes(:entry_enabled=>false)
        Company.new.should_not be_view_commercial_invoices
        Company.new.should_not be_edit_commercial_invoices
      end
    end
    context 'projects' do
      it 'should allow for master company' do
        MasterSetup.get.update_attributes(project_enabled:true)
        expect(Company.new(master:true).view_projects?).to be_true
        expect(Company.new(master:true).edit_projects?).to be_true
      end
      it 'should not allow for non-master Company' do
        MasterSetup.get.update_attributes(project_enabled:true)
        expect(Company.new(master:false).view_projects?).to be_false
        expect(Company.new(master:false).edit_projects?).to be_false
      end
      it "should not allow if module disabled" do
        MasterSetup.get.update_attributes(project_enabled:false)
        expect(Company.new(master:true).view_projects?).to be_false
        expect(Company.new(master:true).edit_projects?).to be_false
      end
    end
  end

  describe "attachments.create!" do
    it 'should allow one or more attachments' do
      c = Factory(:company)
      c.attachments.create!(attached_file_name:"attachment1.jpg")
      c.attachments.create!(attached_file_name:"attachment2.jpg")
      c.attachments.length.should == 2
    end
  end

  describe "can_view?" do
    it "doesn't allow users from other companies to view the company" do
      my_company = Factory(:company)
      other_company = Factory(:company)
      user = Factory(:user, company: my_company)
      (other_company.can_view?(user)).should be_false
    end

    it "allows user to view linked companies" do
      my_company = Factory(:company)
      other_company = Factory(:company)
      user = Factory(:user, company: my_company)
      my_company.linked_companies << other_company

      (other_company.can_view?(user)).should be_true
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
      u.stub(:view_vendors?).and_return true
      expect(@c.can_view_as_vendor?(u)).to be_true
    end
    it "should pass if user can view_vendors? and user's company is linked" do
      u = Factory(:user,vendor_view:true)
      u.stub(:view_vendors?).and_return true
      u.company.linked_companies << @c
      expect(@c.can_view_as_vendor?(u)).to be_true
    end
    it "should pass if user can view_vendors? and user is from master company" do
      u = Factory(:master_user,vendor_view:true)
      u.stub(:view_vendors?).and_return true
      expect(@c.can_view_as_vendor?(u)).to be_true
    end
    it "should fail if user can view_vendors? and is from unrelated company" do
      u = Factory(:user,vendor_view:true)
      u.stub(:view_vendors?).and_return true
      expect(@c.can_view_as_vendor?(u)).to be_false
    end
    it "should fail if user cannot view_vendors?" do
      u = Factory(:user,vendor_view:false,company:@c)
      u.stub(:view_vendors?).and_return false
      expect(@c.can_view_as_vendor?(u)).to be_false
    end
    it "should fail if company is not a vendor?" do
      u = Factory(:user,vendor_view:true)
      u.stub(:view_vendors?).and_return true
      expect(u.company.can_view_as_vendor?(u)).to be_false
    end
  end

  describe "name_with_customer_number" do
    it "returns a string with the appropriate customer numbers appended to the name" do
      c = Factory(:company, name: "My Name")
      c.name_with_customer_number.should == "My Name"

      c.fenix_customer_number = "12345"
      c.name_with_customer_number.should == "My Name (12345)"

      c.fenix_customer_number = nil
      c.name_with_customer_number.should == "My Name"

      c.alliance_customer_number = "7890"
      c.name_with_customer_number.should == "My Name (7890)"

      c.fenix_customer_number = "ABCD"
      c.name_with_customer_number.should == "My Name (ABCD) (7890)"
    end
  end

  describe :has_vfi_invoice? do
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

end
