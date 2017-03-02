require 'open_chain/api/api_entity_jsonizer'
require 'digest/sha2'

module OpenChain; module Api; class ApiEntityXmlizer
  def initialize opts={}
    @jsonizer = OpenChain::Api::ApiEntityJsonizer.new(opts)
    @fingerprint = nil
  end

  # This method generates XML from the given entity and list of model field uids.
  def entity_to_xml user, entity, model_field_uids
    entity_hash = @jsonizer.entity_to_hash(user,entity,model_field_uids)
    entity_hash['xml-generated-time'] = Time.now.utc.strftime("%Y-%m-%dT%l:%M:%S:%L%z")
    make_xml entity, entity_hash
  end

  # This method generates XML from the given entity and data hash of the entity's values.
  def make_xml entity, entity_hash
    root_tag = CoreModule.find_by_object(entity).class_name.underscore
    replace_tag_names entity_hash

    entity_hash.to_xml(root:root_tag)
  end

  def xml_fingerprint xml, ignore_paths: nil
    if xml.is_a? String
      xml = REXML::Document.new xml
    end

    if ignore_paths.nil?
      # By default, we'll extract out the xml-generated-time element that's added to every xml
      ignore_paths = ["/*/xml-generated-time"]
    end

    # Basically, we're just going to go through and delete all the paths that should 
    # be ignored for fingerprinting purposes.  This is generally going to be timestamp-like 
    # fields that are meta-data that will be distinct every single time the xml is generated.
    Array.wrap(ignore_paths).each do |xpath|
      xml.elements.delete xpath
    end

    # Now just use the most compact REXML output style, generate it to a string and then 
    # get a sha256 hash of that string.
    out = StringIO.new
    REXML::Formatters::Default.new.write(xml, out)
    out.rewind
    Digest::SHA256.hexdigest out.read
  end

  def replace_tag_names hash
    hash.keys.each do |uid|
      mf = ModelField.find_by_uid uid
      val = hash[uid]
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
