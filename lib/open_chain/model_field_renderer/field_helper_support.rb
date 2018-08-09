# helper module for ApplicationHelper contianing
# methods used to render model fields
module OpenChain; module ModelFieldRenderer; module FieldHelperSupport
  def add_tooltip_to_html_options model_field, html_options
    tooltip = model_field.tool_tip
    if !tooltip.blank?
      html_options[:title] = tooltip if html_options[:title].blank?
      html_options[:class] ||= ''
      html_options[:class] << ' fieldtip '
    end
    nil
  end

  def get_form_field_name parent_name, form_object, mf
    pn = ''
    if !parent_name.blank?
      pn = parent_name
    else
      if form_object && form_object.respond_to?(:object_name)
        pn = form_object.object_name
      end
    end
    pn.blank? ? "#{mf.uid}" : "#{pn}[#{mf.uid}]"
  end

  def get_core_and_form_objects object_or_form
    core_object = nil
    form_object = nil
    if object_or_form.respond_to?(:fields_for)
      core_object = object_or_form.object
      form_object = object_or_form
    else
      core_object = object_or_form
    end
    [core_object,form_object]
  end

  # yield all model fields
  # takes an array or a single object
  # valid values are string, symbol or ModelField object
  def for_model_fields model_field_uids
    Array.wrap(model_field_uids).each do |mf_uid|
      if mf_uid.is_a? Hash
        value = get_model_field(mf_uid[:value])
        next if value.nil?

        label = mf_uid[:label]
        if label.is_a? Symbol
          label = get_model_field(label)
        end

        mf = {label: label, value: value}
      elsif mf_uid.is_a? Array
        value = get_model_field(mf_uid[1])
        next if value.nil?

        label = mf_uid[0]
        if label.is_a? Symbol
          label = get_model_field(label)
        end
        
        mf = [label, value]
      else
        mf = get_model_field(mf_uid)  
      end

      yield mf unless mf.nil?
    end
  end

  def get_model_field model_field_uid
    return nil if model_field_uid.nil?
    model_field_uid.is_a?(ModelField) ? model_field_uid : ModelField.find_by_uid(model_field_uid)
  end
  alias :mf :get_model_field

  def process_export model_field_uid, obj
    get_model_field(model_field_uid).process_export obj, current_user
  end
  alias :mf_export :process_export


  def skip_field? mf, user, hidden_field_override, read_only_override
    return false if hidden_field_override
    return true if !mf.can_view?(user) #skip fields the user cannot view
    return true if (!read_only_override && (mf.read_only? || !mf.can_edit?(user)))
    return false #default behavior is to show field
  end
end; end; end
