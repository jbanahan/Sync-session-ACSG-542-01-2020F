module ApplicationHelper
  ICON_WRITE = "icon_write.png"
  ICON_SHEET = "icon_sheet.png"
  ICON_PRESENT = "icon_present.png"
  ICON_PDF = "icon_pdf.png"
  ICONS = {:doc=>ICON_WRITE,:docx=>ICON_WRITE,:docm=>ICON_WRITE,:odt=>ICON_WRITE,
    :xls=>ICON_SHEET,:xlsx=>ICON_SHEET,:xlsm=>ICON_SHEET,:ods=>ICON_SHEET,
    :ppt=>ICON_PRESENT,:pptx=>ICON_PRESENT,:pptm=>ICON_PRESENT,:odp=>ICON_PRESENT,
    :pdf=>ICON_PDF
  }


  #create a visual
  def section_box title, html_options={}, &block
    inner_opts = {}.merge html_options
    if inner_opts[:class]
      inner_opts[:class] = "#{inner_opts[:class]} section_box"
    else
      inner_opts[:class] = "section_box"
    end
    content_tag('div', inner_opts) do 
      content_tag('div',title,:class=>'section_head') +
      content_tag('div',:class=>'section_body') do
        yield 
      end
    end
  end
  def search_result_value result_value, no_time 
    return "false" if !result_value.nil? && result_value.is_a?(FalseClass)
    return "&nbsp;".html_safe if result_value.blank?
    if result_value.respond_to?(:strftime)
      if result_value.is_a?(Date) || no_time
        return result_value.strftime("%Y-%m-%d")
      else
        return result_value.strftime("%Y-%m-%d %H:%M")
      end
    end
    result_value
  end

  # if the ModelField is read only then this method returns the output of process_export on the model field
  # otherwise it returns the result of the yield
  def read_only_wrap object, model_field_uid
    mf = ModelField.find_by_uid model_field_uid
    if mf.read_only?
      mf.process_export object, current_user
    else
      yield
    end
  end
  #render view of field in table row form
  def field_view_row object, model_field_uid, show_prefix=nil
    l = lambda {|label,field,never_hide,model_field| field_row(label,field,never_hide,model_field)}
    field_view_generic object, model_field_uid, show_prefix, l
  end

  # render field in bootstrap friendly view mode
  def field_view_bootstrap object, model_field_uid, show_prefix=nil
    l = lambda {|b,f,n,m| field_bootstrap b,f,n,m}
    field_view_generic object, model_field_uid, show_prefix, l
  end

  # render the value of the given model field for the given object
  # model_field can be either an instance of ModelField or a symbol with the model field's uid
  def field_value object, model_field
    mf = model_field.class==ModelField ? model_field : ModelField.find_by_uid(model_field)
    val = mf.process_export object, User.current
    if val 
      if mf.currency
        case mf.currency
        when :usd
          val = number_to_currency val
        else
          val = number_to_currency val, {:format=>"%n",:negative_format=>"-%n"}
        end
      elsif mf.data_type == :decimal
        # Using precision 5 since that'll cover pretty much every decimal field in the system.
        val = number_with_precision val, :precision => 5, :strip_insignificant_zeros => true
      end
    end
    val
  end

  #build a select box with all model_fields grouped by module.
  def select_model_fields_tag(name,selected,opts={})
    opts[:class] ||= ''
    opts[:class] << ' form-control'
    select_tag name, grouped_options_for_select(CoreModule.grouped_options,selected,"Select a Field"), opts
  end

  #builds a text field to back a field represented with a model_field_uid in the ModelField constants.
  #will write a select box if the field's validators include a .one_of validation
  def model_text_field form_object, field_name, model_field_uid, opts={}
    inner_opts = opts_for_model_text_field model_field_uid, opts
    mf = ModelField.find_by_uid(model_field_uid)
    if mf.read_only?
      return content_tag(:span,mf.process_export(form_object.object,current_user))
    end
    r = FieldValidatorRule.find_cached_by_model_field_uid model_field_uid
    if r.size>0 && r[0].one_of_array.size > 0
      inner_opts.delete :size
      inner_opts.delete "size"
      return form_object.select(field_name,r[0].one_of_array,{:include_blank=>true},inner_opts)
    else
      return form_object.text_field(field_name,inner_opts)
    end
  end

  def model_text_field_tag field_name, model_field_uid, value, opts={}
    inner_opts = opts_for_model_text_field model_field_uid, opts
    r = FieldValidatorRule.find_cached_by_model_field_uid model_field_uid
    if r.size>0 && r[0].one_of_array.size>0
      inner_opts.delete :size
      inner_opts.delete "size"
      a = [""]+r[0].one_of_array
      select_tag(field_name,options_for_select(a,value),inner_opts)
    else
      text_field_tag(field_name,value,inner_opts)
    end
  end
  def model_text_area_tag field_name, model_field_uid, value, opts={}
    inner_opts = opts_for_model_text_field model_field_uid, opts
    text_area_tag(field_name,value,inner_opts);
  end


  def attachment_icon att
    opts = {:class=>"attachment_icon",:alt=>att.attached_file_name,:width=>"48px"}
    link_opts = {}
    fn = att.attached_file_name
    icon = image_tag("icon_other.png",opts)
    if att.web_preview?
      opts[:width]="75px"
      opts[:style]="border:1px solid #d7d7d7;"
      link_opts[:target]="chainio_attachment"
      icon = image_tag(download_attachment_path(att), opts)
    elsif !fn.blank?
      ext = fn.split('.').last.downcase.to_sym
      icon = image_tag(ICONS[ext],opts) unless ICONS[ext].nil?
    end
    link_to icon, download_attachment_path(att), link_opts
  end
  #show the label for the field.  show_prefix options: nil=default core module behavior, true=always show prefix, false=never show prefix
  def field_label model_field_uid, show_prefix=nil
    mf = ModelField.find_by_uid model_field_uid
    return "Unknown Field" if mf.nil?
    content_tag(:span,mf.label(show_prefix),{:class=>"fld_lbl",:entity_type_ids=>entity_type_ids(mf)})
  end
  def help_link(text,page_name=nil)
    "<a href='/help#{page_name.blank? ? "" : "?page="+page_name}' target='chainio_help'>#{text}</a>".html_safe
  end
  def help_image(file_name)
    image_tag("help/#{file_name}",:class=>'help_pic')
  end
  def bool_txt(bool) 
    bool ? "Yes" : "No"
  end
  def has_custom_fields(customizable)
    !customizable.custom_definitions.empty?
  end
  def show_custom_fields(customizable, opts={})
		opts = {:form=>false, :table=>false, :show_prefix=>nil, :never_hide=>false}.merge(opts)
	  x = ""
    custom_value_hash = {}
    customizable.custom_values.each {|cv| custom_value_hash[cv.custom_definition_id] = cv}
	  CustomDefinition.where(:module_type => customizable.class.to_s).order("rank ASC, label ASC").each {|d|
      mf = d.model_field
      next unless mf
      name = "#{customizable.class.to_s.downcase}_cf[#{d.id}]"
      name = "#{opts[:parent_name]}#{customizable.class.to_s.downcase}_cf[#{d.id}]" unless opts[:parent_name].nil?
      c_val_obj = custom_value_hash[d.id]
      c_val_obj = customizable.get_custom_value d if c_val_obj.nil?
      c_val = c_val_obj.value d
      if opts[:table]
        if opts[:form] && !mf.read_only?
          field = ''
          field_tip_class = d.tool_tip.blank? ? "" : "fieldtip"
          case d.data_type
          when 'boolean'
            field = hidden_field_tag(name,c_val,:id=>"hdn_"+name.gsub(/[\[\]]/, '_')) + check_box_tag('ignore_me', "1", c_val, {:title=>"#{d.tool_tip}",:class=>"cv_chkbx #{field_tip_class} #{data_type_class(mf)}", :id=>"cbx_"+name.gsub(/[\[\]]/, '_')})
          when 'text'
            field = model_text_area_tag(name, d.model_field_uid, c_val, {:title=>"#{d.tool_tip}", :class=>"#{field_tip_class} #{data_type_class(mf)}",:rows=>5})
          else
            field = model_text_field_tag(name, d.model_field_uid, c_val, {:title=>"#{d.tool_tip}", :class=>"#{data_type_class(mf)} #{field_tip_class}", :size=>"30"})
          end
          x << field_row(field_label(d.model_field_uid,opts[:show_prefix]),field)          
        else
          x << field_view_row(customizable, d.model_field_uid,opts[:show_prefix])
        end
      else
        z = ""
        if opts[:form] && !mf.read_only?
          case d.data_type
          when 'boolean'
            z << hidden_field_tag(name,c_val,:id=>"hdn_"+name.gsub(/[\[\]]/, '_')) + check_box_tag('ignore_me', "1", c_val, {:title=>"#{d.tool_tip}",:class=>"cv_chkbx #{field_tip_class} #{data_type_class(mf)}", :id=>"cbx_"+name.gsub(/[\[\]]/, '_')})
          when 'text'
            z << model_text_area_tag(name, d.model_field_uid, c_val, {:title=>"#{d.tool_tip}", :class=>"#{field_tip_class} #{data_type_class(mf)}",:rows=>5})
          else
            z << model_text_field_tag(name, d.model_field_uid, c_val, {:title=>"#{d.tool_tip}", :class=>"#{d.date? ? "isdate" : ""} #{field_tip_class}"})
          end
        else
          z << "#{c_val}"
        end
        lbl = 
        x << field_bootstrap(field_label(d.model_field_uid,opts[:show_prefix]), z.html_safe, opts[:never_hide], mf)  	
      end
	  }
    return opts[:table] ? x.html_safe : content_tag(:div, x.html_safe, :class=>'custom_field_box')	  
  end
  
  # render <tr> with field content
  def field_row(label, field, never_hide=false, model_field=nil) 
    content_tag(:tr, content_tag(:td, label.blank? ? "" : label+": ", :class => 'label_cell')+content_tag(:td, field, :style=>"#{model_field && [:decimal,:integer].include?(model_field.data_type) ? "text-align:right;" : ""}"), :class=>"hover field_row #{never_hide ? "neverhide" : ""}")
  end

  # render bootstrap friendly field content
  def field_bootstrap label, field, never_hide=false, model_field=nil
    return '' if !never_hide && field.blank?
    field_content = field
    if model_field && model_field.data_type==:text
      field_content = content_tag(:pre,field,:class=>'pre-nochrome')
    end
    content_tag(:div, 
      content_tag(:div,
        label.blank? ? '' : label,
        :class=>'col-md-4', :style=>'font-weight:bold;'
      ) +
      content_tag(:div,field_content,:class=>'col-md-8'),
      :class=>'row bootstrap-hover'
    )
  end
  
  def model_field_label(model_field_uid) 
    r = ""
    return "" if model_field_uid.nil?
    mf = ModelField.find_by_uid(model_field_uid)
    return "" if mf.nil?
    return mf.label
  end

  #takes the values added to the array passed into the block and creates a comma separated list
  def comma_list &block
    base = []
    yield base
    CSV.generate_line base, {:row_sep=>"",:col_sep=>", "} 
  end

  def show_schedule_b schedule_b_number, with_popup_link=true
    return "" if schedule_b_number.blank?
    if with_popup_link
      return link_to schedule_b_number.hts_format, "#", {:class=>'lnk_schedb_popup',:schedb=>schedule_b_number}
    else
      return schedule_b_number.hts_format
    end
  end
  def show_tariff hts_number, country_id, with_popup_link=true
    return "" if hts_number.blank?
    if with_popup_link
      content_tag :span, (hts_number.hts_format + " " + tariff_more_info(hts_number,country_id)).html_safe
    else
      return hts_number.hts_format
    end
  end

  def tariff_more_info hts_number, country_id
    link_to "info", "#", {:class=>'lnk_tariff_popup btn btn-xs btn-default',:hts=>hts_number,:country=>country_id}
  end

  def secure_link obj, user
      return "" unless user.sys_admin?
      sec_url = obj.last_file_secure_url
      return "" unless sec_url
      return content_tag('div', content_tag('b',"Integration File:") + " " + link_to(obj.last_file_path.split("/").last, sec_url)).html_safe
  end

  private

  # render generic field view, last parameter is lambda for actual rendering
  # which should take label, field, never_hide, model_field (see field_row)
  def field_view_generic object, model_field_uid, show_prefix, render_lambda
    mf = ModelField.find_by_uid(model_field_uid)
    show_field = mf.can_view? User.current
    if show_field && !mf.entity_type_field? && object.respond_to?('entity_type_id')
      e_id = object.entity_type_id
      ids = mf.entity_type_ids
      show_field = false if !e_id.nil? && !ids.include?(e_id)
    end
    show_field ? render_lambda.call(field_label(model_field_uid,show_prefix),  field_value(object,mf),false,mf) : ""
  end

  def opts_for_model_text_field model_field_uid, opts
    inner_opts = {:class=>"form-control #{val_class(model_field_uid)}",:mf_id=>model_field_uid}
    passed_class = opts.delete(:class)
    inner_opts[:class] << " " << passed_class unless passed_class.blank?
    inner_opts.merge! opts
    inner_opts 
  end
  def val_class model_field_uid
  #returns the string "rvalidate" if the field needs remote validation
    r = ""
    r << "rvalidate " unless FieldValidatorRule.find_cached_by_model_field_uid(model_field_uid.to_s).empty?
    mf = ModelField.find_by_uid(model_field_uid)
    case mf.data_type
    when :decimal
      r << "decimal "
    when :integer
      r << "integer "
    when :date
      r << "isdate "
    when :datetime
      r << "isdate "
    when :fixnum
      r << "decimal "
    end
    r
  end
  def entity_type_ids model_field
    ids = model_field.entity_type_ids 
    r = "*"
    ids.each {|i| r << "#{i}*"}
    r
  end
  def data_type_class model_field
    case model_field.data_type
    when :date
      return " isdate "
    when :datetime
      return " isdate "
    when :integer
      return " integer "
    when :decimal
      return " decimal "
    else
      return ""
    end
  end
end
