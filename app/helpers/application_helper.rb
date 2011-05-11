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

  #builds a text field to back a field represented with a model_field_uid in the ModelField constants.
  def model_text_field form_object, field_name, model_field_uid, opts={}
    inner_opts = opts_for_model_text_field model_field_uid, opts
    form_object.text_field(field_name,inner_opts)
  end

  def model_text_field_tag field_name, model_field_uid, value, opts={}
    inner_opts = opts_for_model_text_field model_field_uid, opts
    text_field_tag(field_name,value,inner_opts)
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
  def field_label model_field_uid
    mf = ModelField.find_by_uid model_field_uid
    return "Unknown Field" if mf.nil?
    mf.label
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
		opts = {:form=>false, :table=>false}.merge(opts)
	  x = ""
	  customizable.custom_definitions.order("rank ASC, label ASC").each {|d|
			name = "#{customizable.class.to_s.downcase}_cf[#{d.id}]"
			name = "#{opts[:parent_name]}#{customizable.class.to_s.downcase}_cf[#{d.id}]" unless opts[:parent_name].nil?
			c_val = customizable.get_custom_value(d).value
  		if opts[:table]
  		  field = ''
        field_tip_class = d.tool_tip.blank? ? "" : "fieldtip"
  		  if d.data_type=='boolean'
  		    if opts[:form]
  		      field = hidden_field_tag(name,c_val,:id=>"hdn_"+name.gsub(/[\[\]]/, '_')) + check_box_tag('ignore_me', "1", c_val, {:title=>"#{d.tool_tip}",:class=>"cv_chkbx #{field_tip_class}", :id=>"cbx_"+name.gsub(/[\[\]]/, '_')})
  		    else
  		      field = c_val ? "Yes" : "No"
  		    end
  		  elsif d.data_type=='text'
  		    field = opts[:form] ? text_area_tag(name, c_val, {:title=>"#{d.tool_tip}", :class=>field_tip_class,:rows=>5, :cols=>24}) : "#{c_val}"
  		  else
          field = opts[:form] ? model_text_field_tag(name, d.model_field_uid, c_val, {:title=>"#{d.tool_tip}", :class=>"#{d.date? ? "isdate" : ""} #{field_tip_class}", :size=>"30"}) : "#{c_val}"
  		  end
        x << field_row(d.label,field)          
  		else
				z = "<b>".html_safe+d.label+": </b>".html_safe
				if opts[:form]
				  z << model_text_field_tag(name, d.model_field_uid, c_val, {:title=>"#{d.tool_tip}", :class=>"#{d.date? ? "isdate" : ""} #{field_tip_class}"})
				else
				  z << "#{c_val}"
				end
				x << content_tag(:div, z.html_safe, :class=>'field')  	
		  end
	  }
    return opts[:table] ? x.html_safe : content_tag(:div, x.html_safe, :class=>'custom_field_box')	  
  end
  
  def field_row(label, field) 
    content_tag(:tr, content_tag(:td, label+": ", :class => 'label_cell')+content_tag(:td, field), :class=>'hover field_row')
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

  def show_tariff hts_number, country_id, with_popup_link=true
    return "" if hts_number.blank?
    if with_popup_link
      link_to hts_number.hts_format, "#", {:class=>'lnk_tariff_popup',:hts=>hts_number,:country=>country_id}
    else
      return hts_number.hts_format
    end
  end

  def tariff_more_info hts_number, country_id
    link_to "info", "#", {:class=>'lnk_tariff_popup',:hts=>hts_number,:country=>country_id}
  end

  private
  def opts_for_model_text_field model_field_uid, opts
    inner_opts = {:class=>val_class(model_field_uid),:mf_id=>model_field_uid}
    passed_class = opts.delete(:class)
    inner_opts[:class] << " " << passed_class unless passed_class.blank?
    inner_opts.merge! opts
    inner_opts 
  end
  def val_class model_field_uid
  #returns the string "rvalidate" if the field needs remote validation
    FieldValidatorRule.find_cached_by_model_field_uid(model_field_uid.to_s).empty? ? "" : "rvalidate"
  end
end
