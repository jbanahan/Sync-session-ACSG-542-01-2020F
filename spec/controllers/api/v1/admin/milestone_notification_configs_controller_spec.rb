require 'spec_helper'

describe Api::V1::Admin::MilestoneNotificationConfigsController do

  before :each do 
    @user = Factory(:admin_user)
    allow_api_access @user
  end

  describe "show" do
    def timezones
      subject.send(:timezones)
    end

    def event_list
      subject.send(:event_list)
    end

    def model_fields
      subject.send(:model_field_list)
    end

    it "returns a config" do
      config = MilestoneNotificationConfig.create! customer_number: "CUST", output_style: "standard", enabled: true, setup: [{model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true}].to_json
      config.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "eq", value: "val", include_empty: false

      get :show, id: config.id

      expect(response).to be_success
      c = JSON.parse(response.body)

      # Forget about the lists in here..just make sure they're there and the correct attributes are used, but the contents
      # of them are quite large so don't worry too muhc about them
      expect(c['config']['milestone_notification_config']).to eq({
        id: config.id,
        customer_number: "CUST",
        enabled: true,
        output_style: "standard",
        setup_json: [
          {model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true, label: "Broker Reference", event_code: "brok_ref"}
        ],
        search_criterions: [
          {mfid: "ent_brok_ref", label: "Broker Reference", operator: "eq", value: "val", include_empty: false, datatype: "string"}
        ]
        }.with_indifferent_access
      )

      mf_list = c['model_field_list']
      expect(mf_list.size).to eq CoreModule::ENTRY.model_fields(@user).size
      expect(mf_list.first['field_name']).to be_a String
      expect(mf_list.first['mfid']).to be_a String
      expect(mf_list.first['label']).to be_a String
      expect(mf_list.first['datatype']).to be_a String

      event_list = c['event_list']
      expect(event_list.size).to eq CoreModule::ENTRY.model_fields(@user) {|mf| ([:date, :datetime].include? mf.data_type.to_sym)}.size
      expect(event_list.first['field_name']).to be_a String
      expect(event_list.first['mfid']).to be_a String
      expect(event_list.first['label']).to be_a String
      expect(event_list.first['datatype']).to be_a String

      expect(c["output_styles"]).to eq MilestoneNotificationConfig::OUTPUT_STYLES

      timezones = c["timezones"]
      # Plus one is because we're inserting a blank value 
      expect(timezones.size).to eq ActiveSupport::TimeZone.all.size + 1
      expect(timezones.first['name']).to be_a String
      expect(timezones.first['label']).to be_a String
    end

    it "rejects non-admin users" do
      allow_api_access Factory(:user)

      get :show, id: 1
      expect(response.status).to eq 403
      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})
    end
  end

  describe "create" do
    before :each do 
      @c =  {milestone_notification_config: {
                customer_number: "CUST",
                output_style: "standard",
                enabled: true,
                setup_json: [
                  {model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true}
                ],
                search_criterions: [
                  {mfid: "ent_brok_ref", operator: "eq", value: "val", include_empty: false}
                ]
              }
            }
    end
    it "creates a milestone config" do
      post :create, @c

      config = MilestoneNotificationConfig.first
      expect(config.customer_number).to eq "CUST"
      expect(config.enabled).to be_true
      expect(config.output_style).to eq "standard"
      expect(config.setup_json).to eq (
        [{"model_field_uid" => "ent_brok_ref", "timezone" => "timezone", "no_time" => true}]
      )
      expect(config.search_criterions.first.model_field_uid).to eq "ent_brok_ref"
      expect(config.search_criterions.first.operator).to eq "eq"
      expect(config.search_criterions.first.value).to eq "val"
      expect(config.search_criterions.first.include_empty?).to be_false
    end

    it "rejects non-admin users" do
      allow_api_access Factory(:user)

      post :create, @c
      expect(response.status).to eq 403
      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})
    end
  end

  describe "updated" do
    before :each do
      @config = MilestoneNotificationConfig.create! customer_number: "BLAH", output_style: "standard"

      @c =  {milestone_notification_config: {
                 customer_number: "CUST",
                 output_style: "mbol_container",
                 enabled: false,
                 setup_json: [
                   {model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true}
                 ],
                 search_criterions: [
                   {mfid: "ent_brok_ref", operator: "eq", value: "val", include_empty: false}
                 ]
               },
               id: @config.id,
            }
    end

    it "updates milestone config" do
      put :update, @c

      @config.reload
      expect(@config.customer_number).to eq "CUST"
      expect(@config.enabled).to be_false
      expect(@config.output_style).to eq "mbol_container"
      expect(@config.setup_json).to eq (
        [{"model_field_uid" => "ent_brok_ref", "timezone" => "timezone", "no_time" => true}]
      )
      expect(@config.search_criterions.first.model_field_uid).to eq "ent_brok_ref"
      expect(@config.search_criterions.first.operator).to eq "eq"
      expect(@config.search_criterions.first.value).to eq "val"
      expect(@config.search_criterions.first.include_empty?).to be_false
    end

    it "rejects non-admin users" do
      allow_api_access Factory(:user)

      put :update, @c
      expect(response.status).to eq 403
      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})
    end
  end

  describe "destroy" do
    it "removes a config" do
      @config = MilestoneNotificationConfig.create! customer_number: "BLAH", output_style: "standard"

      delete :destroy, id: @config.id
      expect(response).to be_success
      expect(response.body).to eq "{}"
      expect(MilestoneNotificationConfig.first).to be_nil
    end
  end

  describe "index" do
    it "lists all configs" do
      config = MilestoneNotificationConfig.create! customer_number: "CUST", output_style: "standard", setup: [{model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true}].to_json
      config.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "eq", value: "val", include_empty: false
      config2 = MilestoneNotificationConfig.create! customer_number: "ABC",output_style: "standard"

      get :index

      expect(response).to be_success
      configs = JSON.parse response.body

      expect(configs['configs'].length).to eq 2
      c = configs['configs'].first
      expect(c).to eq({
          milestone_notification_config: {
            id: config2.id,
            customer_number: "ABC",
            enabled: nil,
            output_style: 'standard',
            setup_json: [],
            search_criterions: []
          }
        }.with_indifferent_access
      )
      c = configs['configs'].second
      expect(c).to eq({
          milestone_notification_config: {
            id: config.id,
            customer_number: "CUST",
            enabled: nil,
            output_style: 'standard',
            setup_json: [
              {model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true, label: "Broker Reference", event_code: "brok_ref"}
            ],
            search_criterions: [
              {mfid: "ent_brok_ref", operator: "eq", value: "val", include_empty: false, label: "Broker Reference", datatype: "string"}
            ]
          }
        }.with_indifferent_access
      )
    end
  end

  describe "new" do

    def timezones
      subject.send(:timezones)
    end

    def event_list
      subject.send(:event_list)
    end

    def model_fields
      subject.send(:model_field_list)
    end

    it "sends blank milestone config setup info" do
      get :new

      expect(response).to be_success
      c = JSON.parse response.body

      expect(c['config']['milestone_notification_config']).to eq({
        id: nil,
        customer_number: nil,
        enabled: nil,
        output_style: nil,
        setup_json: [],
        search_criterions: []
        }.with_indifferent_access
      )

      mf_list = c['model_field_list']
      expect(mf_list.size).to eq CoreModule::ENTRY.model_fields(@user).size
      expect(mf_list.first['field_name']).to be_a String
      expect(mf_list.first['mfid']).to be_a String
      expect(mf_list.first['label']).to be_a String
      expect(mf_list.first['datatype']).to be_a String

      event_list = c['event_list']
      expect(event_list.size).to eq CoreModule::ENTRY.model_fields(@user) {|mf| ([:date, :datetime].include? mf.data_type.to_sym)}.size
      expect(event_list.first['field_name']).to be_a String
      expect(event_list.first['mfid']).to be_a String
      expect(event_list.first['label']).to be_a String
      expect(event_list.first['datatype']).to be_a String

      expect(c["output_styles"]).to eq MilestoneNotificationConfig::OUTPUT_STYLES

      timezones = c["timezones"]
      # Plus one is because we're inserting a blank value 
      expect(timezones.size).to eq ActiveSupport::TimeZone.all.size + 1
      expect(timezones.first['name']).to be_a String
      expect(timezones.first['label']).to be_a String
    end
  end
end