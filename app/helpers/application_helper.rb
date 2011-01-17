module ApplicationHelper
  def show_custom_fields(customizable, opts={})
		opts = {:form=>false, :table=>false}.merge(opts)
	  x = ""
	  customizable.custom_definitions.order("rank ASC, label ASC").each {|d|
			name = "#{customizable.class.to_s.downcase}_cf[#{d.id}]"
  		if opts[:table]
        field = opts[:form] ? text_field_tag(name, customizable.get_custom_value(d).value, :class=>"#{d.date? ? "isdate" : ""}") : "#{customizable.get_custom_value(d).value}"
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
    content_tag(:tr, content_tag(:td, label+": ", :class => 'label_cell')+content_tag(:td, field), :class=>'hover')
  end
end
