module Api; module V1; module Admin; class MilestoneNotificationConfigsController < Api::V1::Admin::AdminApiController

  def index 
    configs = MilestoneNotificationConfig.order(:customer_number, :testing).all.collect {|c| config_json(c)}
    render json: {configs: configs, output_styles: output_styles, module_types: module_types}
  end

  def update
    c = MilestoneNotificationConfig.find params[:id]
    c.search_criterions.destroy_all
    save c, params[:milestone_notification_config]
  end

  def new
    c = MilestoneNotificationConfig.new
    render json: config_json_with_model_fields(c)
  end

  def model_fields
    render json: {model_field_list: model_field_list(params[:module_type]), event_list: event_list(params[:module_type])}
  end

  def create
    c = MilestoneNotificationConfig.new
    save c, params[:milestone_notification_config]
  end

  def show
    render json: config_json_with_model_fields(MilestoneNotificationConfig.find params[:id])
  end

  def destroy
    c = MilestoneNotificationConfig.find params[:id]
    c.destroy

    render json: {}
  end

  def copy
    c = MilestoneNotificationConfig.find params[:id]
    render json: config_json_with_model_fields(c, true)
  end

  private
    def save c, config
      c.customer_number = config[:customer_number]
      c.output_style = config[:output_style]
      c.enabled = config[:enabled].to_s.to_boolean
      c.testing = config[:testing].to_s.to_boolean
      c.module_type = config[:module_type]
      
      config[:search_criterions].each do |sc|
        c.search_criterions.build model_field_uid: sc[:mfid], operator: sc[:operator], value: sc[:value], include_empty: sc[:include_empty]
      end if config[:search_criterions]
      
      setup = config[:setup_json]
      setup_json = {}
      if setup
        fields = []
        Array.wrap(setup[:milestone_fields]).each do |event|
          uid = event['model_field_uid']
          # uid could be blank if the user added a row, but then didn't fill anything in...skip it if that happened.
          next if uid.blank?

          mf = uid ? ModelField.find_by_uid(uid) : nil
          raise "Missing event_code for #{c.customer_number}.  No event model field for event code '#{uid}' found." unless mf

          conf = {model_field_uid: mf.uid.to_s, no_time: event["no_time"], timezone: event["timezone"]}
          fields << conf
        end

        fingerprint_fields = []
        Array.wrap(setup[:fingerprint_fields]).each do |field|
          next if field.blank?
          
          mf = ModelField.find_by_uid(field)
          raise "Missing identifier field for #{c.customer_number}.  No model field for code '#{field}' found." unless mf
          fingerprint_fields << field
        end
        setup_json[:milestone_fields] = fields
        setup_json[:fingerprint_fields] = fingerprint_fields
      end

      c.setup_json = setup_json
      c.save!
      render json: config_json_with_model_fields(c)
    end

    def config_json_with_model_fields config, copy = false
      json = config_json(config, copy)
      {config: json, model_field_list: model_field_list(config.module_type), event_list: event_list(config.module_type), output_styles: output_styles, timezones: timezones, module_types: module_types}
    end

    def config_json config, copy = false
      c = config.as_json(
        only: [:id, :customer_number, :enabled, :output_style, :testing, :module_type]
      ).with_indifferent_access

      # This is a little wonkier than it needs to be due to supporting some older json formats in the setup_json field
      c[:milestone_notification_config][:setup_json] = {}
      c[:milestone_notification_config][:setup_json][:milestone_fields] = config.milestone_fields
      c[:milestone_notification_config][:setup_json][:fingerprint_fields] = config.fingerprint_fields

      c[:milestone_notification_config][:setup_json][:milestone_fields].each do |setup|
        field = ModelField.find_by_uid setup["model_field_uid"]
        setup['label'] = field.label
        setup['event_code'] = field.uid.to_s.sub /^[^_]+_/, "" # Just trim the leading segement of the front of the uids and use as the event code
      end unless c[:milestone_notification_config][:setup_json][:milestone_fields].blank?
      c[:milestone_notification_config][:search_criterions] = config.search_criterions.collect {|sc| sc.json(current_user)}

      if copy
        c[:milestone_notification_config][:customer_number] = ""
        c[:milestone_notification_config][:enabled] = false
        c[:milestone_notification_config][:id] = 0
      end

      c
    end


    def model_field_list module_type
      cm = CoreModule.find_by_class_name(module_type)
      fields = []
      if cm
        model_fields = cm.model_fields(current_user)
        fields = []
        model_fields.each_pair {|uid, mf| fields << {field_name: mf.field_name.to_s, mfid: mf.uid.to_s, label: mf.label(true), datatype: mf.data_type.to_s} }
        fields = fields.sort {|x, y| x[:label] <=> y[:label]}
      end
      
      fields
    end

    def event_list  module_type
      cm = CoreModule.find_by_class_name(module_type)
      fields = []
      if cm
        model_fields = cm.model_fields(current_user) {|mf| ([:date, :datetime].include? mf.data_type.to_sym)}
        model_fields.each_pair {|uid, mf| fields << {field_name: mf.field_name.to_s, mfid: mf.uid.to_s, label: "#{mf.label} (#{mf.field_name}) - #{mf.data_type.to_s == "datetime" ? "Datetime" : "Date"}", datatype: mf.data_type.to_s} }
        fields = fields.sort {|x, y| x[:label] <=> y[:label]}
      end
      
      fields
    end

    def output_styles
      MilestoneNotificationConfig::OUTPUT_STYLES
    end

    def timezones
      ActiveSupport::TimeZone.all.map {|tz| {name: tz.name, label: "#{tz.name} (#{tz.formatted_offset})" }}.insert(0, {name: "", label: ""})
    end

    def module_types
      {CoreModule::SECURITY_FILING.class_name => "ISF", CoreModule::ENTRY.class_name => "Entry"}
    end
end; end; end; end;