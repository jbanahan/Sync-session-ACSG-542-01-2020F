module Api; module V1; module Admin; class MilestoneNotificationConfigsController < Api::V1::Admin::AdminApiController

  def index 
    configs = MilestoneNotificationConfig.order(:customer_number).all.collect {|c| config_json(c)}
    render json: {configs: configs, output_styles: output_styles}
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

  private
    def save c, config
      c.customer_number = config[:customer_number]
      c.output_style = config[:output_style]
      c.enabled = config[:enabled].to_s.to_boolean
      
      config[:search_criterions].each do |sc|
        c.search_criterions.build model_field_uid: sc[:mfid], operator: sc[:operator], value: sc[:value], include_empty: sc[:include_empty]
      end if config[:search_criterions]
      
      setup = config[:setup_json]
      if setup
        j = []
        setup.each do |event|
          uid = event['model_field_uid']
          # uid could be blank if the user added a row, but then didn't fill anything in...skip it if that happened.
          next if uid.blank?

          mf = uid ? ModelField.find_by_uid(uid) : nil
          raise "Missing event_code for #{c.customer_number}.  No event model field for event code '#{uid}' found." unless mf

          conf = {model_field_uid: mf.uid.to_s, no_time: event["no_time"], timezone: event["timezone"]}
          j << conf
        end
        c.setup_json = j
      else
        c.setup_json = []
      end


      c.save!
      render json: config_json_with_model_fields(c)
    end

    def config_json_with_model_fields config
      json = config_json(config)
      {config: json, model_field_list: model_field_list, event_list: event_list, output_styles: output_styles, timezones: timezones}
    end

    def config_json config
      c = config.as_json(
        only: [:id, :customer_number, :enabled, :output_style],
        methods: [:setup_json]
      ).with_indifferent_access
      c[:milestone_notification_config][:setup_json].each do |setup|
        field = ModelField.find_by_uid setup["model_field_uid"]
        setup['label'] = field.label
        setup['event_code'] = field.uid.to_s.sub /^[^_]+_/, "" # Just trim the leading segement of the front of the uids and use as the event code
      end
      c[:milestone_notification_config][:search_criterions] = config.search_criterions.collect {|sc| sc.json(current_user)}
      c
    end


    def model_field_list
      model_fields = CoreModule::ENTRY.model_fields(current_user)
      fields = []
      model_fields.each_pair {|uid, mf| fields << {field_name: mf.field_name.to_s, mfid: mf.uid.to_s, label: mf.label(true), datatype: mf.data_type.to_s} }
      fields
    end

    def event_list 
      model_fields = CoreModule::ENTRY.model_fields(current_user) {|mf| ([:date, :datetime].include? mf.data_type.to_sym)}
      fields = []
      model_fields.each_pair {|uid, mf| fields << {field_name: mf.field_name.to_s, mfid: mf.uid.to_s, label: "#{mf.label} (#{mf.field_name}) - #{mf.data_type.to_s == "datetime" ? "Datetime" : "Date"}", datatype: mf.data_type.to_s} }
      fields
    end

    def output_styles
      MilestoneNotificationConfig::OUTPUT_STYLES
    end

    def timezones
      ActiveSupport::TimeZone.all.map {|tz| {name: tz.name, label: "#{tz.name} (#{tz.formatted_offset})" }}.insert(0, {name: "", label: ""})
    end
end; end; end; end;