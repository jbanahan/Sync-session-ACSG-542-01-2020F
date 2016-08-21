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
      config = MilestoneNotificationConfig.create! customer_number: "CUST", output_style: "standard", enabled: true, module_type: "Entry", setup: {milestone_fields: [{model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true}], fingerprint_fields: ["ent_brok_ref", "ent_release_date"]}.to_json
      
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
        testing: nil,
        module_type: "Entry",
        setup_json: {
          milestone_fields: [{model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true, label: "Broker Reference", event_code: "brok_ref"}],
          fingerprint_fields: ["ent_brok_ref", "ent_release_date"]
        },
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

      module_list = c['module_types']
      expect(module_list).to eq({"Entry"=>"Entry", "SecurityFiling"=>"ISF"})
    end

     it "returns a config built from an old setup json format" do
      config = MilestoneNotificationConfig.create! customer_number: "CUST", output_style: "standard", enabled: true, module_type: "Entry", setup: [{model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true}].to_json
      config.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "eq", value: "val", include_empty: false

      get :show, id: config.id

      expect(response).to be_success
      c = JSON.parse(response.body)

      expect(c['config']['milestone_notification_config']).to eq({
        id: config.id,
        customer_number: "CUST",
        enabled: true,
        output_style: "standard",
        testing: nil,
        module_type: "Entry",
        setup_json: {
          milestone_fields: [{model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true, label: "Broker Reference", event_code: "brok_ref"}],
          fingerprint_fields: []
        },
        search_criterions: [
          {mfid: "ent_brok_ref", label: "Broker Reference", operator: "eq", value: "val", include_empty: false, datatype: "string"}
        ]
        }.with_indifferent_access
      )
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
                testing: false,
                module_type: "Entry",
                setup_json: {
                  milestone_fields: [
                    {model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true},
                    {model_field_uid: "", timezone: "timezone", no_time: true}
                  ],
                  fingerprint_fields: ["ent_brok_ref", "ent_release_date"]
                },
                search_criterions: [
                  {mfid: "ent_brok_ref", operator: "eq", value: "val", include_empty: false}
                ]
              }
            }
    end
    it "creates an entry milestone config" do
      post :create, @c

      config = MilestoneNotificationConfig.first
      expect(config.customer_number).to eq "CUST"
      expect(config.enabled).to be_truthy
      expect(config.testing).to be_falsey
      expect(config.output_style).to eq "standard"
      expect(config.milestone_fields).to eq (
        [{"model_field_uid" => "ent_brok_ref", "timezone" => "timezone", "no_time" => true}]
      )
      expect(config.fingerprint_fields).to eq ["ent_brok_ref", "ent_release_date"]
      
      expect(config.search_criterions.first.model_field_uid).to eq "ent_brok_ref"
      expect(config.search_criterions.first.operator).to eq "eq"
      expect(config.search_criterions.first.value).to eq "val"
      expect(config.search_criterions.first.include_empty?).to be_falsey
    end

    it "creates an isf milestone config" do
      @c[:milestone_notification_config][:module_type] = "SecurityFiling"
      post :create, @c

      config = MilestoneNotificationConfig.first
      expect(config).not_to be_nil
    end

    it "rejects non-admin users" do
      allow_api_access Factory(:user)

      post :create, @c
      expect(response.status).to eq 403
      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})
    end

    it "errors on configs for non-entry, non-isf modules" do
      @c[:milestone_notification_config][:module_type] = "NotAModule"
      expect {post :create, @c}.to raise_error "Validation failed: Module type is not valid."
    end
  end

  describe "copy" do
    it "copies existing config to new one" do
      c = MilestoneNotificationConfig.create! customer_number: "CUST", module_type: "SecurityFiling", output_style: "standard", enabled: "true", setup: '{"milestone_fields":[{"model_field_uid":"ent_release_date","no_time":null,"timezone":null}],"fingerprint_fields":["ent_brok_ref"]}'
      c.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "eq", value: "val"

      get :copy, id: c.id

      expect(response).to be_success
      conf = JSON.parse(response.body)

      # This uses the exact same code to display the json as the show adn create methods, so just test the differences
      # that should come w/ the create (.ie blank id, no cust no, disabled..)
      expect(conf['config']['milestone_notification_config']['id']).to eq 0
      expect(conf['config']['milestone_notification_config']['customer_number']).to eq ""
      expect(conf['config']['milestone_notification_config']['enabled']).to eq false
      expect(conf['config']['milestone_notification_config']['setup_json']['milestone_fields'].length).to eq 1
      expect(conf['config']['milestone_notification_config']['setup_json']['fingerprint_fields'].length).to eq 1
      expect(conf['config']['milestone_notification_config']['search_criterions'].length).to eq 1
    end

    it "rejects non-admin users" do
      allow_api_access Factory(:user)

      get :copy, id: 1
      expect(response.status).to eq 403
      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})
    end
  end

  describe "update" do
    before :each do
      @config = MilestoneNotificationConfig.create! customer_number: "BLAH", output_style: "standard", module_type:"Entry"

      @c =  {milestone_notification_config: {
                 customer_number: "CUST",
                 output_style: "mbol_container",
                 enabled: false,
                 testing: true,
                 module_type: "Entry",
                 setup_json: {
                   milestone_fields: [
                     {model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true},
                     {model_field_uid: "", timezone: "timezone", no_time: true}
                   ],
                   fingerprint_fields: ["ent_brok_ref"]
                 },
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
      expect(@config.enabled).to be_falsey
      expect(@config.output_style).to eq "mbol_container"
      expect(@config.testing).to be_truthy
      expect(@config.milestone_fields).to eq (
        [{"model_field_uid" => "ent_brok_ref", "timezone" => "timezone", "no_time" => true}]
      )
      expect(@config.fingerprint_fields).to eq ["ent_brok_ref"]
      expect(@config.search_criterions.first.model_field_uid).to eq "ent_brok_ref"
      expect(@config.search_criterions.first.operator).to eq "eq"
      expect(@config.search_criterions.first.value).to eq "val"
      expect(@config.search_criterions.first.include_empty?).to be_falsey
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
      @config = MilestoneNotificationConfig.create! customer_number: "BLAH", output_style: "standard", module_type: "Entry"

      delete :destroy, id: @config.id
      expect(response).to be_success
      expect(response.body).to eq "{}"
      expect(MilestoneNotificationConfig.first).to be_nil
    end
  end

  describe "index" do
    it "lists all configs" do
      config = MilestoneNotificationConfig.create! customer_number: "CUST", output_style: "standard", testing: false, module_type:"Entry", setup: [{model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true}].to_json
      config.search_criterions.create! model_field_uid: "ent_brok_ref", operator: "eq", value: "val", include_empty: false
      config2 = MilestoneNotificationConfig.create! customer_number: "ABC",output_style: "standard", testing: true, module_type: "Entry"

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
            module_type: "Entry",
            setup_json: {milestone_fields: [], fingerprint_fields: []},
            search_criterions: [],
            testing: true
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
            testing: false,
            module_type:"Entry",
            setup_json: {
              milestone_fields: [{model_field_uid: "ent_brok_ref", timezone: "timezone", no_time: true, label: "Broker Reference", event_code: "brok_ref"}],
              fingerprint_fields: []
            },
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
        module_type: nil,
        setup_json: {
          milestone_fields: [],
          fingerprint_fields: []
        },
        search_criterions: [],
        testing: nil
        }.with_indifferent_access
      )

      # event and model field lists must be 0 until a module type is known
      expect(c['model_field_list']).to eq []
      expect(c['event_list']).to eq []

      expect(c["output_styles"]).to eq MilestoneNotificationConfig::OUTPUT_STYLES

      timezones = c["timezones"]
      # Plus one is because we're inserting a blank value 
      expect(timezones.size).to eq ActiveSupport::TimeZone.all.size + 1
      expect(timezones.first['name']).to be_a String
      expect(timezones.first['label']).to be_a String
    end
  end

  describe "model_fields" do

    it 'returns valid model fields for Entry module' do
      get :model_fields, {module_type: "Entry"}
      expect(response).to be_success
      c = JSON.parse response.body

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
    end

    it 'returns valid model fields for SecurityFiling module' do
      get :model_fields, {module_type: "SecurityFiling"}
      expect(response).to be_success
      c = JSON.parse response.body

      mf_list = c['model_field_list']
      expect(mf_list.size).to eq CoreModule::SECURITY_FILING.model_fields(@user).size
      event_list = c['event_list']
      expect(event_list.size).to eq CoreModule::SECURITY_FILING.model_fields(@user) {|mf| ([:date, :datetime].include? mf.data_type.to_sym)}.size
    end
  end
end