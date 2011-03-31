module ApplicationHelper
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
  		  if d.data_type=='boolean'
  		    if opts[:form]
  		      field = hidden_field_tag(name,c_val,:id=>"hdn_"+name.gsub(/[\[\]]/, '_')) + check_box_tag('ignore_me', "1", c_val, {:title=>"#{d.tool_tip}",:class=>"cv_chkbx fieldtip", :id=>"cbx_"+name.gsub(/[\[\]]/, '_')})
  		    else
  		      field = c_val ? "Yes" : "No"
  		    end
  		  elsif d.data_type=='text'
  		    field = opts[:form] ? text_area_tag(name, c_val, {:title=>"#{d.tool_tip}", :class=>'fieldtip',:rows=>5, :cols=>24}) : "#{c_val}"
  		  else
          field = opts[:form] ? text_field_tag(name, c_val, {:title=>"#{d.tool_tip}", :class=>"#{d.date? ? "isdate" : ""} fieldtip", :size=>"30"}) : "#{c_val}"
  		  end
        x << field_row(d.label,field)          
  		else
				z = "<b>".html_safe+d.label+": </b>".html_safe
				if opts[:form]
				  z << text_field_tag(name, c_val, :title=>"#{d.tool_tip}", :class=>"#{d.date? ? "isdate" : ""} fieldtip")
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
    if with_popup_link
      link_to hts_number, "#", {:class=>'lnk_tariff_popup',:hts=>hts_number,:country=>country_id}
    else
      return hts_number
    end
  end

  def tariff_more_info hts_number, country_id
    link_to "info", "#", {:class=>'lnk_tariff_popup',:hts=>hts_number,:country=>country_id}
  end
end
