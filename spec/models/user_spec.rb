describe User do
  describe "locked?" do
    let(:user) { Factory.create(:user) }
    it 'returns false if user is not active' do
      user.update_attribute(:disabled, true)
      expect(user.locked?).to eq(false)
    end

    it 'returns true if password_expired is true' do
      user.update_attribute(:password_expired, true)
      expect(user.locked?).to eq(true)
    end

    it 'returns true if password_locked is true' do
      user.update_attribute(:password_locked, true)
      expect(user.locked?).to eq(true)
    end

  end

  describe "valid_password?" do
    it 'defers to PasswordValidationRegistry' do
      u = User.new
      p = 'password'
      expect(OpenChain::Registries::PasswordValidationRegistry).to receive(:valid_password?).with(u, p).and_return true
      expect(User.valid_password? u, p).to eq true
    end
  end

  describe "recent_passwords" do

    let!(:user) { Factory.create(:user) }
    it 'returns the 5 most recently used passwords' do
      # We would expect that password6 not be included in the return value as it is the oldest
      passwords = ["password1", "password2", "password3", "password4", "password5", "password6"]
      expected_passwords = passwords[0..4].map { |password| user.encrypt_password(user.password_salt, password)}

      [5, 10, 15, 20, 25, 30].each_with_index do |time_ago, index|
        UserPasswordHistory.create do |uph|
          uph.user_id = user.id
          uph.hashed_password = user.encrypt_password(user.password_salt, passwords[index])
          uph.password_salt = user.password_salt
          uph.created_at = uph.updated_at = time_ago.minutes.ago
        end
      end

      expect(user.recent_password_hashes.map { |password| password.hashed_password}).to eql expected_passwords
      expect(user.recent_password_hashes.map { |password| password.hashed_password}).to_not include(user.encrypt_password(user.password_salt, passwords[5]))
    end
  end

  describe "api_hash" do
    let (:user) { Factory(:user, first_name:'Joe', last_name:'User', username:'uname', email:'j@sample.com', department:'something', email_new_messages:true) }
    it "should get hash" do
      allow(user).to receive(:view_orders?).and_return true
      h = user.api_hash

      expect(h[:permissions][:view_orders]).to eq true
      expect(h[:permissions][:view_shipments]).to be_falsey
      # not testing every permission
      h.delete(:permissions)

      expected = {
        username:'uname',
        full_name:user.full_name,
        first_name:user.first_name,
        last_name:user.last_name,
        email:'j@sample.com',
        email_new_messages:true,
        id:user.id,
        company_id:user.company_id,
        department:user.department
      }
      expect(h).to eq expected
    end

    it "excludes permissions if requested not to" do
      h = user.api_hash include_permissions: false
      expect(h[:permissions]).to be_nil
      expect(h).to eq({
        username:'uname',
        full_name:user.full_name,
        first_name:user.first_name,
        last_name:user.last_name,
        email:'j@sample.com',
        email_new_messages:true,
        id:user.id,
        company_id:user.company_id,
        department:user.department
      })
    end
  end
  describe "groups" do
    before :each do
      @gA = Factory(:group,system_code:'groupA')

      @u1 = Factory(:user)
      @gA.users << @u1
      @u1.reload

      @gB = Factory(:group,system_code:'groupB')
    end
    it "should find in_group?" do
      expect(@u1.in_group?('groupA')).to be_truthy
      expect(@u1.in_group?(@gA)).to be_truthy
      expect(@u1.in_group?('groupB')).to be_falsey
      expect(@u1.in_group?(@gB)).to be_falsey
    end
    it "should find in_any_group?" do
      expect(@u1.in_any_group?(['groupA','groupB'])).to be_truthy
      expect(@u1.in_any_group?([@gA,@gB])).to be_truthy
      expect(@u1.in_any_group?(['groupB'])).to be_falsey
      expect(@u1.in_any_group?([@gB])).to be_falsey
    end
  end
  describe "available_importers" do
    before :each do
      @c1 = Factory(:company,importer:true)
      @c2 = Factory(:company,importer:true)
      @c3 = Factory(:company,importer:true)
      @c4 = Factory(:company) #not an importer
    end
    it "should show all importers if master company" do
      u = Factory(:master_user)
      expect(u.available_importers.to_a).to eq [@c1,@c2,@c3]
    end
    it "should show all linked importers" do
      u = Factory(:user,company:@c4)
      @c4.linked_companies << @c1
      expect(u.available_importers.to_a).to eq [@c1]
    end
    it "should show me if i'm an importer" do
      u = Factory(:user,company:@c2)
      @c2.linked_companies << @c1
      expect(u.available_importers.to_a).to eq [@c1,@c2]
    end
  end
  describe "api_admin" do
    it "should create api_admin if it doesn't exist" do
      u = User.api_admin
      expect(u.username).to eq 'ApiAdmin'
      expect(u.first_name).to eq 'API'
      expect(u.last_name).to eq 'Admin'
      expect(u.email).to eq 'bug+api_admin@vandegriftinc.com'
      expect(u.system_user).to be true
      expect(u.company).to be_master
      expect(u).to be_admin
      expect(u.api_auth_token).to_not be_blank
      expect(u.time_zone).to eq "Eastern Time (US & Canada)"
      expect(u.disallow_password).to be_truthy
    end
    it "should return api_admin if it exits" do
      u = Factory(:master_user,username:'ApiAdmin')
      expect(User.api_admin).to eq u
    end
  end
  describe "integration" do
    it "should create integration if it doesn't exist" do
      u = User.integration
      expect(u.username).to eq 'integration'
      expect(u.first_name).to eq 'Integration'
      expect(u.last_name).to eq 'User'
      expect(u.email).to eq 'bug+integration@vandegriftinc.com'
      expect(u.system_user).to be true
      expect(u.company).to be_master
      expect(u).to be_admin
      expect(u.api_auth_token).to_not be_blank
      expect(u.time_zone).to eq "Eastern Time (US & Canada)"
      expect(u.disallow_password).to be_truthy
    end
    it "should return integration if it exits" do
      u = Factory(:master_user,username:'integration')
      expect(User.integration).to eq u
    end
  end
  describe "magic_columns" do
    before :each do
      @updated_at = 1.year.ago
      @u = Factory(:user,:updated_at=>@updated_at)
    end
    it "should not update updated_at if only confirmation token changed" do
      @u.confirmation_token='12345'
      @u.save!
      expect(User.find(@u.id).updated_at.to_i).to eq(@updated_at.to_i)
      expect(User.record_timestamps).to be_truthy
    end
    it "should not update updated_at if only remember token changed" do
      @u.remember_token='12345'
      @u.save!
      expect(User.find(@u.id).updated_at.to_i).to eq(@updated_at.to_i)
      expect(User.record_timestamps).to be_truthy
    end
    it "should not update updated_at if only last request at changed" do
      @u.last_request_at = Time.zone.now
      @u.save!
      expect(User.find(@u.id).updated_at.to_i).to eq(@updated_at.to_i)
      expect(User.record_timestamps).to be_truthy
    end
    it "should not update updated_at if all no-update fields changed" do
      @u.confirmation_token='12345'
      @u.remember_token='12345'
      @u.last_request_at = Time.zone.now
      @u.save!
      expect(User.find(@u.id).updated_at.to_i).to eq(@updated_at.to_i)
      expect(User.record_timestamps).to be_truthy
    end
    it "should update updated_at if a standard column changes" do
      @u.update_attributes(:email=>'a@sample.com')
      expect(User.record_timestamps).to be_truthy
      expect(User.find(@u.id).updated_at).to be > 10.seconds.ago
    end
    it "should update updated_at if both standard and no-update columns change" do
      @u.update_attributes(:perishable_token=>'12345',:email=>'a@sample.com')
      expect(User.record_timestamps).to be_truthy
      expect(User.find(@u.id).updated_at).to be > 10.seconds.ago
    end
  end
  context "permissions" do
    context "vendors" do
      before :each do
        allow_any_instance_of(MasterSetup).to receive(:vendor_management_enabled?).and_return true
      end
      it "should allow when MasterSetup.vendor_management_enabled? and I have vendor_X permission" do
        expect(User.new(vendor_view:true).view_vendors?).to be_truthy
        expect(User.new(vendor_edit:true).edit_vendors?).to be_truthy
        expect(User.new(vendor_attach:true).attach_vendors?).to be_truthy
        expect(User.new(vendor_comment:true).comment_vendors?).to be_truthy
      end
      it "should not allow when !MasterSetup.vendor_management_enabled?" do
        allow_any_instance_of(MasterSetup).to receive(:vendor_management_enabled?).and_return false
        expect(User.new(vendor_view:true).view_vendors?).to be_falsey
        expect(User.new(vendor_edit:true).edit_vendors?).to be_falsey
        expect(User.new(vendor_attach:true).attach_vendors?).to be_falsey
        expect(User.new(vendor_comment:true).comment_vendors?).to be_falsey
      end
      it "should not allow when I dont have vendor_view permission" do
        expect(User.new.view_vendors?).to be_falsey
        expect(User.new.edit_vendors?).to be_falsey
        expect(User.new.attach_vendors?).to be_falsey
        expect(User.new.comment_vendors?).to be_falsey
      end
    end
    context "product_vendor_assignments" do
      it "should allow if corresponding vendor value is true" do
        u = User.new
        allow(u).to receive(:view_vendors?).and_return true
        allow(u).to receive(:edit_vendors?).and_return true
        allow(u).to receive(:create_vendors?).and_return true
        expect(u.view_product_vendor_assignments?).to be_truthy
        expect(u.edit_product_vendor_assignments?).to be_truthy
        expect(u.create_product_vendor_assignments?).to be_truthy
      end
      it "should not allow if corresponding vendor value is false" do
        u = User.new
        allow(u).to receive(:view_vendors?).and_return false
        allow(u).to receive(:edit_vendors?).and_return false
        allow(u).to receive(:create_vendors?).and_return false
        expect(u.view_product_vendor_assignments?).to be_falsey
        expect(u.edit_product_vendor_assignments?).to be_falsey
        expect(u.create_product_vendor_assignments?).to be_falsey
      end
    end
    context "official tariffs" do
      it "should allow master company user" do
        expect(Factory(:master_user)).to be_view_official_tariffs
      end
      it "should not allow non master company user" do
        expect(Factory(:user)).not_to be_view_official_tariffs
      end
      it "should allow if user can view products" do
        expect(Factory(:user,product_view:true).view_official_tariffs?).to be_truthy
      end
    end
    context "business_validation_results" do
      it "allows user if company has business rules viewing allowed" do
        u = User.new
        c = Company.new
        u.company = c
        c.show_business_rules = true
        expect(u.view_business_validation_results?).to be_truthy
        expect(u.edit_business_validation_results?).to be_truthy
      end
      it "doesn't allow if company cannot view business rules" do
        u = User.new
        c = Company.new
        u.company = c
        c.show_business_rules = false
        expect(u.view_business_validation_results?).to be_falsey
        expect(u.edit_business_validation_results?).to be_falsey
      end

      context "private rules" do
        it "allows master users" do
          u = Factory(:master_user)
          u.company.update_attributes(show_business_rules:true)
          expect(u.view_all_business_validation_results?).to be_truthy
          expect(u.edit_all_business_validation_results?).to be_truthy
        end

        it "doesn't allow importer users even if company has business-rules viewing allowed" do
          u = Factory(:importer_user)
          u.company.update_attributes(show_business_rules:true)
          expect(u.view_all_business_validation_results?).to be_falsey
          expect(u.edit_all_business_validation_results?).to be_falsey
        end   
      end
    end
    context "business_validation_rule_results" do
      it "should allow master users" do
        u = Factory(:master_user)
        u.company.update_attributes(show_business_rules:true)
        expect(u.view_business_validation_rule_results?).to be_truthy
        expect(u.edit_business_validation_rule_results?).to be_truthy
      end
      it "shouldn't allow non master users" do
        u = Factory(:importer_user)
        expect(u.view_business_validation_rule_results?).to be_falsey
        expect(u.edit_business_validation_rule_results?).to be_falsey
      end
      it "allows importer user if company has business rules viewing allowed" do
        u = Factory(:importer_user)
        u.company.update_attributes! show_business_rules: true

        expect(u.view_business_validation_rule_results?).to be_truthy
        expect(u.edit_business_validation_rule_results?).to be_truthy
      end
      
      context "private rules" do
        it "allows master users" do
          u = Factory(:master_user)
          u.company.update_attributes(show_business_rules:true)
          expect(u.view_all_business_validation_rule_results?).to be_truthy
          expect(u.edit_all_business_validation_rule_results?).to be_truthy
        end

        it "doesn't allow importer users even if company has business-rules viewing allowed" do
          u = Factory(:importer_user)
          u.company.update_attributes! show_business_rules: true

          expect(u.view_all_business_validation_rule_results?).to be_falsey
          expect(u.edit_all_business_validation_rule_results?).to be_falsey
        end
      end
    end
    context "projects" do
      it "should allow master company user with permission" do
        u = Factory(:master_user)
        expect(u.view_projects?).to be_falsey
        expect(u.edit_projects?).to be_falsey
        u.project_view = true
        expect(u.view_projects?).to be_truthy
        u.project_edit = true
        expect(u.edit_projects?).to be_truthy
      end
      it "should not allow non master company user" do
        u = Factory(:user)
        u.project_view = true
        u.project_edit = true
        expect(u.view_projects?).to be_falsey
        expect(u.edit_projects?).to be_falsey
      end
    end
    context "trade_lanes" do
      let(:user) do
        u = User.new(trade_lane_view:true,trade_lane_edit:true,trade_lane_comment:true,trade_lane_attach:true)
        u.company = Company.new
        allow(u.company).to receive(:view_trade_lanes?).and_return true
        allow(u.company).to receive(:edit_trade_lanes?).and_return true
        u
      end
      it "should allow for user whose company has permission" do
        u = user
        expect(u.view_trade_lanes?).to be_truthy
        expect(u.edit_trade_lanes?).to be_truthy
        expect(u.comment_trade_lanes?).to be_truthy
        expect(u.attach_trade_lanes?).to be_truthy
      end
      it "should not allow for user whose company does not have permission" do
        u = user
        allow(u.company).to receive(:view_trade_lanes?).and_return false
        allow(u.company).to receive(:edit_trade_lanes?).and_return false
        expect(u.view_trade_lanes?).to be_falsey
        expect(u.edit_trade_lanes?).to be_falsey
        expect(u.comment_trade_lanes?).to be_falsey
        expect(u.attach_trade_lanes?).to be_falsey
      end
      it "should not allow for user who does not have permission" do
        u = User.new
        expect(u.view_trade_lanes?).to be_falsey
        expect(u.edit_trade_lanes?).to be_falsey
        expect(u.comment_trade_lanes?).to be_falsey
        expect(u.attach_trade_lanes?).to be_falsey
      end
    end
    context "trade_preference_programs" do
      it "should delegate view to trade lanes method" do
        u = User.new
        expect(u).to receive(:view_trade_lanes?).and_return 'ABC'
        expect(u.view_trade_preference_programs?).to eq 'ABC'
      end
      it "should delegate edit to trade lanes method" do
        u = User.new
        expect(u).to receive(:edit_trade_lanes?).and_return 'ABC'
        expect(u.edit_trade_preference_programs?).to eq 'ABC'
      end
      it "should delegate comment to trade lanes method" do
        u = User.new
        expect(u).to receive(:comment_trade_lanes?).and_return 'ABC'
        expect(u.comment_trade_preference_programs?).to eq 'ABC'
      end
      it "should delegate attach to trade lanes method" do
        u = User.new
        expect(u).to receive(:attach_trade_lanes?).and_return 'ABC'
        expect(u.attach_trade_preference_programs?).to eq 'ABC'
      end
    end
    context "tpp_hts_overrides" do
      it "should delegate to trade_preference_programs" do
        u = User.new
        expect(u).to receive(:view_trade_preference_programs?).and_return 'view'
        expect(u).to receive(:edit_trade_preference_programs?).and_return 'edit'
        expect(u).to receive(:attach_trade_preference_programs?).and_return 'attach'
        expect(u).to receive(:comment_trade_preference_programs?).and_return 'comment'

        expect(u.view_tpp_hts_overrides?).to eq 'view'
        expect(u.edit_tpp_hts_overrides?).to eq 'edit'
        expect(u.attach_tpp_hts_overrides?).to eq 'attach'
        expect(u.comment_tpp_hts_overrides?).to eq 'comment'
      end
    end
    context "attachment_archives" do
      it "should allow for master user who can view entries" do
        u = Factory(:user,:company=>Factory(:company,:master=>true))
        allow(u).to receive(:view_entries?).and_return true
        expect(u).to be_view_attachment_archives
        expect(u).to be_edit_attachment_archives
      end
      it "should not allow for non-master user" do
        u = Factory(:user)
        allow(u).to receive(:view_entries?).and_return true
        expect(u).not_to be_view_attachment_archives
        expect(u).not_to be_edit_attachment_archives
      end
      it "should not allow for user who cannot view entries" do
        u = Factory(:user,:company=>Factory(:company,:master=>true))
        allow(u).to receive(:view_entries?).and_return false
        expect(u).not_to be_view_attachment_archives
        expect(u).not_to be_edit_attachment_archives
      end
    end
    context "security filing" do
      context "company has permission" do
        before :each do
          allow_any_instance_of(Company).to receive(:view_security_filings?).and_return(true)
          allow_any_instance_of(Company).to receive(:edit_security_filings?).and_return(true)
          allow_any_instance_of(Company).to receive(:attach_security_filings?).and_return(true)
          allow_any_instance_of(Company).to receive(:comment_security_filings?).and_return(true)
        end
        it "should allow if permission set and company has permission" do
          u = Factory(:user,:security_filing_view=>true,:security_filing_edit=>true,:security_filing_attach=>true,:security_filing_comment=>true)
          expect(u.view_security_filings?).to be_truthy
          expect(u.edit_security_filings?).to be_truthy
          expect(u.attach_security_filings?).to be_truthy
          expect(u.comment_security_filings?).to be_truthy
        end
        it "should not allow if user permission not set and company has permission" do
          u = Factory(:user,:security_filing_view=>false,:security_filing_edit=>false,:security_filing_attach=>false,:security_filing_comment=>false)
          expect(u.view_security_filings?).to be_falsey
          expect(u.edit_security_filings?).to be_falsey
          expect(u.attach_security_filings?).to be_falsey
          expect(u.comment_security_filings?).to be_falsey
        end
      end
      it "should not allow if company does not have permission" do
        allow_any_instance_of(Company).to receive(:view_security_filings?).and_return(false)
        allow_any_instance_of(Company).to receive(:edit_security_filings?).and_return(false)
        allow_any_instance_of(Company).to receive(:attach_security_filings?).and_return(false)
        allow_any_instance_of(Company).to receive(:comment_security_filings?).and_return(false)
        u = Factory(:user,:security_filing_view=>true,:security_filing_edit=>true,:security_filing_attach=>true,:security_filing_comment=>true)
        expect(u.view_security_filings?).to be_falsey
        expect(u.edit_security_filings?).to be_falsey
        expect(u.attach_security_filings?).to be_falsey
        expect(u.comment_security_filings?).to be_falsey
      end
    end
    context "drawback" do
      before :each do
        MasterSetup.get.update_attributes(:drawback_enabled=>true)
      end
      it "should allow user to view if permission is set and drawback enabled" do
        expect(Factory(:user,:drawback_view=>true).view_drawback?).to be_truthy
      end
      it "should allow user to edit if permission is set and drawback enabled" do
        expect(Factory(:user,:drawback_edit=>true).edit_drawback?).to be_truthy
      end
      it "should not allow view/edit if drawback not enabled" do
        MasterSetup.get.update_attributes(:drawback_enabled=>false)
        u = Factory(:user,:drawback_view=>true,:drawback_edit=>true)
        expect(u.view_drawback?).to be_falsey
        expect(u.edit_drawback?).to be_falsey
      end
      it "should now allow if permissions not set" do
        u = Factory(:user)
        expect(u.view_drawback?).to be_falsey
        expect(u.edit_drawback?).to be_falsey
      end
    end
    context "broker invoice" do
      context "with company permission" do
        before :each do
          allow_any_instance_of(Company).to receive(:edit_broker_invoices?).and_return(true)
          allow_any_instance_of(Company).to receive(:view_broker_invoices?).and_return(true)
        end
        it "should allow view if permission is set" do
          expect(Factory(:user,:broker_invoice_view=>true).view_broker_invoices?).to be_truthy
        end
        it "should allow edit if permission is set" do
          expect(Factory(:user,:broker_invoice_edit=>true).edit_broker_invoices?).to be_truthy
        end
        it "should not allow view without permission" do
          expect(Factory(:user,:broker_invoice_view=>false).view_broker_invoices?).to be_falsey
        end
        it "should not allow edit without permission" do
          expect(Factory(:user,:broker_invoice_edit=>false).edit_broker_invoices?).to be_falsey
        end
      end
      context "without company permission" do
        before :each do
          allow_any_instance_of(Company).to receive(:edit_broker_invoices?).and_return(false)
          allow_any_instance_of(Company).to receive(:view_broker_invoices?).and_return(false)
        end
        it "should not allow view even if permission is set" do
          expect(Factory(:user,:broker_invoice_view=>true).view_broker_invoices?).to be_falsey
        end
        it "should not allow edit even if permission is set" do
          expect(Factory(:user,:broker_invoice_edit=>true).edit_broker_invoices?).to be_falsey
        end
      end
    end
    context "vfi invoice" do
      context "with company permission" do
        before :each do
          allow_any_instance_of(Company).to receive(:edit_vfi_invoices?).and_return true
          allow_any_instance_of(Company).to receive(:view_vfi_invoices?).and_return true
        end
        it "should allow view if permission is set" do
          expect(Factory(:user,:vfi_invoice_view=>true).view_vfi_invoices?).to be_truthy
        end
        it "should allow edit if permission is set" do
          expect(Factory(:user,:vfi_invoice_edit=>true).edit_vfi_invoices?).to be_truthy
        end
        it "should not allow view without permission" do
          expect(Factory(:user,:vfi_invoice_view=>false).view_vfi_invoices?).to be_falsey
        end
        it "should not allow edit without permission" do
          expect(Factory(:user,:vfi_invoice_edit=>false).edit_vfi_invoices?).to be_falsey
        end
      end
      context "without company permission" do
        before :each do
          allow_any_instance_of(Company).to receive(:edit_vfi_invoices?).and_return(false)
          allow_any_instance_of(Company).to receive(:view_vfi_invoices?).and_return(false)
        end
        it "should not allow view even if permission is set" do
          expect(Factory(:user,:vfi_invoice_view=>true).view_vfi_invoices?).to be_falsey
        end
        it "should not allow edit even if permission is set" do
          expect(Factory(:user,:vfi_invoice_edit=>true).edit_vfi_invoices?).to be_falsey
        end
      end
    end
    context "survey" do
      it "should pass view_surveys?" do
        expect(User.new(:survey_view=>true).view_surveys?).to be_truthy
      end
      it "should pass edit_surveys?" do
        expect(User.new(:survey_edit=>true).edit_surveys?).to be_truthy
      end
      it "should fail view_surveys?" do
        expect(User.new(:survey_view=>false).view_surveys?).to be_falsey
      end
      it "should fail edit_surveys?" do
        expect(User.new(:survey_edit=>false).edit_surveys?).to be_falsey
      end
    end
    context "entry" do
      before :each do
        @company = Factory(:company,:broker=>true)
      end
      it "should allow user to edit entry if permission is set and company is not broker" do
        expect(Factory(:user,:entry_edit=>true,:company=>@company)).to be_edit_entries
      end
      it "should not allow user to edit entry if permission is not set" do
        expect(User.new(:company=>@company)).not_to be_edit_entries
      end
      it "should not allow user to edit entry if company is not broker" do
        @company.update_attributes(:broker=>false)
        expect(User.new(:entry_edit=>true,:company_id=>@company.id)).not_to be_edit_entries
      end
    end

    # Commercial Invoices fall under entry edit/view permissions.

    context "variant" do
      before :each do
        @u = Factory(:master_user, product_edit: true)
      end
      context "enabled" do
        before :each do
          MasterSetup.get.update_attributes(variant_enabled: true)
        end

        it "should pass with user enabled" do
          @u.update_attributes(variant_edit:true)
          expect(@u.add_variants?).to be_truthy
          expect(@u.edit_variants?).to be_truthy
        end
        it "should fail with user not enabled" do
          expect(@u.add_variants?).to be_falsey
          expect(@u.edit_variants?).to be_falsey
        end
      end
      context "disabled" do
        before :each do
          MasterSetup.get.update_attributes(variant_enabled: false)
        end

        it "should fail with user enabled" do
          @u.update_attributes(variant_edit:true)
          expect(@u.add_variants?).to be_falsey
          expect(@u.edit_variants?).to be_falsey
        end
        it "should fail with user not enabled" do
          expect(@u.add_variants?).to be_falsey
          expect(@u.edit_variants?).to be_falsey
        end
      end
    end

    context "powers of attorney" do
      let!(:poa) { Factory(:power_of_attorney) }
      let!(:group) { Factory(:group, system_code: "maintain_poa")}
      let!(:user) { Factory(:user) }

      describe "edit_power_of_attorneys?" do
        it "returns true if user is a member of group" do
          group.users << user
          expect(user.edit_power_of_attorneys?).to eq true
        end
        
        it "returns false if user isn't a member of group" do
          expect(user.edit_power_of_attorneys?).to eq false
        end

        it "returns true if user is an admin" do
          user.admin = true; user.save!
          expect(user.edit_power_of_attorneys?).to eq true
        end
      end

      describe "view_power_of_attorneys?" do
        it "returns true if user can edit powers of attorney" do
          expect(user).to receive(:edit_power_of_attorneys?).and_return true
          expect(user.view_power_of_attorneys?).to eq true
        end

        it "returns false if user can't edit powers of attorney" do
          expect(user).to receive(:edit_power_of_attorneys?).and_return false
          expect(user.view_power_of_attorneys?).to eq false
        end
      end
    end
  end

  context "run_with_user_settings" do

    before :each do
      @user = User.current
      @time = Time.zone

      @run_as = User.new :name => 'Run As', :time_zone => "Hawaii"
      @current_user = User.new :name => 'Current', :time_zone => "UTC"
      User.current = @current_user
      Time.zone = @current_user.time_zone
    end

    after :each do
      User.current = @user
      Time.zone = @time
    end

    it "should set/unset User settings" do

      val = User.run_with_user_settings(@run_as) do
        expect(User.current).to eq(@run_as)
        expect(Time.zone).to eq(ActiveSupport::TimeZone[@run_as.time_zone])
        "abcdefg"
      end
      # Just make sure the method returns whatever the block returns
      expect(val).to eq("abcdefg")

      expect(User.current).to eq(@current_user)
      expect(Time.zone).to eq(ActiveSupport::TimeZone[@current_user.time_zone])
    end

    it "should set/unset User settings even if block raises an Exception" do
      # Exception is used here since it's the base for any other errors (even syntax or "severe" runtime issues)
      expect {
        User.run_with_user_settings(@run_as) {
          raise Exception, "Error"
        }
      }.to raise_exception "Error"

      expect(User.current).to eq(@current_user)
      expect(Time.zone).to eq(ActiveSupport::TimeZone[@current_user.time_zone])
    end

    it "should not set Time.zone if user has no timezone" do
      # the main admin user doesn't appear to have timezone set. User.run_with.. handles this
      # scenario just in case.
      @run_as.time_zone = ""

      User.run_with_user_settings(@run_as) do
        expect(User.current).to eq(@run_as)
        expect(Time.zone).to eq(ActiveSupport::TimeZone[@current_user.time_zone])
      end

      expect(User.current).to eq(@current_user)
      expect(Time.zone).to eq(ActiveSupport::TimeZone[@current_user.time_zone])
    end
  end
  describe 'hidden messages' do
    it "should add hidden message" do
      u = User.new
      u.add_hidden_message 'h1'
      expect(u.hide_message?('h1')).to be_truthy
    end
    it "should remove hidden message" do
      u = User.new
      u.add_hidden_message 'hx'
      u.remove_hidden_message 'hx'
      expect(u.hide_message?('hx')).to be_falsey
    end
    it "should save hidden messages" do
      u = Factory(:user)
      u.add_hidden_message 'hx'
      u.add_hidden_message 'abc'
      u.save!
      u = User.find(u.id)
      expect(u.hide_message?('hx')).to be_truthy
      expect(u.hide_message?('abc')).to be_truthy
    end
    it "should be case insensitive" do
      u = User.new
      u.add_hidden_message 'hx'
      expect(u.hide_message?('HX')).to be_truthy
    end
  end
  context "send_invite_emails" do
    it "should send an invite email to a user" do
      e = double("Email")
      expect(e).to receive(:deliver_now!)
      u = Factory(:user)

      expect_any_instance_of(User).to receive(:update_user_password).with(instance_of(String), instance_of(String), true, false).and_call_original

      expect(OpenMailer).to receive(:send_invite) do |user, password|
        expect(user.id).to eq(u.id)
        # Make sure the password has been updated by checking the encrypted
        # versions
        expect(user.encrypted_password).not_to eq(u.encrypted_password)
        expect(password.length).to eq 8
        expect(user.password_reset).to be_truthy
        e
      end

      User.send_invite_emails u.id
    end

    it "should send an invite email to an admin user" do
      e = double("Email")
      expect(e).to receive(:deliver_now!)
      u = Factory(:user, admin:true)

      expect(OpenMailer).to receive(:send_invite) do |user, password|
        expect(user.id).to eq(u.id)
        # Make sure the password has been updated by checking the encrypted
        # versions
        expect(user.encrypted_password).not_to eq(u.encrypted_password)
        # Longer default password than standard user.
        expect(password.length).to eq 16
        expect(user.password_reset).to be_truthy
        e
      end

      User.send_invite_emails u.id
    end

    it "should send an invite email to multiple users" do
      e = double("email")
      expect(e).to receive(:deliver_now!).twice
      expect(OpenMailer).to receive(:send_invite).twice.and_return(e)

      u = Factory(:user)
      User.send_invite_emails [u.id, u.id]
    end
  end

  describe "authenticate" do
    before :each do
      @user = Factory :user, password: "abc"
    end

    it "validates user exists with specified password" do
      expect(User.authenticate @user.username, "abc").to eq @user
    end

    it "returns nil if user is not found" do
      expect(User.authenticate "notauser", "abc").to be_nil
    end

    it "returns nil if user password is incorrect" do
      expect(User.authenticate @user.username, "notmypassword").to be_nil
    end

    it "calls FailedPasswordHandler if authentication fails" do
      klass = OpenChain::UserSupport::FailedPasswordHandler
      expect(klass).to receive(:call)
      User.authenticate @user.username, "notmypassword"
    end

    it "returns nil if user can't use password login" do
      @user.update_attributes(disallow_password:true)
      expect(User.authenticate @user.username, "abc").to be_nil
    end
  end

  describe "access_allowed?" do
    it "validates user is not nill" do
      expect(User.access_allowed? nil).to be_falsey
    end

    it "validates user is not disabled?" do
      user = User.new
      user.disabled = true
      expect(User.access_allowed? user).to be_falsey
    end

    it "validates user company is not locked" do
      user = Factory(:user, company: Factory(:company, locked: true))
      expect(User.access_allowed? user).to be_falsey
    end

    it "validates user" do
      user = Factory(:user)
      expect(User.access_allowed? user).to be_truthy
    end
  end

  describe "update_user_password" do
    before :each do
      @user = Factory(:user)
    end

    it 'creates user_password_histories record if password is valid' do
      @user.update_attributes! time_zone:"Central Time (US & Canada)"
      Timecop.freeze(Time.zone.parse("2019-09-09 09:09:00 +0200")) do
        @user.update_user_password 'newpassword', 'newpassword'
        expect(User.authenticate @user.username, 'newpassword').to eq @user
        @user.reload
        expect(@user.user_password_histories.first.hashed_password).to eq(@user.encrypted_password)
        expect(@user.user_password_histories.first.password_salt).to eq(@user.password_salt)

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq [@user.email]
        expect(mail.subject).to eq "VFI Track Password Change"
        # Change time should be in Central, not UTC+2 (Kaliningrad/European summer time).
        expect(mail.body).to include "<p>This email was sent to notify you that the password for your VFI Track account ‘#{@user.username}’ was changed on 2019-09-09 02:09.</p><p>If you did not initiate this password change, it may indicate your account has been compromised.  Please notify support@vandegriftinc.com of this situation.</p>".html_safe
      end
    end

    it 'creates user_password_histories record if password is valid, user has no default time zone' do
      @user.update_attributes! time_zone:nil
      Timecop.freeze(Time.zone.parse("2019-09-09 09:09:00 +0200")) do
        @user.update_user_password 'newpassword', 'newpassword'
        expect(User.authenticate @user.username, 'newpassword').to eq @user
        @user.reload
        expect(@user.user_password_histories.first.hashed_password).to eq(@user.encrypted_password)
        expect(@user.user_password_histories.first.password_salt).to eq(@user.password_salt)

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq [@user.email]
        expect(mail.subject).to eq "VFI Track Password Change"
        # Change time should be displayed in default UTC zone.
        expect(mail.body).to include "<p>This email was sent to notify you that the password for your VFI Track account ‘#{@user.username}’ was changed on 2019-09-09 07:09.</p><p>If you did not initiate this password change, it may indicate your account has been compromised.  Please notify support@vandegriftinc.com of this situation.</p>".html_safe
      end
    end

    it "sets password_changed_at" do
      Timecop.freeze(Time.zone.now) do
        @user.update_user_password 'newpassword', 'newpassword'
        expect(User.authenticate @user.username, 'newpassword').to eq @user
        expect(@user.password_changed_at).to eql(Time.zone.now)
      end
    end

    it "updates a user password with valid info" do
      # Update the password and then validate that our authenticate method confirms
      # the password now matches the hash that our new password generates
      @user.update_user_password 'newpassword', 'newpassword'
      expect(User.authenticate @user.username, 'newpassword').to eq @user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.subject).to eq "VFI Track Password Change"
    end

    it "does not send password change email if told to not do so" do
      @user.update_user_password 'newpassword', 'newpassword', true, false
      expect(User.authenticate @user.username, 'newpassword').to eq @user

      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it "validates password confirmation matches password" do
      @user.update_user_password 'newpassword', 'notmatched'
      expect(@user.errors.full_messages).to eq ["Password must match password confirmation."]
    end

    it "skips fails if password is blank" do
      expect(@user.update_user_password ' ', 'notmatched').to be_falsey
      expect(@user.errors[:password]).to eq ["cannot be blank."]
      expect(User.authenticate @user.username, ' ').to be_nil
    end
  end

  describe "on_successful_login" do
    it "sets last_login_at, current_login_at, failed_login_count and creates a history record" do
      user = Factory(:user, current_login_at: Date.new(2014,1,1), failed_login_count: 10)
      last_login = user.current_login_at
      updated_at = user.updated_at

      request = double("request")
      allow(request).to receive(:host_with_port).and_return "localhost:3000"

      user.on_successful_login request

      user.reload
      expect(user.last_login_at).to eq last_login
      expect(user.current_login_at).to be >= 5.seconds.ago
      expect(user.failed_login_count).to eq 0
      expect(user.failed_logins).to eq 0
      expect(user.host_with_port).to eq "localhost:3000"
      # Don't want the login to update the user timestamps
      expect(user.updated_at.to_i).to eq updated_at.to_i
      expect(user.histories.where(history_type: 'login', company_id: user.company.id).first).to_not be_nil

    end

    it "doesn't update host with port if it's not blank" do
      user = Factory(:user, host_with_port: "www.test.com")
      user.on_successful_login double("request")

      user.reload
      expect(user.host_with_port).to eq "www.test.com"
    end
  end

  describe "from_omniauth" do
    before :each do
      @user = Factory(:user, email: "condoleeza@rice.com")
    end

    context "google oauth" do
      it "should return an updated user when a user is found" do
        info = OpenStruct.new({"email" => "condoleeza@rice.com", "name" => "Condoleeza R"})
        creds = OpenStruct.new({"token" => "123456789", "expires_at" => (Time.now + 5.days).to_i})
        auth = OpenStruct.new({"info" => info, "provider" => "oauth", "uid" => "someuid123", "credentials" => creds})

        expect(User.from_omniauth("google_oauth2", auth)).to eq ({user: @user, errors: []})

        @user.reload
        expect(@user.provider).to eq("oauth")
        expect(@user.uid).to eq("someuid123")
        expect(@user.google_name).to eq("Condoleeza R")
        expect(@user.oauth_token).to eq("123456789")
        expect(@user.oauth_expires_at > Time.now).to eq(true)
      end

      it "should return nil if the user is not found" do
        info = OpenStruct.new({"email" => "susan@rice.com", "name" => "Condoleeza R"})
        creds = OpenStruct.new({"token" => "123456789", "expires_at" => (Time.now + 5.days).to_i})
        auth = OpenStruct.new({"info" => info, "provider" => "google_oauth2", "uid" => "someuid123", "credentials" => creds})

        expect(User.from_omniauth("google_oauth2", auth)).to eq ({user: nil, errors: ["Google email account susan@rice.com has not been set up in VFI Track. If you would like to request an account, please click the 'Need an account?' link below."]})
      end
    end

    context "azure oauth" do
      let(:auth) { {"info" => {"email" => "susan@maersk.com"}}.with_indifferent_access }
      
      it "returns user when found" do
        @user.update_attributes! email: "susan@maersk.com"
        expect(User.from_omniauth("azure_oauth2", auth)).to eq ({user: @user, errors: []})
      end

      it "returns nil if user not found" do
        expect(User.from_omniauth("azure_oauth2", auth)).to eq ({user: nil, errors: ["Maersk email account susan@maersk.com has not been set up in VFI Track. If you would like to request an account, please click the 'Need an account?' link below."]})
      end
    end

    context "pepsi SAML" do
      it "finds user by uid from SAML response" do
        expect(User.from_omniauth("pepsi-saml", OpenStruct.new({"uid" => @user.username}))).to eq ({user: @user, errors: []})
      end

      it "returns an error if user is not found" do
        expect(User.from_omniauth("pepsi-saml", OpenStruct.new({"uid" => "notausername"}))).to eq ({user: nil, errors: ["Pepsi User ID notausername has not been set up in VFI Track."]})
      end
    end
  end

  describe "username uniqueness" do
    it "should prevent duplicate usernames without case sensitivity" do
      c = Factory(:company)
      u1 = User.new(email: "example@example.com", username: "username")
      u1.password = "password"
      u1.company = c
      u1.save!

      u2 = User.new(email: "example2@example.com", username: "username")
      u2.password = "password"
      u2.company = c
      expect{ u2.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Username has already been taken")

      u3 = User.new(email: "example2@example.com", username: "USERNAME")
      u3.password = "password"
      u3.company = c
      expect{ u3.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Username has already been taken")
    end
  end

  describe "email validation" do
    it "should update email field if all members of semicolon/comma-separated list match regex pattern" do
      u = Factory(:user, email: "default@vandegriftinc.com")
      list = "abc@exam-ple.net, nbc123@vandegriftinc.com; cbs_1@britishcompany.co.uk; 1@2.3.com, philip.glass@mail.ymu-global.com"
      u.update_attributes(email: list)
      u.reload
      expect(u.email).to eq list
      expect(u.errors.messages[:email]).to be_nil
    end

    it "should not update email field if any member of semicolon/comma-separated list fails to match regex pattern" do
      u = Factory(:user, email: "default@vandegriftinc.com")
      list = "abc@example.*et, nbc123grifter.com; cbs@somewhere.org"
      u.update_attributes(email: list)
      u.reload
      expect(u.email).to eq "default@vandegriftinc.com"
      expect(u.errors.full_messages).to eq ["Email invalid: abc@example.*et, nbc123grifter.com"]
    end

    it "should have a different error for one invalid email" do
      u = Factory(:user, email: "default@vandegriftinc.com")
      addr = "abc@example.*et"
      u.update_attributes(email: addr)
      u.reload
      expect(u.email).to eq "default@vandegriftinc.com"
      expect(u.errors.full_messages).to eq ["Email invalid"]
    end

    it "should prevent duplicate emails without case sensitivity" do
      c = Factory(:company)
      u1 = User.new(email: "example@example.com", username: "username")
      u1.password = "password"
      u1.company = c
      u1.save!

      u2 = User.new(email: "example@example.com", username: "somethingelse")
      u2.password = "password"
      u2.company = c
      expect{ u2.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Email has already been taken")
    end
  end

  describe "portal_redirect_path" do
    it "should return nil if portal_mode.blank?" do
      expect(User.new.portal_redirect_path).to be_nil
    end
    it "should return nil if portal_mode not found in list" do
      expect(User.new(portal_mode:'ABC').portal_redirect_path).to be_nil
    end
    it "should return portal redirect for vendor" do
      expect(User.new(portal_mode:'vendor').portal_redirect_path).to eq '/vendor_portal'
    end
  end

  describe "url" do
    it "returns user's nested url" do
      stub_master_setup
      u = Factory(:user)
      expect(u.url).to eq "https://localhost:3000/companies/#{u.company.id}/users/#{u.id}"
    end
  end

  describe "view_statements?" do
    let (:user) { Factory(:user, statement_view: true) }

    it "allows users with statement view and company access to view statements" do
      expect(user.company).to receive(:view_statements?).and_return true
      expect(user.view_statements?).to eq true
    end

    it "disallows users whose companies can't view statements from viewing statements" do 
      expect(user.company).to receive(:view_statements?).and_return false
      expect(user.view_statements?).to eq false
    end

    it "disallows users without permission" do
      user.statement_view = false
      expect(user.company).not_to receive(:view_statements?)
      expect(user.view_statements?).to eq false
    end
  end

  describe "user_auth_token" do
    let (:user) { 
      Factory(:user, username: "username", api_auth_token: "authtoken")
    }

    it "returns token if already set" do
      expect(user.user_auth_token).to eq "username:authtoken"
    end

    it "generates a new authtoken and saves user if token is not already set" do
      user.api_auth_token = nil
      user.save!
      expect(User).to receive(:generate_authtoken).with(user).and_return "newtoken"

      expect(user.user_auth_token).to eq "username:newtoken"

      user.reload
      expect(user.api_auth_token).to eq "newtoken"
    end
  end
end
