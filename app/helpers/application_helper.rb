module ApplicationHelper
  def show_custom_fields(customizable, opts={})
		opts = {:form=>false}.merge(opts)
		rval = ""
		if opts[:form]
		  x = ""
			customizable.custom_definitions.order("rank ASC, label ASC").each {|d| 
				name = "#{customizable.class.to_s.downcase}_cf[#{d.id}]"
					z = d.label+"<br />".html_safe+text_field_tag(name, customizable.get_custom_value(d).value, :class=>"#{d.date? ? "isdate" : ""}")
					x << content_tag(:div, z.html_safe, :class=>'field')
			} 
			rval =	content_tag(:div, x.html_safe, :class=>'custom_field_box')
		else
		  x = ""
			customizable.custom_definitions.order("rank ASC, label ASC").each {|d| 
					x << content_tag(:p, content_tag(:b, d.label+": ")+"#{customizable.get_custom_value(d).value}")
			} 
			rval =	content_tag(:div, x.html_safe, :class=>'custom_field_box')
		end 
		return rval
  end
end
