module WorkflowHelper
  include ActionView::Helpers::SanitizeHelper
  include ActionDispatch::Routing::UrlFor

  def task_panel base_object
    h = Hash.new
    anchors = Hash.new
    base_object.workflow_instances.includes(:workflow_tasks).each do |wi|
      wi.workflow_tasks.each do |wt|
        category = wt.test_class.category
        h[category] ||= []
        h[category] << wt
        anchors[category] = "wf-#{category.parameterize}"
      end
    end
    summary_tab, summary_count = summary_tab(base_object)
    my_tab, my_count = my_tasks_tab(base_object)
    tabs = [
      task_tab('Summary',summary_count,'wf-summary',{active:true}),
      task_tab('My Tasks',my_count,'wf-my-tasks',{label_type:'danger'})
    ]
    tab_pages = [
      summary_tab,
      my_tab
    ]
    h.keys.sort.collect do |tab_name|
      anchor = anchors[tab_name]
      
      tab_page_content, open_count = task_tab_pane(h[tab_name],anchor)
      tabs << task_tab(tab_name,open_count,anchor)

      tab_pages << tab_page_content
      
    end
    tab_list = content_tag(:ul,tabs.join.html_safe,:class=>'nav nav-tabs',:role=>'tablist')


    tab_content = content_tag(:div,tab_pages.join.html_safe,:class=>'tab-content')
    content_tag(:div,tab_list+tab_content,:role=>'tabpanel')

  end

  def due_for_me_panel
    tasks = WorkflowTask.includes(:workflow_instance=>:base_object).for_user(current_user).not_passed.where('workflow_tasks.assigned_to_id = ?',current_user.id).order('workflow_tasks.due_at DESC')
    r = ''
    if tasks.empty?
      r = content_tag(:div,"You have no incomplete tasks assigned.",:class=>'alert alert-success')
    else
      by_due = {}
      tasks.each do |t|
        due_label = due_at_label(t)
        by_due[due_label] ||= []
        by_due[due_label] << t
      end
      r = grouped_tasks(by_due) {|due_at| due_at}
    end
    r
  end

  def by_page_panel
    tasks = WorkflowTask.includes(:workflow_instance=>:base_object).for_user(current_user).not_passed.order('workflow_tasks.due_at DESC')
    r = ''
    if tasks.empty?
      r = content_tag(:div,"You have no incomplete tasks.",:class=>'alert alert-success')
    else
      by_page = {}
      tasks.each do |t|
        bo = t.base_object
        by_page[bo] ||= []
        by_page[bo] << t
      end
      r = grouped_tasks(by_page) {|bo| task_group_label(bo)}
    end
    r
  end

  def by_due_panel
    tasks = WorkflowTask.includes(:workflow_instance=>:base_object).for_user(current_user).not_passed.order('workflow_tasks.due_at DESC')
    r = ''
    if tasks.empty?
      r = content_tag(:div,"You have no incomplete tasks.",:class=>'alert alert-success')
    else
      by_due = {}
      tasks.each do |t|
        due_label = due_at_label(t)
        by_due[due_label] ||= []
        by_due[due_label] << t
      end
      r = grouped_tasks(by_due) {|due_at| due_at}
    end
    r
  end

  private
  def task_tab_pane tasks, anchor, active=false
    c = generic_tab_task_pane(task_collection_to_widgets(tasks.sort_by {|x| x.passed_at || 1000.years.ago}).join.html_safe, anchor, active)
    [c,open_count(tasks)]
  end

  def grouped_tasks task_hash, opts={}
    total_open_count = 0
    coll = []
    label_hash = {}
    task_hash.keys.each {|hash_key| label_hash[yield(hash_key)] = hash_key}
    label_hash.keys.sort.each do |label|
      k = label_hash[label]
      tasks = task_hash[k]
      total_open_count += open_count(tasks)
      collapse_anchor = "wrkflw-panel-body-#{k.to_s.gsub(/\W/,'')}"
      coll << content_tag(:div,:class=>'panel panel-default') do
        heading = content_tag(:div,:class=>'panel-heading') do
          content_tag(:h4,:class=>'panel-title') do
            (content_tag(:span,tasks.count.to_s,'class'=>'label label-default pull-right') + ' ' + content_tag(:a,label,:href=>"##{collapse_anchor}",'data-toggle'=>'collapse')).html_safe
          end
        end
        body = content_tag(:div,content_tag(:div,task_collection_to_widgets(tasks,opts).join.html_safe,:class=>'panel-body'),'id'=>collapse_anchor,'class'=>'panel-collapse collapse')
        (heading + body).html_safe
      end
    end
    coll.join.html_safe
  end
  def grouped_task_tab_pane task_hash, anchor, opts={}
    [generic_tab_task_pane(content_tag(:div,gouped_tasks(task_hash,opts),:class=>'panel-group'), anchor, opts[:active]),total_open_count]
  end

  def task_group_label base_object
    cm = base_object.core_module
    label = "#{cm.label}: #{ModelField.find_by_uid(cm.default_search_columns.first).process_export(base_object,nil,true)}"
  end

  def generic_tab_task_pane content, anchor, active
    content_tag(:div,content.html_safe,:role=>'tabpanel',:class=>"tab-pane workflow-pane #{active ? 'active' : ''}",:id=>anchor).html_safe
  end

  def open_count tasks
    tasks.inject(0) { |mem, t| mem + (t.passed? ? 0 : 1) }
  end

  def task_collection_to_widgets tasks, opts={}
    tab_tasks = []
    tasks.each {|wt| tab_tasks << task_widget(wt,opts)}
    tab_tasks
  end

  def summary_tab base_object
    tasks = base_object.workflow_instances.collect {|wi| wi.workflow_tasks.to_a}.flatten
    task_tab_pane tasks, 'wf-summary', true
  end

  def my_tasks_tab base_object
    tasks = WorkflowTask.for_user(current_user).for_base_object(base_object)
    task_tab_pane tasks, 'wf-my-tasks'
  end

  def task_tab title, open_count, anchor, opts={}
    inner_opts = {label_type:'default'}.merge(opts)
    open_count_label = (!open_count.nil? && open_count > 0) ? content_tag(:span,open_count.to_s,:class=>"label label-#{inner_opts[:label_type]}") : ''
    content_tag(:li,content_tag(:a,"#{sanitize title} #{open_count_label}".html_safe,'href'=>"##{anchor}",'aria-controls'=>anchor,'role'=>'tab','data-toggle'=>'tab'),'role'=>'presentation','class'=>"#{inner_opts[:active] ? 'active' : ''}")
  end

  def task_widget task, opts={}
    inner_left = content_tag(:span,'',:class=>"glyphicon #{task_glyphicon(task)}") + ' ' + content_tag(:span,(opts[:show_object_label] ? "#{task_group_label(task.base_object)}: " : '')+task.name) + ' ' +
      content_tag(:span,task_assignment_text(task),:class=>'text-muted') + ' ' +
       task_label(task)
    inner = content_tag(:span,inner_left,:class=>'task-widget-left') + content_tag(:span,task_actions(task),:class=>'task-widget-right')
    content_tag(:div,inner,:title=>task_tooltip(task),:class=>"task-widget #{task.passed? ? 'text-muted' : ''} clearfix",'task-id'=>task.id.to_s)
  end

  def task_assignment_text task
    r = task.group.name.upcase
    if task.assigned_to
      r << " (#{task.assigned_to.full_name})"
    end
    r
  end

  def task_label task
    if task.passed?
      return content_tag(:span,'','rel-date'=>task.passed_at.getutc.iso8601,'rel-date-prefix'=>'done ',:class=>"label label-default",:title=>task.passed_at)
    else
      return task.due_at ? content_tag(:span,'','rel-date'=>task.due_at.getutc.iso8601,:class=>"label label-#{task.overdue? ? 'danger' : 'default'}",'rel-date-prefix'=>'due ',:title=>task.due_at) : ''
    end
  end

  def task_tooltip task
    case task.test_class_name
    when /MultiStateWorkflowTest$/
      return task.can_edit?(current_user) ? "Click button to select option" : "You don't have permission to update this task."
    when /AttachmentTypeWorkflowTest$/
      return "Upload an attachment of type #{task.payload['attachment_type']}"
    when /ModelFieldWorkflowTest$/
      fields = task.payload['model_fields'].collect {|mf_h| ModelField.find_by_uid(mf_h['uid']).label}.join(', ')
      return "Complete these fields: #{fields}"
    end
    return ''
  end

  def task_glyphicon task
    return 'glyphicon-ok' if task.passed?
    if task.can_edit?(current_user)
      if task.assigned_to == current_user
        return 'glyphicon-user'
      else
        return 'glyphicon-unchecked' 
      end
    end
    return 'glyphicon-blank-circle'
  end

  def task_actions task
    btns = []
    case task.test_class_name
    when /MultiStateWorkflowTest$/
      active_state = task.multi_state_workflow_task ? task.multi_state_workflow_task.state : nil
      can_edit = task.can_edit? current_user
      btns = task.payload['state_options'].collect { |opt|
        opts_hash = {:class=>"btn #{active_state==opt ? 'btn-primary' : 'btn-default'} #{!can_edit ? "disabled" : ''}"}
        if can_edit
          opts_hash['data-wtask-multi-opt'] = opt
          opts_hash['data-wtask-id'] = task.id.to_s
        end
        content_tag(:button,opt,opts_hash)
      }
      btns << link_to_task_object_button(task)
    when /ModelFieldWorkflowTest$/
      btns << link_to('Edit',
        edit_polymorphic_path(task.base_object),:class=>"btn #{task.passed? ? 'btn-default' : 'btn-primary'}"
      )
    else 
      btns << link_to_task_object_button(task)
    end
    if task.can_edit?(current_user)
      btns << assign_button(task)
    end
    return content_tag(:div,btns.join.html_safe,:class=>'btn-group btn-group-sm pull-right') unless btns.blank?
    return ""
  end

  def assign_button task
    content_tag(:button,content_tag(:span,'',:class=>"glyphicon glyphicon-user"),:class=>'btn btn-default dropdown-toggle','data-toggle'=>'dropdown','aria-expanded'=>'false','title'=>'Assign User')+content_tag('ul',assign_list(task),:class=>'dropdown-menu',:role=>'menu')
  end

  def assign_list task
    assignable_users = task.group.users
    return "<li><a href='#'>none</a></li>" if assignable_users.blank?
    user_links = assignable_users.collect do |u|
      assigned_to_user = task.assigned_to==u
      "<li><a href='#' data-wtask-id='#{task.id}' data-assign-workflow-user='#{u.id}' data-assigned='#{assigned_to_user}'><span class='glyphicon glyphicon-#{assigned_to_user ? 'ok' : 'blank-circle'}'></span> #{u.full_name}</a></li>"
    end
    user_links.join.html_safe
  end

  def link_to_task_object_button task
    url = task.view_path.blank? ? polymorphic_path(task.base_object) : task.view_path
    link_to(content_tag(:span,'',:class=>'glyphicon glyphicon-link'),url,:class=>"btn btn-default",:title=>'View')
  end

  def due_at_label task
    task.due_at_label
  end
end