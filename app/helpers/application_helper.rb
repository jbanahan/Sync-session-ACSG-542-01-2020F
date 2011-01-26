module ApplicationHelper
  def show_custom_fields(customizable, opts={})
		opts = {:form=>false, :table=>false}.merge(opts)
	  x = ""
	  customizable.custom_definitions.order("rank ASC, label ASC").each {|d|
			name = "#{customizable.class.to_s.downcase}_cf[#{d.id}]"
			name = "#{opts[:parent_name]}#{customizable.class.to_s.downcase}_cf[#{d.id}]" unless opts[:parent_name].nil?
  		if opts[:table]
  		  field = ''
  		  if d.data_type=='boolean'
  		    field = hidden_field_tag(name,customizable.get_custom_value(d).value,:id=>"hdn_"+name.gsub(/[\[\]]/, '_')) + check_box_tag('ignore_me', "1", customizable.get_custom_value(d).value, {:disabled => !opts[:form], :class=>"cv_chkbx", :id=>"cbx_"+name.gsub(/[\[\]]/, '_')})
  		  elsif d.data_type=='text'
  		    field = opts[:form] ? text_area_tag(name, customizable.get_custom_value(d).value, {:rows=>5, :cols=>24}) : "#{customizable.get_custom_value(d).value}"
  		  else
          field = opts[:form] ? text_field_tag(name, customizable.get_custom_value(d).value, {:class=>"#{d.date? ? "isdate" : ""}", :size=>"30"}) : "#{customizable.get_custom_value(d).value}"
  		  end
        x << field_row(d.label,field)          
  		else
				z = "<b>".html_safe+d.label+": </b>".html_safe
				if opts[:form]
				  z << text_field_tag(name, customizable.get_custom_value(d).value, :class=>"#{d.date? ? "isdate" : ""}")
				else
				  z << "#{customizable.get_custom_value(d).value}"
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
end
