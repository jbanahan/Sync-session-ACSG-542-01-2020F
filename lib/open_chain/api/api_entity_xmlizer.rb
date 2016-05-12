require 'open_chain/api/api_entity_jsonizer'
module OpenChain; module Api; class ApiEntityXmlizer
  def initialize opts={}
    @jsonizer = OpenChain::Api::ApiEntityJsonizer.new(opts)
  end

  def entity_to_xml user, entity, model_field_uids
    entity_hash = @jsonizer.entity_to_hash(user,entity,model_field_uids)
    make_xml entity, entity_hash
  end

  def make_xml entity, entity_hash
    root_tag = CoreModule.find_by_object(entity).class_name.underscore
    replace_tag_names entity_hash
    entity_hash.to_xml(root:root_tag)
  end

  def replace_tag_names hash
    hash.keys.each do |uid|
      mf = ModelField.find_by_uid uid
      val = hash[uid]
      if val.blank?
        hash.delete uid
        next
      end
      if !mf.blank?
        hash.delete uid
        hash[mf.xml_tag_name] = val
      end
      if val.is_a?(Array)
        val.each do |v_hash|
          replace_tag_names v_hash
        end
      elsif val.is_a?(Hash)
        replace_tag_names val
      end
    end
  end
end; end; end
