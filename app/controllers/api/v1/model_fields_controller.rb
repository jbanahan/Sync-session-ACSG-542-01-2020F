require 'digest/md5'

module Api; module V1; class ModelFieldsController < Api::V1::ApiController
  API_MODULES = [CoreModule::PRODUCT, CoreModule::CLASSIFICATION, CoreModule::TARIFF, CoreModule::ORDER, CoreModule::ENTRY, CoreModule::OFFICIAL_TARIFF]

  def index
    h = {}
    h['recordTypes'] = []
    h['fields'] = []
    h['cache_key'] = make_cache_key
    API_MODULES.each do |cm|
      next unless cm.view?(current_user)
      cm_class_name = cm.class_name
      h['recordTypes'] << {'uid'=>cm_class_name,label:cm.label}
      ModelField.find_by_core_module(cm).each do |mf|
        next unless mf.can_view?(current_user)
        mf_h = {'uid'=>mf.uid, 'label'=>mf.label, 'data_type'=>mf.data_type, 'record_type_uid'=>cm_class_name, 'read_only' => mf.read_only?}
        h['fields'] << mf_h
      end
    end
    render json: h
  end

  def cache_key
    render json: {cache_key: make_cache_key}
  end

  private def make_cache_key
    Digest::MD5.hexdigest "#{current_user.username}#{ModelField.last_loaded.to_s}#{current_user.company.updated_at.to_i}#{current_user.updated_at.to_i}"
  end

end; end; end