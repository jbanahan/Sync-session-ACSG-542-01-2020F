describe OneTimeAlertsController do
  let(:user) { FactoryBot(:user, first_name: "David", last_name: "St. Hubbins", username: "dsthubbins") }

  before { sign_in_as user }

  describe "index" do
    let!(:ota1) do
      FactoryBot(:one_time_alert, inactive: true, user: user, expire_date_last_updated_by: user, module_type: "Entry", name: "ota 1",
                               expire_date: Date.new(2018, 3, 15), search_criterions: [FactoryBot(:search_criterion, model_field_uid: "ent_entry_num"),
                                                                                       FactoryBot(:search_criterion, model_field_uid: "ent_ent_released_date")])
    end

    let!(:ota2) do
      FactoryBot(:one_time_alert, inactive: false, user: user, expire_date_last_updated_by: user, module_type: "Entry",
                               name: "ota 2", expire_date: Date.new(2018, 3, 20), search_criterions: [FactoryBot(:search_criterion, model_field_uid: "ent_cust_num"),
                                                                                                      FactoryBot(:search_criterion, model_field_uid: "ent_arrival_date")])
    end

    let(:ota3) do
    end

    let(:ota4) do
    end

    before do
      FactoryBot(:one_time_alert, inactive: false, user: FactoryBot(:user, first_name: "Nigel", last_name: "Tufnel", username: "ntufnel"),
                               name: "ota 3", module_type: "Entry", expire_date: Date.new(2018, 3, 15))

      FactoryBot(:one_time_alert, inactive: false, user: FactoryBot(:user, first_name: "Derek", last_name: "Smalls", username: "dsmalls"),
                               name: "ota 4", module_type: "Entry", expire_date: Date.new(2018, 3, 20),
                               search_criterions: [FactoryBot(:search_criterion, model_field_uid: "ent_entry_num")])
    end

    it "renders for user with permission" do
      expect(OneTimeAlert).to receive(:can_view?).with(user).and_return true

      Timecop.freeze(DateTime.new(2018, 3, 17)) { get :index, tab: "enabled" }
      expect(response).to be_success

      expect(assigns(:tab)).to eq "enabled"

      expect(assigns(:expired).length).to eq 1
      expired = assigns(:expired).first
      expect(expired.name).to eq ota1.name
      expect(expired.inactive).to eq true
      expect(expired.creator_name).to eq "David St. Hubbins (dsthubbins)"
      expect(expired.updater_name).to eq "David St. Hubbins (dsthubbins)"
      expect(expired.created_at).to be_within(1).of ota1.created_at
      expect(expired.module_type).to eq ota1.module_type
      expect(expired.expire_date).to eq ota1.expire_date
      expect(expired.reference_field_uids).to eq "ent_entry_num, ent_ent_released_date"

      expect(assigns(:enabled).length).to eq 1
      enabled = assigns(:enabled).first
      expect(enabled.inactive).to eq false
      expect(enabled.name).to eq ota2.name
      expect(enabled.creator_name).to eq "David St. Hubbins (dsthubbins)"
      expect(expired.updater_name).to eq "David St. Hubbins (dsthubbins)"
      expect(enabled.created_at).to be_within(1).of ota2.created_at
      expect(enabled.module_type).to eq ota2.module_type
      expect(enabled.expire_date).to eq ota2.expire_date
      expect(enabled.reference_field_uids).to eq "ent_cust_num, ent_arrival_date"
    end

    it "renders all alerts for admin user when requested" do
      user.admin = true; user.save!
      expect(OneTimeAlert).to receive(:can_view?).with(user).and_return true

      Timecop.freeze(DateTime.new(2018, 3, 17)) { get :index, display_all: true, tab: "expired" }
      expect(response).to be_success

      expect(assigns(:tab)).to eq "expired"
      expect(assigns(:expired).length).to eq 2
      expect(assigns(:expired).map(&:name)).to include("ota 1", "ota 3")

      expect(assigns(:enabled).length).to eq 2
      expect(assigns(:enabled).map(&:name)).to include("ota 2", "ota 4")
    end

    it "shows update notice (when applicable)" do
      expect(OneTimeAlert).to receive(:can_view?).with(user).and_return true

      get :index, message: "update"
      expect(flash[:notices]).to include "One Time Alert has been updated."
    end

    it "shows reference-field update notice (when applicable)" do
      expect(OneTimeAlert).to receive(:can_view?).with(user).and_return true

      get :index, message: "ref_update"
      expect(flash[:notices]).to include "Available reference fields have been updated."
    end

    it "shows delete notice (when applicable)" do
      expect(OneTimeAlert).to receive(:can_view?).with(user).and_return true

      get :index, message: "delete"
      expect(flash[:notices]).to include "One Time Alert has been deleted."
    end

    it "rejects other users" do
      get :index
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to view One Time Alerts."
    end
  end

  describe "new" do
    it "assigns new alert, core-module info to view for permitted users" do
      expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      get :new, display_all: true
      expect(assigns(:alert)).to be_instance_of(OneTimeAlert)
      expect(assigns(:display_all)).to eq true
      expect(assigns(:cm_list)).to eq [["BrokerInvoice", "Broker Invoice"],
                                       ["Entry", "Entry"], ["Order", "Order"],
                                       ["Product", "Product"], ["Shipment", "Shipment"]]
    end

    it "rejects other users" do
      get :new
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to create One Time Alerts."
    end
  end

  describe "edit" do
    let(:ota) { FactoryBot(:one_time_alert, user: user) }

    it "renders for alert's creator" do
      get :edit, id: ota.id, display_all: true
      expect(assigns(:display_all)).to eq true
      expect(response).to be_success
    end

    it "renders for admin" do
      sign_in_as FactoryBot(:admin_user)
      get :edit, id: ota.id
      expect(response).to be_success
    end

    it "rejects other users" do
      sign_in_as FactoryBot(:user)
      get :edit, id: ota.id
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to edit One Time Alerts."
    end
  end

  describe "create" do
    let(:dt) { DateTime.new 2018, 3, 15, 12 }

    it "creates alert for permitted user" do
      expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      Timecop.freeze(dt) do
        post :create, module_type: "Entry", user_id: user.id, display_all: true
      end
      expect(OneTimeAlert.count).to eq 1
      ota = OneTimeAlert.first
      expect(ota.module_type).to eq "Entry"
      expect(ota.user).to eq user
      expect(ota.inactive).to eq true
      expect(ota.expire_date_last_updated_by).to eq user
      expect(ota.enabled_date).to eq dt.to_date
      expect(ota.expire_date).to eq dt.to_date + 1.year
      expect(response).to redirect_to edit_one_time_alert_path(ota, display_all: true)
    end

    it "prevents access by other users" do
      post :create, module_type: "Entry", user_id: user.id, enabled_date: dt.to_date
      expect(OneTimeAlert.count).to eq 0
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to create One Time Alerts."
    end
  end

  describe "copy" do
    let!(:user2) { FactoryBot(:user) }
    let!(:alert) do
      FactoryBot(:one_time_alert, module_type: "Product", inactive: false, blind_copy_me: true, email_addresses: "sthubbins@hellhole.co.uk", email_body: "body",
                               email_subject: "subject", name: "OTA Name", enabled_date: Date.new(2018, 3, 15), expire_date: Date.new(2019, 3, 15),
                               expire_date_last_updated_by: user2, mailing_list: FactoryBot(:mailing_list), user: user2)
    end

    it "duplicates alert if populated" do
      sc = FactoryBot(:search_criterion, model_field_uid: 'prod_uid')
      alert.search_criterions << sc

      expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      expect { put :copy, id: alert.id, display_all: true }.to change(OneTimeAlert, :count).from(1).to(2)

      cpy = OneTimeAlert.last
      expect(cpy.id).not_to eq alert.id
      expect(cpy.inactive).to eq true
      expect(cpy.blind_copy_me).to eq alert.blind_copy_me
      expect(cpy.email_addresses).to eq alert.email_addresses
      expect(cpy.email_body).to eq alert.email_body
      expect(cpy.email_subject).to eq alert.email_subject
      expect(cpy.enabled_date).to eq alert.enabled_date
      expect(cpy.expire_date).to eq alert.expire_date
      expect(cpy.expire_date_last_updated_by).to eq user
      expect(cpy.mailing_list).to eq alert.mailing_list
      expect(cpy.module_type).to eq alert.module_type
      expect(cpy.name).to eq "OTA Name"
      expect(cpy.user).to eq user
      sc_cpy = cpy.search_criterions.first
      expect(sc_cpy.model_field_uid).to eq 'prod_uid'

      expect(response).to redirect_to edit_one_time_alert_path(cpy, display_all: true)
      expect(flash[:notices]).to include "One Time Alert has been copied."
    end

    it "does nothing if alert missing name" do
      expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      alert.update! name: nil
      expect { put :copy, id: alert.id }.not_to change(OneTimeAlert, :count)
      expect(response).to redirect_to request.referer
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "This alert can't be copied."
    end

    it "increments name" do
      sign_in_as user2
      expect(OneTimeAlert).to receive(:can_edit?).with(user2).and_return true

      alert.update name: "OTA NAME (COPY)"
      put :copy, id: alert.id

      cpy = OneTimeAlert.last
      expect(cpy.name).to eq "OTA NAME (COPY 2)"
    end

    it "blocks unauthorized users" do
      expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return false
      expect { put :copy, id: alert.id }.not_to change(OneTimeAlert, :count)
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "You do not have permission to copy One Time Alerts."
    end
  end

  context "mass update" do
    let!(:ota_1) { FactoryBot(:one_time_alert, user: user, name: "ota 1", expire_date: Date.new(2018, 3, 15)) }
    let!(:ota_2) { FactoryBot(:one_time_alert, user: user, name: "ota 2", expire_date: Date.new(2018, 3, 15)) }
    let!(:ota_3) { FactoryBot(:one_time_alert, user: user, name: "ota 3", expire_date: Date.new(2018, 3, 15)) }
    let!(:ota_4) { FactoryBot(:one_time_alert, user: FactoryBot(:user), name: "ota 4", expire_date: Date.new(2018, 3, 15)) }

    describe "mass_delete" do
      it "deletes multiple alerts for permitted user" do
        expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

        expect {delete :mass_delete, ids: [ota_1.id, ota_3.id, ota_4.id], display_all: true}.to change(OneTimeAlert, :count).from(4).to 2
        expect(OneTimeAlert.all.map(&:name)).to include("ota 2", "ota 4")
        expect(response).to redirect_to one_time_alerts_path(display_all: true)
        expect(flash[:notices]).to include "Selected One Time Alerts have been deleted."
      end

      it "deletes all multiple alerts for admin" do
        user.admin = true; user.save!

        expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

        expect {delete :mass_delete, ids: [ota_1.id, ota_3.id, ota_4.id]}.to change(OneTimeAlert, :count).from(4).to 1
        expect(OneTimeAlert.all.map(&:name)).to include("ota 2")
        expect(response).to redirect_to one_time_alerts_path
        expect(flash[:notices]).to include "Selected One Time Alerts have been deleted."
      end

      it "prevents access by other users" do
        expect {delete :mass_delete, ids: [ota_1.id, ota_3.id]}.not_to change(OneTimeAlert, :count)
        expect(flash[:errors]).to include "You do not have permission to edit One Time Alerts."
      end
    end

    describe "mass_expire" do
      it "updates expire date for multiple alerts for permitted user" do
        expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

        Timecop.freeze(DateTime.new(2018, 4, 1)) { put :mass_expire, ids: [ota_1.id, ota_3.id, ota_4.id], display_all: true }
        [ota_1, ota_2, ota_3, ota_4].each(&:reload)
        expect(ota_1.expire_date).to eq Date.new(2018, 4, 1)
        expect(ota_2.expire_date).to eq Date.new(2018, 3, 15)
        expect(ota_3.expire_date).to eq Date.new(2018, 4, 1)
        expect(ota_4.expire_date).to eq Date.new(2018, 3, 15)
        expect(response).to redirect_to one_time_alerts_path(display_all: true)
        expect(flash[:notices]).to include "Selected One Time Alerts will expire at the end of the day."
      end

      it "updates all alerts for admin" do
        user.admin = true; user.save!
        expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

        Timecop.freeze(DateTime.new(2018, 4, 1)) { put :mass_expire, ids: [ota_1.id, ota_3.id, ota_4.id] }
        [ota_1, ota_2, ota_3, ota_4].each(&:reload)
        expect(ota_1.expire_date).to eq Date.new(2018, 4, 1)
        expect(ota_2.expire_date).to eq Date.new(2018, 3, 15)
        expect(ota_3.expire_date).to eq Date.new(2018, 4, 1)
        expect(ota_4.expire_date).to eq Date.new(2018, 4, 1)
        expect(flash[:notices]).to include "Selected One Time Alerts will expire at the end of the day."
      end

      it "prevents access by other users" do
        Timecop.freeze(DateTime.new(2018, 4, 1)) { put :mass_expire, ids: [ota_1.id, ota_3.id] }

        [ota_1, ota_2, ota_3, ota_4].each(&:reload)
        expect(ota_1.expire_date).to eq Date.new(2018, 3, 15)
        expect(ota_2.expire_date).to eq Date.new(2018, 3, 15)
        expect(ota_3.expire_date).to eq Date.new(2018, 3, 15)
        expect(ota_4.expire_date).to eq Date.new(2018, 3, 15)

        expect(flash[:errors]).to include "You do not have permission to edit One Time Alerts."
      end
    end

    describe "mass_enable" do
      it "increment expire date for multiple alerts by 1 year for permitted user" do
        expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

        Timecop.freeze(DateTime.new(2018, 4, 1)) { put :mass_enable, ids: [ota_1.id, ota_3.id, ota_4.id], display_all: true }
        [ota_1, ota_2, ota_3, ota_4].each(&:reload)
        expect(ota_1.expire_date).to eq Date.new(2019, 4, 1)
        expect(ota_2.expire_date).to eq Date.new(2018, 3, 15)
        expect(ota_3.expire_date).to eq Date.new(2019, 4, 1)
        expect(ota_4.expire_date).to eq Date.new(2018, 3, 15)
        expect(response).to redirect_to one_time_alerts_path(display_all: true)
        expect(flash[:notices]).to include "Expire dates for selected One Time Alerts have been extended."
      end

      it "updates all alerts for admin" do
        user.admin = true; user.save!
        expect(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

        Timecop.freeze(DateTime.new(2018, 4, 1)) { put :mass_enable, ids: [ota_1.id, ota_3.id, ota_4.id] }
        [ota_1, ota_2, ota_3, ota_4].each(&:reload)
        expect(ota_1.expire_date).to eq Date.new(2019, 4, 1)
        expect(ota_2.expire_date).to eq Date.new(2018, 3, 15)
        expect(ota_3.expire_date).to eq Date.new(2019, 4, 1)
        expect(ota_4.expire_date).to eq Date.new(2019, 4, 1)

        expect(flash[:notices]).to include "Expire dates for selected One Time Alerts have been extended."
      end

      it "prevents access by other users" do
        sign_in_as FactoryBot(:user)
        Timecop.freeze(DateTime.new(2018, 4, 1)) { put :mass_enable, ids: [ota_1.id, ota_3.id] }

        [ota_1, ota_2, ota_3].each(&:reload)
        expect(ota_1.expire_date).to eq Date.new(2018, 3, 15)
        expect(ota_2.expire_date).to eq Date.new(2018, 3, 15)
        expect(ota_3.expire_date).to eq Date.new(2018, 3, 15)

        expect(flash[:errors]).to include "You do not have permission to edit One Time Alerts."
      end
    end
  end

  describe "reference_fields_index" do
    it "assigns fields to the view for admin user" do
      user.admin = true; user.save!

      DataCrossReference.create!(cross_reference_type: "ota_reference_fields", key: "Order~ord_ord_num")
      DataCrossReference.create!(cross_reference_type: "ota_reference_fields", key: "Shipment~shp_ref")

      bi_invoice_number = instance_double "Invoice Number"
      ent_entry_num = instance_double "Entry Number"
      ord_ord_num = instance_double "Order Number"
      prod_uid = instance_double "Unique Identifier"
      shp_ref = instance_double "Reference Number"

      expect(bi_invoice_number).to receive(:label).and_return "Invoice Number"
      expect(ent_entry_num).to receive(:label).and_return "Entry Number"
      expect(ord_ord_num).to receive(:label).and_return "Order Number"
      expect(prod_uid).to receive(:label).and_return "Unique Identifier"
      expect(shp_ref).to receive(:label).and_return "Reference Number"

      allow_any_instance_of(ModuleChain).to receive(:model_fields) do |mc, u|
        expect(u).to eq user
        mc_owner = mc.to_a.first.class_name
        case mc_owner
        when "BrokerInvoice"
          { bi_invoice_number: bi_invoice_number}
        when "Entry"
          { ent_entry_num: ent_entry_num }
        when "Order"
          { ord_ord_num: ord_ord_num }
        when "Product"
          { prod_uid: prod_uid }
        when "Shipment"
          { shp_ref: shp_ref }
        else
          raise "Unexpected name found in OneTimeAlert::MODULE_CLASS_NAMES."
        end
      end

      get :reference_fields_index, display_all: true

      expect(response).to be_success
      expect(assigns(:display_all)).to eq true
      expect(JSON.parse(assigns(:available))).to eq("BrokerInvoice" => [{ "mfid" => "bi_invoice_number", "label" => "Invoice Number"}],
                                                    "Entry" => [{"mfid" => "ent_entry_num", "label" => "Entry Number"}],
                                                    "Product" => [{"mfid" => "prod_uid", "label" => "Unique Identifier"}],
                                                    "Order" => [], "Shipment" => [])

      expect(JSON.parse(assigns(:included))).to eq("Order" => [{"mfid" => "ord_ord_num", "label" => "Order Number"}],
                                                   "Shipment" => [{"mfid" => "shp_ref", "label" => "Reference Number"}],
                                                   "BrokerInvoice" => [], "Entry" => [], "Product" => [])
    end

    it "rejects non-admin users" do
      get :reference_fields_index
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "Only administrators can do this."
    end
  end

  describe "log_index" do
    let!(:alert) { FactoryBot(:one_time_alert, user: user) }

    it "renders for user with permission" do
      expect(OneTimeAlert).to receive(:can_view?).with(user).and_return true

      get :log_index, id: alert.id, display_all: true
      expect(response).to be_success
      expect(assigns(:alert)).to eq alert
      expect(assigns(:display_all)).to eq true
    end

    it "rejects other users" do
      expect(OneTimeAlert).to receive(:can_view?).with(user).and_return false

      get :log_index, id: alert.id
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view One Time Alerts."
    end
  end
end
