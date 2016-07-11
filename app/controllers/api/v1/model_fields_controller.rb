require 'digest/md5'

module Api; module V1; class ModelFieldsController < Api::V1::ApiController
  API_MODULES ||= [CoreModule::PRODUCT,
    CoreModule::CLASSIFICATION,
    CoreModule::TARIFF,
    CoreModule::ORDER,
    CoreModule::ORDER_LINE,
    CoreModule::ENTRY,
    CoreModule::OFFICIAL_TARIFF,
    CoreModule::VARIANT,
    CoreModule::TRADE_LANE,
    CoreModule::TRADE_PREFERENCE_PROGRAM,
    CoreModule::TPP_HTS_OVERRIDE
  ]

  def index
    cu = current_user
    text_to_render = Rails.cache.fetch("Api::V1::ModelFields#index-#{ModelField.last_loaded}-#{cu.id}-#{cu.updated_at.to_i}") do
      validator_rules = Hash[FieldValidatorRule.all.map{|fvr| [fvr.model_field_uid.to_sym, fvr]}]
      h = {}
      h['recordTypes'] = []
      h['fields'] = []
      h['cache_key'] = make_cache_key
      API_MODULES.each do |cm|
        next unless cm.view?(cu)
        cm_class_name = cm.class_name
        h['recordTypes'] << {'uid'=>cm_class_name,label:cm.label}
        ModelField.find_by_core_module(cm).each do |mf|
          next if !mf.can_view?(cu) || !mf.user_accessible
          mf_h = {'uid'=>mf.uid, 'label'=>mf.label(false), 'data_type'=>mf.data_type, 'record_type_uid'=>cm_class_name, 'read_only' => mf.read_only?}
          select_opts = mf.select_options
          mf_h['select_options'] = select_opts
          mf_h['autocomplete'] = mf.autocomplete unless mf.autocomplete.blank?
          mf_h['can_edit'] = mf.can_edit?(cu)
          fvr = validator_rules[mf.uid.to_sym]
          if fvr
            mf_h['remote_validate'] = true
            if fvr.one_of_array.length > 0
              #clobber the hard coded options with the customer configured ones if they both exist.
              #This is on purpose - BSG 2015-09-16
              mf_h['select_options'] = fvr.one_of_array.collect {|a| [a,a]} #api expects 2 dimensional array
            end
          end
          mf_h['user_id_field'] = true if mf.user_id_field?
          mf_h['user_field'] = true if mf.user_field?
          mf_h['user_full_name_field'] = true if mf.user_full_name_field?
          mf_h['required'] = true if mf.required?
          h['fields'] << mf_h
        end
      end
      h.to_json
    end
    render json: text_to_render
  end

  def cache_key
    render json: {cache_key: make_cache_key}
  end

  private def make_cache_key
    Digest::MD5.hexdigest "#{current_user.username}#{ModelField.last_loaded.to_s}#{current_user.company.updated_at.to_i}#{current_user.updated_at.to_i}"
  end

end; end; end
