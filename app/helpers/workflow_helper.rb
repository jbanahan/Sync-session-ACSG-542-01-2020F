module WorkflowHelper
  include ActionView::Helpers::SanitizeHelper
  include ActionDispatch::Routing::UrlFor

  def task_panel base_object
    h = Hash.new
    anchors = Hash.new
    base_object.workflow_instances.each do |wi|
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

  def my_task_panel
    r = content_tag(:div,"You have no incomplete tasks.",:class=>'alert alert-success')
    tasks = WorkflowTask.for_user(current_user).not_passed.order('workflow_tasks.due_at DESC').to_a
    if tasks.size > 0
      by_base_object_hash = {}
      by_due_at_hash = {}
      tasks.each do |t|
        base_object = t.base_object
        due_label = due_at_label(t)
        by_due_at_hash[due_label] ||= []
        by_due_at_hash[due_label] << t
        by_base_object_hash[base_object] ||= []
        by_base_object_hash[base_object] << t
      end
      by_base_object_pane, by_base_object_count = 
      task_tabs = [
        task_tab('By Page',nil,'wf-my-tasks',{active:true}),
        task_tab('By Due Date',nil,'wf-my-due')
      ]
      task_panes = [
        grouped_task_tab_pane(by_base_object_hash, 'wf-my-tasks', {active:true}) {|base_object| task_group_label(base_object)}.first,
        grouped_task_tab_pane(by_due_at_hash,'wf-my-due',{show_object_label:true}) {|due_at| due_at}.first
      ]
      tab_list = content_tag(:ul,task_tabs.join.html_safe,:class=>'nav nav-tabs',:role=>'tablist')
      tab_content = content_tag(:div,task_panes.join.html_safe,:class=>'tab-content')
      r = content_tag(:div,tab_list+tab_content,:role=>'tabpanel')
    end
    r
  end

  private
  def task_tab_pane tasks, anchor, active=false
    c = generic_tab_task_pane(task_collection_to_widgets(tasks.sort_by {|x| x.passed_at || 1000.years.ago}).join.html_safe, anchor, active)
    [c,open_count(tasks)]
  end

  def grouped_task_tab_pane task_hash, anchor, opts={}
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
    [generic_tab_task_pane(content_tag(:div,coll.join.html_safe,:class=>'panel-group'), anchor, opts[:active]),total_open_count]
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
      content_tag(:span,task.group.name.upcase,:class=>'text-muted') + ' ' +
       task_label(task)
    inner = content_tag(:span,inner_left,:class=>'task-widget-left') + content_tag(:span,task_actions(task),:class=>'task-widget-right')
    content_tag(:div,inner,:title=>task_tooltip(task),:class=>"task-widget #{task.passed? ? 'text-muted' : ''} clearfix",'task-id'=>task.id.to_s)
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
    return 'glyphicon-user' if task.can_edit?(current_user)
    return 'glyphicon-minus'
  end

  def task_actions task
    inner_content = nil
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
      inner_content = btns.join.html_safe 
    when /ModelFieldWorkflowTest$/
      inner_content = link_to('Edit',
        edit_polymorphic_path(task.base_object),:class=>"btn #{task.passed? ? 'btn-default' : 'btn-primary'}"
      )
    else 
      inner_content = link_to_task_object_button(task,true)
    end
    return content_tag(:div,inner_content,:class=>'btn-group btn-group-sm pull-right') unless inner_content.blank?
    return ""
  end

  def link_to_task_object_button task, primary = false
    url = task.view_path.blank? ? polymorphic_path(task.base_object) : task.view_path
    link_to('View',url,:class=>"btn #{!task.passed? && primary ? 'btn-primary' : 'btn-default'}")
  end

  def due_at_label task
    task.due_at_label
  end
end