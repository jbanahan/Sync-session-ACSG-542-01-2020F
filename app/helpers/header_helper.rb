module HeaderHelper
  def nav_section id, title, render_me=true
    r = ""
    if render_me
      heading = content_tag('div',class:'panel-heading') do
        content_tag('h3','class'=>'panel-title','data-toggle'=>'collapse','data-target'=>"#nav-list-#{id}") do
          link_to(title,'#',onclick:'return false;')
        end
      end
      body = content_tag('div',class:'panel-collapse collapse',id:"nav-list-#{id}") do
        content_tag('div',class:'list-group') do
          yield
        end
      end
      r = content_tag 'div',class:'panel',id:id do
        heading + body
      end
    end
    r
  end

  def nav_item title, url, render_me=true
    render_me ? link_to(title,url,class: 'list-group-item') : ""
  end
end