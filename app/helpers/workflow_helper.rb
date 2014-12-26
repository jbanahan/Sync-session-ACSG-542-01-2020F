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

  private
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
    open_count_label = open_count > 0 ? content_tag(:span,open_count.to_s,:class=>"label label-#{inner_opts[:label_type]}") : ''
    content_tag(:li,content_tag(:a,"#{sanitize title} #{open_count_label}".html_safe,'href'=>"##{anchor}",'aria-controls'=>anchor,'role'=>'tab','data-toggle'=>'tab'),'role'=>'presentation','class'=>"#{inner_opts[:active] ? 'active' : ''}")
  end

  def task_tab_pane tasks, anchor, active=false
    #tab content
    tab_tasks = []
    tasks.sort_by {|x| x.passed_at || 1000.years.ago}.each do |wt|
      tab_tasks << task_widget(wt)
    end

    content = content_tag(:div,tab_tasks.join.html_safe,:role=>'tabpanel',:class=>"tab-pane workflow-pane #{active ? 'active' : ''}",:id=>anchor).html_safe
    open_count = tasks.inject(0) { |mem, t| mem + (t.passed? ? 0 : 1) }
    [content,open_count]
  end

  def task_widget task
    inner = content_tag(:span,'',:class=>"glyphicon #{task_glyphicon(task)}") + ' ' + content_tag(:span,task.name) + ' ' +
      content_tag(:span,task.group.name.upcase,:class=>'text-muted') + ' ' +
      task_actions(task)
    content_tag(:div,inner,:title=>task_tooltip(task),:class=>"task-widget #{task.passed? ? 'text-muted' : ''} clearfix")
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
      inner_content = btns.join.html_safe unless btns.empty?
    when /ModelFieldWorkflowTest$/
      inner_content = link_to('Edit',
        edit_polymorphic_path(task.base_object),:class=>"btn #{task.passed? ? 'btn-default' : 'btn-primary'}"
      )
    end
    return content_tag(:div,inner_content,:class=>'btn-group btn-group-sm pull-right') unless inner_content.blank?
    return ""
  end
end