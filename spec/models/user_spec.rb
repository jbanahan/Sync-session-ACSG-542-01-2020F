describe User do
  describe "new_announcements" do
    let(:user) { Factory(:user, time_zone: "Eastern Time (US & Canada)") }
    let(:now) { Time.zone.now }

    it "returns associated announcements within date range for type 'all' in descending order" do
      anc1 = Factory(:announcement, category: 'all', start_at: now - 1.day, end_at: now + 1.day)
      anc2 = Factory(:announcement, category: 'all', start_at: now - 1.day, end_at: now + 1.day)
      anc3 = Factory(:announcement, category: 'all', start_at: now - 1.day, end_at: now + 1.day)

      [anc1, anc2, anc3].each_with_index do |a, idx|
        # test sorting
        a.created_at = now - (10 - idx).days
        a.save!
      end

      expect(user.new_announcements).to eq [anc3, anc2, anc1]
    end

    it "returns associated announcements within date range for type 'user'" do
      user2 = Factory(:user, time_zone: "Eastern Time (US & Canada)")
      anc1 = Factory(:announcement, category: 'all', start_at: now - 1.day, end_at: now + 1.day)
      anc2 = Factory(:announcement, category: 'users', start_at: now - 1.day, end_at: now + 1.day)
      anc2.selected_users << user

      [anc1, anc2].each_with_index do |a, idx|
        # test sorting
        a.created_at = now - (10 - idx).days
        a.save!
      end

      expect(user.new_announcements).to eq [anc2, anc1]
      expect(user2.new_announcements).to eq [anc1]
    end

    it "omits confirmed announcements" do
      anc = Factory(:announcement, category: 'all', start_at: now - 1.day, end_at: now + 1.day)
      Factory(:user_announcement_marker, announcement: anc, user: user, confirmed_at: now)

      expect(user.new_announcements).to be_empty
    end

    it "omits announcements before UTC start date" do
      Factory(:announcement, category: 'all', start_at: now + 1.hour, end_at: now + 1.day)

      expect(user.new_announcements).to be_empty
    end

    it "omits announcements after UTC end date" do
      Factory(:announcement, category: 'all', start_at: now - 1.day, end_at: now - 1.hour)

      expect(user.new_announcements).to be_empty
    end
  end

  describe "locked?" do
    let(:user) { Factory.create(:user) }

    it 'returns false if user is not active' do
      user.update(disabled: true)
      expect(user.locked?).to eq(false)
    end

    it 'returns true if password_expired is true' do
      user.update(password_expired: true)
      expect(user.locked?).to eq(true)
    end

    it 'returns true if password_locked is true' do
      user.update(password_locked: true)
      expect(user.locked?).to eq(true)
    end

  end

  describe "valid_password?" do
    it 'defers to PasswordValidationRegistry' do
      u = described_class.new
      p = 'password'
      expect(OpenChain::Registries::PasswordValidationRegistry).to receive(:valid_password?).with(u, p).and_return true
      expect(described_class.valid_password?(u, p)).to eq true
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

      expect(user.recent_password_hashes.map(&:hashed_password)).to eql expected_passwords
      expect(user.recent_password_hashes.map(&:hashed_password)).not_to include(user.encrypt_password(user.password_salt, passwords[5]))
    end
  end

  describe "api_hash" do
    let (:user) do
      Factory(:user, first_name: 'Joe', last_name: 'User', username: 'uname', email: 'j@sample.com',
                     department: 'something', email_new_messages: true)
    end

    it "gets hash" do
      allow(user).to receive(:view_orders?).and_return true
      h = user.api_hash

      expect(h[:permissions][:view_orders]).to eq true
      expect(h[:permissions][:view_shipments]).to be_falsey
      # not testing every permission
      h.delete(:permissions)

      expected = {
        username: 'uname',
        full_name: user.full_name,
        first_name: user.first_name,
        last_name: user.last_name,
        email: 'j@sample.com',
        email_new_messages: true,
        id: user.id,
        company_id: user.company_id,
        department: user.department
      }
      expect(h).to eq expected
    end

    it "excludes permissions if requested not to" do
      h = user.api_hash include_permissions: false
      expect(h[:permissions]).to be_nil
      expect(h).to eq({
                        username: 'uname',
                        full_name: user.full_name,
                        first_name: user.first_name,
                        last_name: user.last_name,
                        email: 'j@sample.com',
                        email_new_messages: true,
                        id: user.id,
                        company_id: user.company_id,
                        department: user.department
                      })
    end
  end

  describe "groups" do
    let(:group_a) { Factory(:group, system_code: 'groupA') }
    let(:group_b) { Factory(:group, system_code: 'groupB') }
    let(:user_one) { Factory(:user) }

    before do
      group_a.users << user_one
      user_one.reload
    end

    it "finds in_group?" do
      expect(user_one.in_group?('groupA')).to be_truthy
      expect(user_one.in_group?(group_a)).to be_truthy
      expect(user_one.in_group?('groupB')).to be_falsey
      expect(user_one.in_group?(group_b)).to be_falsey
    end

    it "finds in_any_group?" do
      expect(user_one.in_any_group?(['groupA', 'groupB'])).to be_truthy
      expect(user_one.in_any_group?([group_a, group_b])).to be_truthy
      expect(user_one.in_any_group?(['groupB'])).to be_falsey
      expect(user_one.in_any_group?([group_b])).to be_falsey
    end
  end

  describe "available_importers" do
    let!(:company_one) { Factory(:company, importer: true) }
    let!(:company_two) { Factory(:company, importer: true) }
    let!(:company_three) { Factory(:company, importer: true) }
    let!(:company_four) { Factory(:company) }

    it "shows all importers if master company" do
      u = Factory(:master_user)
      expect(u.available_importers.to_a).to eq [company_one, company_two, company_three]
    end

    it "shows all linked importers" do
      u = Factory(:user, company: company_four)
      company_four.linked_companies << company_one
      expect(u.available_importers.to_a).to eq [company_one]
    end

    it "shows me if i'm an importer" do
      u = Factory(:user, company: company_two)
      company_two.linked_companies << company_one
      expect(u.available_importers.to_a).to eq [company_one, company_two]
    end
  end

  describe "api_admin" do
    it "creates api_admin if it doesn't exist" do
      u = described_class.api_admin
      expect(u.username).to eq 'ApiAdmin'
      expect(u.first_name).to eq 'API'
      expect(u.last_name).to eq 'Admin'
      expect(u.email).to eq 'bug+api_admin@vandegriftinc.com'
      expect(u.system_user).to be true
      expect(u.company).to be_master
      expect(u).to be_admin
      expect(u.api_auth_token).not_to be_blank
      expect(u.time_zone).to eq "Eastern Time (US & Canada)"
      expect(u.disallow_password).to be_truthy
    end

    it "returns api_admin if it exits" do
      u = Factory(:master_user, username: 'ApiAdmin')
      expect(described_class.api_admin).to eq u
    end
  end

  describe "integration" do
    it "creates integration if it doesn't exist" do
      u = described_class.integration
      expect(u.username).to eq 'integration'
      expect(u.first_name).to eq 'Integration'
      expect(u.last_name).to eq 'User'
      expect(u.email).to eq 'bug+integration@vandegriftinc.com'
      expect(u.system_user).to be true
      expect(u.company).to be_master
      expect(u).to be_admin
      expect(u.api_auth_token).not_to be_blank
      expect(u.time_zone).to eq "Eastern Time (US & Canada)"
      expect(u.disallow_password).to be_truthy
    end

    it "returns integration if it exits" do
      u = Factory(:master_user, username: 'integration')
      expect(described_class.integration).to eq u
    end
  end

  describe "magic_columns" do
    let(:user) { Factory(:user, updated_at: 1.year.ago) }

    it "does not update updated_at if only confirmation token changed" do
      user.confirmation_token = '12345'
      user.save!
      expect(described_class.find(user.id).updated_at.to_i).to eq(user.updated_at.to_i)
      expect(described_class.record_timestamps).to be_truthy
    end

    it "does not update updated_at if only remember token changed" do
      user.remember_token = '12345'
      user.save!
      expect(described_class.find(user.id).updated_at.to_i).to eq(user.updated_at.to_i)
      expect(described_class.record_timestamps).to be_truthy
    end

    it "does not update updated_at if only last request at changed" do
      user.last_request_at = Time.zone.now
      user.save!
      expect(described_class.find(user.id).updated_at.to_i).to eq(user.updated_at.to_i)
      expect(described_class.record_timestamps).to be_truthy
    end

    it "does not update updated_at if all no-update fields changed" do
      user.confirmation_token = '12345'
      user.remember_token = '12345'
      user.last_request_at = Time.zone.now
      user.save!
      expect(described_class.find(user.id).updated_at.to_i).to eq(user.updated_at.to_i)
      expect(described_class.record_timestamps).to be_truthy
    end

    it "updates updated_at if a standard column changes" do
      user.update(email: 'a@sample.com')
      expect(described_class.record_timestamps).to be_truthy
      expect(described_class.find(user.id).updated_at).to be > 10.seconds.ago
    end

    it "updates updated_at if both standard and no-update columns change" do
      user.update(perishable_token: '12345', email: 'a@sample.com')
      expect(described_class.record_timestamps).to be_truthy
      expect(described_class.find(user.id).updated_at).to be > 10.seconds.ago
    end
  end

  context "permissions" do
    context "vendors" do
      before do
        allow_any_instance_of(MasterSetup).to receive(:vendor_management_enabled?).and_return true
      end

      it "allows when MasterSetup.vendor_management_enabled? and I have vendor_X permission" do
        expect(described_class.new(vendor_view: true).view_vendors?).to be_truthy
        expect(described_class.new(vendor_edit: true).edit_vendors?).to be_truthy
        expect(described_class.new(vendor_attach: true).attach_vendors?).to be_truthy
        expect(described_class.new(vendor_comment: true).comment_vendors?).to be_truthy
      end

      it "does not allow when !MasterSetup.vendor_management_enabled?" do
        allow_any_instance_of(MasterSetup).to receive(:vendor_management_enabled?).and_return false
        expect(described_class.new(vendor_view: true).view_vendors?).to be_falsey
        expect(described_class.new(vendor_edit: true).edit_vendors?).to be_falsey
        expect(described_class.new(vendor_attach: true).attach_vendors?).to be_falsey
        expect(described_class.new(vendor_comment: true).comment_vendors?).to be_falsey
      end

      it "does not allow when I dont have vendor_view permission" do
        expect(described_class.new.view_vendors?).to be_falsey
        expect(described_class.new.edit_vendors?).to be_falsey
        expect(described_class.new.attach_vendors?).to be_falsey
        expect(described_class.new.comment_vendors?).to be_falsey
      end
    end

    context "product_vendor_assignments" do
      it "allows if corresponding vendor value is true" do
        u = described_class.new
        allow(u).to receive(:view_vendors?).and_return true
        allow(u).to receive(:edit_vendors?).and_return true
        allow(u).to receive(:create_vendors?).and_return true
        expect(u.view_product_vendor_assignments?).to be_truthy
        expect(u.edit_product_vendor_assignments?).to be_truthy
        expect(u.create_product_vendor_assignments?).to be_truthy
      end

      it "does not allow if corresponding vendor value is false" do
        u = described_class.new
        allow(u).to receive(:view_vendors?).and_return false
        allow(u).to receive(:edit_vendors?).and_return false
        allow(u).to receive(:create_vendors?).and_return false
        expect(u.view_product_vendor_assignments?).to be_falsey
        expect(u.edit_product_vendor_assignments?).to be_falsey
        expect(u.create_product_vendor_assignments?).to be_falsey
      end
    end

    context "official tariffs" do
      it "allows master company user" do
        expect(Factory(:master_user)).to be_view_official_tariffs
      end

      it "does not allow non master company user" do
        expect(Factory(:user)).not_to be_view_official_tariffs
      end

      it "allows if user can view products" do
        expect(Factory(:user, product_view: true).view_official_tariffs?).to be_truthy
      end
    end

    context "business_validation_results" do
      it "allows user if company has business rules viewing allowed" do
        u = described_class.new
        c = Company.new
        u.company = c
        c.show_business_rules = true
        expect(u.view_business_validation_results?).to be_truthy
        expect(u.edit_business_validation_results?).to be_truthy
      end

      it "doesn't allow if company cannot view business rules" do
        u = described_class.new
        c = Company.new
        u.company = c
        c.show_business_rules = false
        expect(u.view_business_validation_results?).to be_falsey
        expect(u.edit_business_validation_results?).to be_falsey
      end

      context "private rules" do
        it "allows master users" do
          u = Factory(:master_user)
          u.company.update(show_business_rules: true)
          expect(u.view_all_business_validation_results?).to be_truthy
          expect(u.edit_all_business_validation_results?).to be_truthy
        end

        it "doesn't allow importer users even if company has business-rules viewing allowed" do
          u = Factory(:importer_user)
          u.company.update(show_business_rules: true)
          expect(u.view_all_business_validation_results?).to be_falsey
          expect(u.edit_all_business_validation_results?).to be_falsey
        end
      end
    end

    context "business_validation_rule_results" do
      it "allows master users" do
        u = Factory(:master_user)
        u.company.update(show_business_rules: true)
        expect(u.view_business_validation_rule_results?).to be_truthy
        expect(u.edit_business_validation_rule_results?).to be_truthy
      end

      it "does not allow non master users" do
        u = Factory(:importer_user)
        expect(u.view_business_validation_rule_results?).to be_falsey
        expect(u.edit_business_validation_rule_results?).to be_falsey
      end

      it "allows importer user if company has business rules viewing allowed" do
        u = Factory(:importer_user)
        u.company.update! show_business_rules: true

        expect(u.view_business_validation_rule_results?).to be_truthy
        expect(u.edit_business_validation_rule_results?).to be_truthy
      end

      context "private rules" do
        it "allows master users" do
          u = Factory(:master_user)
          u.company.update(show_business_rules: true)
          expect(u.view_all_business_validation_rule_results?).to be_truthy
          expect(u.edit_all_business_validation_rule_results?).to be_truthy
        end

        it "doesn't allow importer users even if company has business-rules viewing allowed" do
          u = Factory(:importer_user)
          u.company.update! show_business_rules: true

          expect(u.view_all_business_validation_rule_results?).to be_falsey
          expect(u.edit_all_business_validation_rule_results?).to be_falsey
        end
      end
    end

    context "trade_lanes" do
      let(:user) do
        u = described_class.new(trade_lane_view: true, trade_lane_edit: true, trade_lane_comment: true, trade_lane_attach: true)
        u.company = Company.new
        allow(u.company).to receive(:view_trade_lanes?).and_return true
        allow(u.company).to receive(:edit_trade_lanes?).and_return true
        u
      end

      it "allows for user whose company has permission" do
        u = user
        expect(u.view_trade_lanes?).to be_truthy
        expect(u.edit_trade_lanes?).to be_truthy
        expect(u.comment_trade_lanes?).to be_truthy
        expect(u.attach_trade_lanes?).to be_truthy
      end

      it "does not allow for user whose company does not have permission" do
        u = user
        allow(u.company).to receive(:view_trade_lanes?).and_return false
        allow(u.company).to receive(:edit_trade_lanes?).and_return false
        expect(u.view_trade_lanes?).to be_falsey
        expect(u.edit_trade_lanes?).to be_falsey
        expect(u.comment_trade_lanes?).to be_falsey
        expect(u.attach_trade_lanes?).to be_falsey
      end

      it "does not allow for user who does not have permission" do
        u = described_class.new
        expect(u.view_trade_lanes?).to be_falsey
        expect(u.edit_trade_lanes?).to be_falsey
        expect(u.comment_trade_lanes?).to be_falsey
        expect(u.attach_trade_lanes?).to be_falsey
      end
    end

    context "trade_preference_programs" do
      it "delegates view to trade lanes method" do
        u = described_class.new
        expect(u).to receive(:view_trade_lanes?).and_return 'ABC'
        expect(u.view_trade_preference_programs?).to eq 'ABC'
      end

      it "delegates edit to trade lanes method" do
        u = described_class.new
        expect(u).to receive(:edit_trade_lanes?).and_return 'ABC'
        expect(u.edit_trade_preference_programs?).to eq 'ABC'
      end

      it "delegates comment to trade lanes method" do
        u = described_class.new
        expect(u).to receive(:comment_trade_lanes?).and_return 'ABC'
        expect(u.comment_trade_preference_programs?).to eq 'ABC'
      end

      it "delegates attach to trade lanes method" do
        u = described_class.new
        expect(u).to receive(:attach_trade_lanes?).and_return 'ABC'
        expect(u.attach_trade_preference_programs?).to eq 'ABC'
      end
    end

    context "tpp_hts_overrides" do
      it "delegates to trade_preference_programs" do
        u = described_class.new
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
      it "allows for master user who can view entries" do
        u = Factory(:user, company: Factory(:company, master: true))
        allow(u).to receive(:view_entries?).and_return true
        expect(u).to be_view_attachment_archives
        expect(u).to be_edit_attachment_archives
      end

      it "does not allow for non-master user" do
        u = Factory(:user)
        allow(u).to receive(:view_entries?).and_return true
        expect(u).not_to be_view_attachment_archives
        expect(u).not_to be_edit_attachment_archives
      end

      it "does not allow for user who cannot view entries" do
        u = Factory(:user, company: Factory(:company, master: true))
        allow(u).to receive(:view_entries?).and_return false
        expect(u).not_to be_view_attachment_archives
        expect(u).not_to be_edit_attachment_archives
      end
    end

    context "security filing" do
      context "company has permission" do
        before do
          allow_any_instance_of(Company).to receive(:view_security_filings?).and_return(true)
          allow_any_instance_of(Company).to receive(:edit_security_filings?).and_return(true)
          allow_any_instance_of(Company).to receive(:attach_security_filings?).and_return(true)
          allow_any_instance_of(Company).to receive(:comment_security_filings?).and_return(true)
        end

        it "allows if permission set and company has permission" do
          u = Factory(:user, security_filing_view: true, security_filing_edit: true, security_filing_attach: true, security_filing_comment: true)
          expect(u.view_security_filings?).to be_truthy
          expect(u.edit_security_filings?).to be_truthy
          expect(u.attach_security_filings?).to be_truthy
          expect(u.comment_security_filings?).to be_truthy
        end

        it "does not allow if user permission not set and company has permission" do
          u = Factory(:user, security_filing_view: false, security_filing_edit: false, security_filing_attach: false, security_filing_comment: false)
          expect(u.view_security_filings?).to be_falsey
          expect(u.edit_security_filings?).to be_falsey
          expect(u.attach_security_filings?).to be_falsey
          expect(u.comment_security_filings?).to be_falsey
        end
      end

      it "does not allow if company does not have permission" do
        allow_any_instance_of(Company).to receive(:view_security_filings?).and_return(false)
        allow_any_instance_of(Company).to receive(:edit_security_filings?).and_return(false)
        allow_any_instance_of(Company).to receive(:attach_security_filings?).and_return(false)
        allow_any_instance_of(Company).to receive(:comment_security_filings?).and_return(false)
        u = Factory(:user, security_filing_view: true, security_filing_edit: true, security_filing_attach: true, security_filing_comment: true)
        expect(u.view_security_filings?).to be_falsey
        expect(u.edit_security_filings?).to be_falsey
        expect(u.attach_security_filings?).to be_falsey
        expect(u.comment_security_filings?).to be_falsey
      end
    end

    context "drawback" do
      let! (:master_setup) do
        ms = stub_master_setup
        allow(ms).to receive(:drawback_enabled?).and_return true
        ms
      end

      it "allows user to view if permission is set and drawback enabled" do
        expect(Factory(:user, drawback_view: true).view_drawback?).to be_truthy
      end

      it "allows user to edit if permission is set and drawback enabled" do
        expect(Factory(:user, drawback_edit: true).edit_drawback?).to be_truthy
      end

      it "does not allow view/edit if drawback not enabled" do
        allow(master_setup).to receive(:drawback_enabled?).and_return false
        u = Factory(:user, drawback_view: true, drawback_edit: true)
        expect(u.view_drawback?).to be_falsey
        expect(u.edit_drawback?).to be_falsey
      end

      it "nows allow if permissions not set" do
        u = Factory(:user)
        expect(u.view_drawback?).to be_falsey
        expect(u.edit_drawback?).to be_falsey
      end
    end

    context "broker invoice" do
      context "with company permission" do
        before do
          allow_any_instance_of(Company).to receive(:edit_broker_invoices?).and_return(true)
          allow_any_instance_of(Company).to receive(:view_broker_invoices?).and_return(true)
        end

        it "allows view if permission is set" do
          expect(Factory(:user, broker_invoice_view: true).view_broker_invoices?).to be_truthy
        end

        it "allows edit if permission is set" do
          expect(Factory(:user, broker_invoice_edit: true).edit_broker_invoices?).to be_truthy
        end

        it "does not allow view without permission" do
          expect(Factory(:user, broker_invoice_view: false).view_broker_invoices?).to be_falsey
        end

        it "does not allow edit without permission" do
          expect(Factory(:user, broker_invoice_edit: false).edit_broker_invoices?).to be_falsey
        end
      end

      context "without company permission" do
        before do
          allow_any_instance_of(Company).to receive(:edit_broker_invoices?).and_return(false)
          allow_any_instance_of(Company).to receive(:view_broker_invoices?).and_return(false)
        end

        it "does not allow view even if permission is set" do
          expect(Factory(:user, broker_invoice_view: true).view_broker_invoices?).to be_falsey
        end

        it "does not allow edit even if permission is set" do
          expect(Factory(:user, broker_invoice_edit: true).edit_broker_invoices?).to be_falsey
        end
      end
    end

    context "vfi invoice" do
      context "with company permission" do
        before do
          allow_any_instance_of(Company).to receive(:edit_vfi_invoices?).and_return true
          allow_any_instance_of(Company).to receive(:view_vfi_invoices?).and_return true
        end

        it "allows view if permission is set" do
          expect(Factory(:user, vfi_invoice_view: true).view_vfi_invoices?).to be_truthy
        end

        it "allows edit if permission is set" do
          expect(Factory(:user, vfi_invoice_edit: true).edit_vfi_invoices?).to be_truthy
        end

        it "does not allow view without permission" do
          expect(Factory(:user, vfi_invoice_view: false).view_vfi_invoices?).to be_falsey
        end

        it "does not allow edit without permission" do
          expect(Factory(:user, vfi_invoice_edit: false).edit_vfi_invoices?).to be_falsey
        end
      end

      context "without company permission" do
        before do
          allow_any_instance_of(Company).to receive(:edit_vfi_invoices?).and_return(false)
          allow_any_instance_of(Company).to receive(:view_vfi_invoices?).and_return(false)
        end

        it "does not allow view even if permission is set" do
          expect(Factory(:user, vfi_invoice_view: true).view_vfi_invoices?).to be_falsey
        end

        it "does not allow edit even if permission is set" do
          expect(Factory(:user, vfi_invoice_edit: true).edit_vfi_invoices?).to be_falsey
        end
      end
    end

    context "survey" do
      it "passes view_surveys?" do
        expect(described_class.new(survey_view: true).view_surveys?).to be_truthy
      end

      it "passes edit_surveys?" do
        expect(described_class.new(survey_edit: true).edit_surveys?).to be_truthy
      end

      it "fails view_surveys?" do
        expect(described_class.new(survey_view: false).view_surveys?).to be_falsey
      end

      it "fails edit_surveys?" do
        expect(described_class.new(survey_edit: false).edit_surveys?).to be_falsey
      end
    end

    context "entry" do
      let(:company) { Factory(:company, broker: true) }

      it "allows user to edit entry if permission is set and company is not broker" do
        expect(Factory(:user, entry_edit: true, company: company)).to be_edit_entries
      end

      it "does not allow user to edit entry if permission is not set" do
        expect(described_class.new(company: company)).not_to be_edit_entries
      end

      it "does not allow user to edit entry if company is not broker" do
        company.update(broker: false)
        expect(described_class.new(entry_edit: true, company_id: company.id)).not_to be_edit_entries
      end
    end

    # Commercial Invoices fall under entry edit/view permissions.

    context "variant" do
      let(:user) { Factory(:master_user, product_edit: true) }

      context "enabled" do
        let! (:master_setup) do
          ms = stub_master_setup
          allow(ms).to receive(:variant_enabled).and_return true
          ms
        end

        it "passes with user enabled" do
          user.update(variant_edit: true)
          expect(user.add_variants?).to be_truthy
          expect(user.edit_variants?).to be_truthy
        end

        it "fails with user not enabled" do
          expect(user.add_variants?).to be_falsey
          expect(user.edit_variants?).to be_falsey
        end
      end

      context "disabled" do
        let! (:master_setup) do
          ms = stub_master_setup
          allow(ms).to receive(:variant_enabled).and_return false
          ms
        end

        it "fails with user enabled" do
          user.update(variant_edit: true)
          expect(user.add_variants?).to be_falsey
          expect(user.edit_variants?).to be_falsey
        end

        it "fails with user not enabled" do
          expect(user.add_variants?).to be_falsey
          expect(user.edit_variants?).to be_falsey
        end
      end
    end

    context "powers of attorney" do
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
    let(:run_as) { described_class.new username: 'Run As', time_zone: "Hawaii" }
    let(:current_user) { described_class.new username: 'Current', time_zone: "UTC" }
    let(:user) { described_class.current }
    let(:time) { Time.zone }

    before do
      described_class.current = current_user
      Time.zone = current_user.time_zone
    end

    after do
      described_class.current = user
      Time.zone = time
    end

    it "set/unsets User settings" do

      val = described_class.run_with_user_settings(run_as) do
        expect(described_class.current).to eq(run_as)
        expect(Time.zone).to eq(ActiveSupport::TimeZone[run_as.time_zone])
        "abcdefg"
      end
      # Just make sure the method returns whatever the block returns
      expect(val).to eq("abcdefg")

      expect(described_class.current).to eq(current_user)
      expect(Time.zone).to eq(ActiveSupport::TimeZone[current_user.time_zone])
    end

    it "set/unsets User settings even if block raises an Exception" do
      # Exception is used here since it's the base for any other errors (even syntax or "severe" runtime issues)
      expect do
        described_class.run_with_user_settings(run_as) do
          raise Exception, "Error"
        end
      end.to raise_exception "Error"

      expect(described_class.current).to eq(current_user)
      expect(Time.zone).to eq(ActiveSupport::TimeZone[current_user.time_zone])
    end

    it "does not set Time.zone if user has no timezone" do
      # the main admin user doesn't appear to have timezone set. User.run_with.. handles this
      # scenario just in case.
      run_as.time_zone = ""

      described_class.run_with_user_settings(run_as) do
        expect(described_class.current).to eq(run_as)
        expect(Time.zone).to eq(ActiveSupport::TimeZone[current_user.time_zone])
      end

      expect(described_class.current).to eq(current_user)
      expect(Time.zone).to eq(ActiveSupport::TimeZone[current_user.time_zone])
    end
  end

  describe 'hidden messages' do
    it "adds hidden message" do
      u = described_class.new
      u.add_hidden_message 'h1'
      expect(u.hide_message?('h1')).to be_truthy
    end

    it "removes hidden message" do
      u = described_class.new
      u.add_hidden_message 'hx'
      u.remove_hidden_message 'hx'
      expect(u.hide_message?('hx')).to be_falsey
    end

    it "saves hidden messages" do
      u = Factory(:user)
      u.add_hidden_message 'hx'
      u.add_hidden_message 'abc'
      u.save!
      u = described_class.find(u.id)
      expect(u.hide_message?('hx')).to be_truthy
      expect(u.hide_message?('abc')).to be_truthy
    end

    it "is case insensitive" do
      u = described_class.new
      u.add_hidden_message 'hx'
      expect(u.hide_message?('HX')).to be_truthy
    end
  end

  context "send_invite_emails" do
    it "sends an invite email to a user" do
      e = instance_double("Email")
      expect(e).to receive(:deliver_now!)
      u = Factory(:user)

      expect_any_instance_of(described_class).to receive(:update_user_password).with(instance_of(String), instance_of(String), true, false).and_call_original

      expect(OpenMailer).to receive(:send_invite) do |user, password|
        expect(user.id).to eq(u.id)
        # Make sure the password has been updated by checking the encrypted
        # versions
        expect(user.encrypted_password).not_to eq(u.encrypted_password)
        expect(password.length).to eq 8
        expect(user.password_reset).to be_truthy
        e
      end

      described_class.send_invite_emails u.id
    end

    it "sends an invite email to an admin user" do
      e = instance_double("Email")
      expect(e).to receive(:deliver_now!)
      u = Factory(:user, admin: true)

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

      described_class.send_invite_emails u.id
    end

    it "sends an invite email to multiple users" do
      e = instance_double("email")
      expect(e).to receive(:deliver_now!).twice
      expect(OpenMailer).to receive(:send_invite).twice.and_return(e)

      u = Factory(:user)
      described_class.send_invite_emails [u.id, u.id]
    end
  end

  describe "authenticate" do
    let(:user) { Factory :user, password: "abc" }

    it "validates user exists with specified password" do
      expect(described_class.authenticate(user.username, "abc")).to eq user
    end

    it "returns nil if user is not found" do
      expect(described_class.authenticate("notauser", "abc")).to be_nil
    end

    it "returns nil if user password is incorrect" do
      expect(described_class.authenticate(user.username, "notmypassword")).to be_nil
    end

    it "calls FailedPasswordHandler if authentication fails" do
      klass = OpenChain::UserSupport::FailedPasswordHandler
      expect(klass).to receive(:call)
      described_class.authenticate user.username, "notmypassword"
    end

    it "returns nil if user can't use password login" do
      user.update(disallow_password: true)
      expect(described_class.authenticate(user.username, "abc")).to be_nil
    end
  end

  describe "access_allowed?" do
    it "validates user is not nill" do
      expect(described_class.access_allowed?(nil)).to be_falsey
    end

    it "validates user is not disabled?" do
      user = described_class.new
      user.disabled = true
      expect(described_class.access_allowed?(user)).to be_falsey
    end

    it "validates user company is not locked" do
      user = Factory(:user, company: Factory(:company, locked: true))
      expect(described_class.access_allowed?(user)).to be_falsey
    end

    it "validates user" do
      user = Factory(:user)
      expect(described_class.access_allowed?(user)).to be_truthy
    end
  end

  describe "update_user_password" do
    let(:user) { Factory(:user) }

    it 'creates user_password_histories record if password is valid' do
      user.update! time_zone: "Central Time (US & Canada)"
      Timecop.freeze(Time.zone.parse("2019-09-09 09:09:00 +0200")) do
        user.update_user_password 'newpassword', 'newpassword'
        expect(described_class.authenticate(user.username, 'newpassword')).to eq user
        user.reload
        expect(user.user_password_histories.first.hashed_password).to eq(user.encrypted_password)
        expect(user.user_password_histories.first.password_salt).to eq(user.password_salt)

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq [user.email]
        expect(mail.subject).to eq "#{MasterSetup.application_name} Password Change"
        # rubocop:disable Rails/OutputSafety
        # Change time should be in Central, not UTC+2 (Kaliningrad/European summer time).
        expect(mail.body).to include "<p>This email was sent to notify you that the password for your " + MasterSetup.application_name + " account ‘#{user.username}’ was changed on 2019-09-09 02:09.</p><p>If you did not initiate this password change, it may indicate your account has been compromised.  Please notify support@vandegriftinc.com of this situation.</p>".html_safe
        # rubocop:enable Rails/OutputSafety
      end
    end

    it 'creates user_password_histories record if password is valid, user has no default time zone' do
      user.update! time_zone: nil
      Timecop.freeze(Time.zone.parse("2019-09-09 09:09:00 +0200")) do
        user.update_user_password 'newpassword', 'newpassword'
        expect(described_class.authenticate(user.username, 'newpassword')).to eq user
        user.reload
        expect(user.user_password_histories.first.hashed_password).to eq(user.encrypted_password)
        expect(user.user_password_histories.first.password_salt).to eq(user.password_salt)

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq [user.email]
        expect(mail.subject).to eq "#{MasterSetup.application_name} Password Change"
        # rubocop:disable Rails/OutputSafety
        # Change time should be displayed in default UTC zone.
        expect(mail.body).to include "<p>This email was sent to notify you that the password for your " + MasterSetup.application_name + " account ‘#{user.username}’ was changed on 2019-09-09 07:09.</p><p>If you did not initiate this password change, it may indicate your account has been compromised.  Please notify support@vandegriftinc.com of this situation.</p>".html_safe
        # rubocop:enable Rails/OutputSafety
      end
    end

    it "sets password_changed_at" do
      Timecop.freeze(Time.zone.now) do
        user.update_user_password 'newpassword', 'newpassword'
        expect(described_class.authenticate(user.username, 'newpassword')).to eq user
        expect(user.password_changed_at).to eql(Time.zone.now)
      end
    end

    it "updates a user password with valid info" do
      # Update the password and then validate that our authenticate method confirms
      # the password now matches the hash that our new password generates
      user.update_user_password 'newpassword', 'newpassword'
      expect(described_class.authenticate(user.username, 'newpassword')).to eq user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.subject).to eq "#{MasterSetup.application_name} Password Change"
    end

    it "does not send password change email if told to not do so" do
      user.update_user_password 'newpassword', 'newpassword', true, false
      expect(described_class.authenticate(user.username, 'newpassword')).to eq user

      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it "validates password confirmation matches password" do
      user.update_user_password 'newpassword', 'notmatched'
      expect(user.errors.full_messages).to eq ["Password must match password confirmation."]
    end

    it "skips fails if password is blank" do
      expect(user.update_user_password(' ', 'notmatched')).to be_falsey
      expect(user.errors[:password]).to eq ["cannot be blank."]
      expect(described_class.authenticate(user.username, ' ')).to be_nil
    end
  end

  describe "on_successful_login" do
    it "sets last_login_at, current_login_at, failed_login_count and creates a history record" do
      user = Factory(:user, current_login_at: Date.new(2014, 1, 1), failed_login_count: 10)
      last_login = user.current_login_at
      updated_at = user.updated_at

      request = instance_double("request")
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
      expect(user.histories.where(history_type: 'login', company_id: user.company.id).first).not_to be_nil
    end

    it "doesn't update host with port if it's not blank" do
      user = Factory(:user, host_with_port: "www.test.com")
      user.on_successful_login instance_double("request")

      user.reload
      expect(user.host_with_port).to eq "www.test.com"
    end
  end

  describe "from_omniauth" do
    let!(:user) { Factory(:user, email: "condoleeza@rice.com") }

    context "google oauth" do
      it "returns an updated user when a user is found" do
        info = OpenStruct.new({"email" => "condoleeza@rice.com", "name" => "Condoleeza R"})
        creds = OpenStruct.new({"token" => "123456789", "expires_at" => (Time.zone.now + 5.days).to_i})
        auth = OpenStruct.new({"info" => info, "provider" => "oauth", "uid" => "someuid123", "credentials" => creds})

        expect(described_class.from_omniauth("google_oauth2", auth)).to eq ({user: user, errors: []})

        user.reload
        expect(user.provider).to eq("oauth")
        expect(user.uid).to eq("someuid123")
        expect(user.google_name).to eq("Condoleeza R")
        expect(user.oauth_token).to eq("123456789")
        expect(user.oauth_expires_at > Time.zone.now).to eq(true)
      end

      it "returns nil if the user is not found" do
        info = OpenStruct.new({"email" => "susan@rice.com", "name" => "Condoleeza R"})
        creds = OpenStruct.new({"token" => "123456789", "expires_at" => (Time.zone.now + 5.days).to_i})
        auth = OpenStruct.new({"info" => info, "provider" => "google_oauth2", "uid" => "someuid123", "credentials" => creds})

        expect(described_class.from_omniauth("google_oauth2", auth)).to eq ({user: nil, errors: ["Google email account susan@rice.com has not been set up in #{MasterSetup.application_name}. If you would like to request an account, please click the 'Need an account?' link below."]})
      end
    end

    context "azure oauth" do
      let(:auth) { {"info" => {"email" => "susan@maersk.com"}}.with_indifferent_access }

      it "returns user when found" do
        user.update! email: "susan@maersk.com"
        expect(described_class.from_omniauth("azure_oauth2", auth)).to eq ({user: user, errors: []})
      end

      it "returns nil if user not found" do
        expect(described_class.from_omniauth("azure_oauth2", auth)).to eq ({user: nil, errors: ["Maersk email account susan@maersk.com has not been set up in #{MasterSetup.application_name}. If you would like to request an account, please click the 'Need an account?' link below."]})
      end
    end

    context "pepsi SAML" do
      it "finds user by uid from SAML response" do
        expect(described_class.from_omniauth("pepsi-saml", OpenStruct.new({"uid" => user.username}))).to eq ({user: user, errors: []})
      end

      it "returns an error if user is not found" do
        expect(described_class.from_omniauth("pepsi-saml",
                                             OpenStruct.new({"uid" => "notausername"})))
          .to eq ({user: nil, errors: ["Pepsi User ID notausername has not been set up in #{MasterSetup.application_name}."]})
      end
    end
  end

  describe "username uniqueness" do
    it "prevents duplicate usernames without case sensitivity" do
      c = Factory(:company)
      u1 = described_class.new(email: "example@example.com", username: "username")
      u1.password = "password"
      u1.company = c
      u1.save!

      u2 = described_class.new(email: "example2@example.com", username: "username")
      u2.password = "password"
      u2.company = c
      expect { u2.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Username has already been taken")

      u3 = described_class.new(email: "example2@example.com", username: "USERNAME")
      u3.password = "password"
      u3.company = c
      expect { u3.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Username has already been taken")
    end
  end

  describe "email validation" do
    it "updates email field if all members of semicolon/comma-separated list match regex pattern" do
      u = Factory(:user, email: "default@vandegriftinc.com")
      list = "abc@exam-ple.net, nbc123@vandegriftinc.com; cbs_1@britishcompany.co.uk; 1@2.3.com, philip.glass@mail.ymu-global.com"
      u.update(email: list)
      u.reload
      expect(u.email).to eq list
      expect(u.errors.messages[:email]).to be_nil
    end

    it "does not update email field if any member of semicolon/comma-separated list fails to match regex pattern" do
      u = Factory(:user, email: "default@vandegriftinc.com")
      list = "abc@example.*et, nbc123grifter.com; cbs@somewhere.org"
      u.update(email: list)
      u.reload
      expect(u.email).to eq "default@vandegriftinc.com"
      expect(u.errors.full_messages).to eq ["Email invalid: abc@example.*et, nbc123grifter.com"]
    end

    it "has a different error for one invalid email" do
      u = Factory(:user, email: "default@vandegriftinc.com")
      addr = "abc@example.*et"
      u.update(email: addr)
      u.reload
      expect(u.email).to eq "default@vandegriftinc.com"
      expect(u.errors.full_messages).to eq ["Email invalid"]
    end

    it "prevents duplicate emails without case sensitivity" do
      c = Factory(:company)
      u1 = described_class.new(email: "example@example.com", username: "username")
      u1.password = "password"
      u1.company = c
      u1.save!

      u2 = described_class.new(email: "example@example.com", username: "somethingelse")
      u2.password = "password"
      u2.company = c
      expect { u2.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Email has already been taken")
    end
  end

  describe "portal_redirect_path" do
    it "returns nil if portal_mode.blank?" do
      expect(described_class.new.portal_redirect_path).to be_nil
    end

    it "returns nil if portal_mode not found in list" do
      expect(described_class.new(portal_mode: 'ABC').portal_redirect_path).to be_nil
    end

    it "returns portal redirect for vendor" do
      expect(described_class.new(portal_mode: 'vendor').portal_redirect_path).to eq '/vendor_portal'
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
    let (:user) do
      Factory(:user, username: "username", api_auth_token: "authtoken")
    end

    it "returns token if already set" do
      expect(user.user_auth_token).to eq "username:authtoken"
    end

    it "generates a new authtoken and saves user if token is not already set" do
      user.api_auth_token = nil
      user.save!
      expect(described_class).to receive(:generate_authtoken).with(user).and_return "newtoken"

      expect(user.user_auth_token).to eq "username:newtoken"

      user.reload
      expect(user.api_auth_token).to eq "newtoken"
    end
  end
end
