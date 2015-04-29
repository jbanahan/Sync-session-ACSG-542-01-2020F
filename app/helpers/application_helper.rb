require 'open_chain/model_field_renderer/field_helper_support'

module ApplicationHelper
  include ::HeaderHelper
  include ::WorkflowHelper
  include ::OpenChain::ModelFieldRenderer::FieldHelperSupport

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
    mf = get_model_field(model_field_uid)
    if mf.blank? || mf.read_only? || !mf.can_edit?(current_user)
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
    mf = get_model_field(model_field)
    val = mf.process_export object, User.current
    format_for_output(mf, val).html_safe
  end

  #build a select box with all model_fields grouped by module.
  def select_model_fields_tag(name,selected,opts={})
    opts[:class] ||= ''
    opts[:class] << ' form-control'

    inner_opts = {}
    if opts[:filter]
      inner_opts[:filter] = opts.delete :filter
    end

    select_tag name, grouped_options_for_select(CoreModule.grouped_options(User.current, inner_opts),selected,"Select a Field"), opts
  end

  #builds a text field to back a field represented with a model_field_uid in the ModelField constants.
  #will write a select box if the field's validators include a .one_of validation
  def model_text_field form_object, field_name, model_field_uid, opts={}
    inner_opts = opts_for_model_text_field model_field_uid, opts
    mf = ModelField.find_by_uid(model_field_uid)
    if mf.read_only? || !mf.can_edit?(current_user)
      return content_tag(:span,mf.process_export(form_object.object,current_user))
    end
    one_of_array = mf.field_validator_rule.try(:one_of_array)
    if one_of_array&& one_of_array.size > 0
      inner_opts.delete :size
      inner_opts.delete "size"
      return form_object.select(field_name,one_of_array,{:include_blank=>true},inner_opts)
    else
      return form_object.text_field(field_name,inner_opts)
    end
  end

  def model_text_field_tag field_name, model_field_uid, value, opts={}
    inner_opts = opts_for_model_text_field model_field_uid, opts

    model_field = get_model_field(model_field_uid)
    one_of_array = model_field.field_validator_rule.try(:one_of_array)
    if one_of_array && one_of_array.size > 0
      inner_opts.delete :size
      inner_opts.delete "size"
      a = [""]+one_of_array
      select_tag(field_name,options_for_select(a,value),inner_opts)
    else
      text_field_tag(field_name,value,inner_opts)
    end
  end

  def model_text_area_tag field_name, model_field_uid, value, opts={}
    inner_opts = opts_for_model_text_field model_field_uid, opts
    text_area_tag(field_name,value,inner_opts);
  end

  def model_select_field_tag field_name, model_field_uid, value, opts = {}
    inner_opts = opts_for_model_text_field model_field_uid, opts

    option_tags = nil
    if inner_opts[:select_options]
      options = inner_opts.delete :select_options
      if options.respond_to? :call
        option_tags = options.call value
      else
        option_tags = options
      end
    else
      # Create a blank series of selects if no options are provided
      option_tags = options_for_select [["", ""]]
    end

    select_tag(field_name, option_tags, inner_opts)
  end

  def model_hidden_field_tag field_name, model_field_uid, value, opts = {}
    inner_opts = opts_for_model_text_field model_field_uid, opts
    inner_opts.delete :hidden
    hidden_field_tag field_name, value, inner_opts
  end

  def attachment_icon att
    title = "Uploaded: " + att.created_at.to_date.to_s
    title += "<br>Uploaded by: " + att.uploaded_by.full_name if att.uploaded_by && !att.uploaded_by.full_name.blank?
    title += "<br>Archive Title: " + att.attachment_archives.first.name unless att.try(:attachment_archives).try(:first).try(:name).blank?

    opts = {:class=>"attachment_icon",:alt=>att.attached_file_name,:width=>"48px",
            "data-container" => "body", "data-toggle" => "popover", "data-placement" => "top",
            "data-content" => title, "data-trigger" => "hover", "data-delay" => '{"show":"500"}' }
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
  def field_label model_field, show_prefix=nil
    mf = get_model_field(model_field)
    return "" if mf.blank? || !mf.can_view?(User.current)

    render_field_label(mf, show_prefix)
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
    # The custom fields are already cached under the surface for all web requests, so all this is being done to
    # avoid a database call
    cm = CoreModule.find_by_object(customizable)
    cm.model_fields(User.current) {|mf| mf.custom?}.size > 0
  end

  def show_custom_fields(obj, opts={})
    customizable = nil
    form = nil
    if obj.respond_to?(:fields_for)
      customizable = obj.object
      form = obj
    else
      customizable = obj
    end

    # The custom fields are already cached under the surface for all web requests, so all this is being done to
    # avoid a database call
    cm = CoreModule.find_by_object(customizable)
    custom_fields = cm.model_fields(User.current) {|mf| mf.custom?}.values
    custom_fields = CustomValue.sort_by_rank_and_label(custom_fields) unless custom_fields.blank?
    show_model_fields (form ? form : customizable), custom_fields, opts
  end


  def show_model_field core_object, form_object, mf, opts
    output = ""

    user = User.current

    # Don't display model fields that are missing or the user doesn't have permission to view
    # OR if we're not showing read only fields, don't show any fields the user also can't edit
    html_attributes = create_field_html_attributes mf, opts

    add_tooltip_to_html_options(mf,html_attributes)

    hidden = html_attributes[:hidden] === true || opts[:hidden]
    return "" if skip_field?(mf,user,hidden,opts[:display_read_only])
    html_attributes[:hidden] = hidden if html_attributes[:hidden].nil?

    editor = nil
    wrapper = html_attributes.delete :wrap_with

    form_field_name = get_form_field_name(opts[:parent_name],opts[:form],mf)
    if hidden || (opts[:form] && !mf.read_only? && mf.can_edit?(user))
      if !hidden && block_given?
        editor = yield mf, form_field_name, mf.process_export(core_object, user), html_attributes
      end
      editor = model_field_editor(user, core_object, mf, form_field_name, html_attributes).html_safe if editor.nil?
    else
      if block_given?
        editor = yield mf, form_field_name, mf.process_export(core_object, user), html_attributes
      end
      editor = field_value(core_object, mf).html_safe if editor.nil?
    end

    # At the moment, we only hide custom fields..not standard ones..use hide_blank to hide blank standard fields
    return "" if (opts[:hide_blank] == true || html_attributes[:hide_blank] == true || mf.custom?) && !(opts[:never_hide] == true || html_attributes[:never_hide] == true) && editor.blank?

    if wrapper && wrapper.respond_to?(:call)
      editor = wrapper.call(mf, editor)
    end

    label = ""
    label = render_field_label(mf,opts[:show_prefix]) unless opts[:editor_only]


    if opts[:editor_only] || hidden
      if opts[:table]
        attrs = {}
        attrs[:class] = "has_numeric" if [:decimal,:integer].include?(mf.data_type)
        output << content_tag(:td, editor, attrs)
      else
        output << editor
      end

    elsif opts[:table]
      output << field_row(label, editor, (opts[:never_hide] || html_attributes[:never_hide]), mf)
    else
      output << field_bootstrap(label, editor)
    end

    output
  end
  def show_model_fields(obj, model_field_uids, opts = {})

    core_object, form_object = get_core_and_form_objects(obj)

    opts = {:form=>form_object, :table=>false, :show_prefix=>false, :never_hide=>false, :display_read_only=>true}.merge(opts)

    output = ""
    for_model_fields(model_field_uids) do |mf|
      output << show_model_field(core_object, form_object, mf, opts)
    end

    if output.blank?
      return ""
    else
      output = output.html_safe
      return (opts[:table] || opts[:editor_only] || opts[:hidden]) ? output : content_tag(:div, output, :class=>'model_field_box')
    end
  end

  def create_field_html_attributes model_field, opts
    html_attributes = {}
    if opts[:attributes]
      html_attributes = opts[:attributes] ? {}.merge(opts[:attributes]) : {}
      # This is mostly just to shift the class attribute into an array (which rails handles)
      html_attributes[:class] = merge_css_attributes nil, html_attributes[:class]
    else
      html_attributes[:class] = []
    end

    unless (field_specific_opts = opts[model_field.uid.to_sym]).nil?
      f_opts = field_specific_opts.deep_dup
      css_class = f_opts.delete :class
      html_attributes[:class] = merge_css_attributes(html_attributes[:class], css_class) unless css_class.blank?

      html_attributes.merge! f_opts
    end

    type_class = data_type_class(model_field)
    html_attributes[:class] << type_class unless type_class.blank?
    html_attributes[:wrap_with] = opts[:wrap_with] if html_attributes[:wrap_with].nil?

    html_attributes
  end

  def model_field_editor user, core_object, model_field, form_field_name, html_attributes
    # We're going to assume that hidden attributes can be allowed to be written to the page
    # regardless of whether the user has permission to see / not see the value.
    # This should really exclusively be used for writing id values into the page anyway, so even
    # if the user does see the values, it's not a problem.
    if html_attributes[:hidden] === true
      value = model_field.process_export core_object, user, true
      return model_hidden_field_tag(form_field_name, model_field, value, html_attributes)
    end

    field = nil
    c_val = model_field.process_export(core_object, user)

    case model_field.data_type
    when :boolean
      # The cv_chkbx tag is monitored by a jquery expression and copies the state of the check into the hidden field (which is what is read on form submission)
      html_attributes[:class] << "cv_chkbx"
      chb_field_name = form_field_name.gsub(/[\[\]*]/, '_')
      html_attributes[:id] = "cbx_"+chb_field_name
      field = hidden_field_tag(form_field_name,c_val,:id=>"hdn_"+chb_field_name) + check_box_tag('ignore_me', "1", c_val, html_attributes)
    when :text
      html_attributes[:rows] = 5 unless html_attributes[:rows]
      field = model_text_area_tag(form_field_name, model_field, c_val, html_attributes)
    else
      if html_attributes[:select_options]
        field = model_select_field_tag(form_field_name, model_field, c_val, html_attributes)
      else
        html_attributes[:size] = 30 unless html_attributes[:size]
        field = model_text_field_tag(form_field_name, model_field, c_val, html_attributes)
      end
    end

    field
  end
  private :model_field_editor

  def model_field_labels(model_field_uids, opts={})
    if !model_field_uids.respond_to? :each
      model_field_uids = [model_field_uids]
    end

    output = ""
    opts = {attributes: {}, heading: false, show_prefix: false, table: false, row: false}.merge opts
    model_field_uids.each do |mf|
      field = field_label(mf, opts[:show_prefix])
      next if field.blank?

      if opts[:table]
        field = content_tag((opts[:heading] ? :th : :td), field.html_safe, opts[:attributes])

        if opts[:row]
          field = content_tag(:tr, field.html_safe)
        end
      end

      output << field
    end

    output.html_safe
  end

  # render <tr> with field content
  def field_row(label, field, never_hide=false, model_field=nil)
    model_field = get_model_field(model_field)
    td_label = content_tag(:td, label.blank? ? "" : label+": ", :class => 'label_cell')
    is_numeric = model_field && [:decimal,:integer].include?(model_field.data_type) && field && !field.to_s.match(/[a-zA-Z\s]/)
    td_content = content_tag(:td, field, :style=>"#{is_numeric ? "text-align:right;" : ""}")
    content_tag(:tr, td_label+td_content, :class=>"hover field_row #{never_hide ? "neverhide" : ""}")
  end

  # render bootstrap friendly field content
  def field_bootstrap label, field, never_hide=false, model_field=nil
    return '' if !never_hide && field.blank?
    field_content = field
    model_field = get_model_field(model_field)
    if model_field && model_field.data_type==:text
      field = field.gsub(/(:?\r\n)|(:?\r)|(:?\n)/, "<br>").html_safe
      field_content = content_tag(:span,field,:class=>'pre-ish')
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

  def model_field_label(model_field_uid, always_view = false)
    mf = get_model_field(model_field_uid)
    (always_view || mf.can_view?(User.current)) ? mf.label : ""
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

  def show_tariff_hts_model_field core_object, model_field, country_id, with_popup_link=true
    value = field_value(core_object, model_field)
    return "" if value.blank?

    if with_popup_link
      content_tag :span, (value + " " + tariff_more_info(value,country_id).html_safe)
    else
      value
    end
  end

  def show_tariff_schedule_b_model_field core_object, model_field, with_popup_link=true
     value = field_value(core_object, model_field)
    return "" if value.blank?

    if with_popup_link
      content_tag :span, (value + " " + schedule_b_more_info(value).html_safe)
    else
      value
    end
  end

  def tariff_more_info hts_number, country_id
    link_to "info", "#", {:class=>'lnk_tariff_popup btn btn-xs btn-default',:hts=>hts_number,:country=>country_id}
  end

  def schedule_b_more_info hts_number
    link_to "info", "#", {:class=>'lnk_schedb_popup btn btn-xs btn-default',:schedb=>hts_number}
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
    mf = get_model_field(model_field_uid)
    show_field = mf.can_view? User.current
    if show_field && !mf.entity_type_field? && object.respond_to?('entity_type_id')
      e_id = object.entity_type_id
      ids = mf.entity_type_ids
      show_field = false if !e_id.nil? && !ids.include?(e_id)
    end

    show_field ? render_lambda.call(field_label(mf,show_prefix),  field_value(object,mf),false,mf) : ""
  end

   # Given a model field and a value, render an output formatted, html-safe representation of the value
  def format_for_output model_field, val
    if val
      if model_field.currency
        case model_field.currency
        when :usd
          val = number_to_currency val
        else
          val = number_to_currency val, {:format=>"%n",:negative_format=>"-%n"}
        end
      elsif model_field.data_type == :decimal
        # Using precision 5 since that'll cover pretty much every decimal field in the system.
        val = number_with_precision val, :precision => 5, :strip_insignificant_zeros => true
      elsif model_field.custom_definition && model_field.custom_definition.is_user?
        u = User.find_by_id(val)
        val = u.full_name if u
      end
    end
    html_escape val
  end

  def opts_for_model_text_field model_field_uid, opts

    mf = get_model_field(model_field_uid)
    inner_opts = {mf_id: mf.uid.to_s}.merge opts
    inner_opts[:class] = ["form-control"]
    inner_opts[:class].push *val_class(mf)
    inner_opts[:class] = merge_css_attributes inner_opts[:class], opts[:class]

    inner_opts
  end

  def val_class model_field_uid
    mf = get_model_field(model_field_uid)
    #returns the string "rvalidate" if the field needs remote validation
    r = []
    r << "rvalidate" unless mf.field_validator_rule.nil?

    case mf.data_type
    when :decimal
      r << "decimal"
    when :integer
      r << "integer"
    when :date
      r << "isdate"
    when :datetime
      r << "isdate"
    when :fixnum
      r << "decimal"
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
      return "isdate"
    when :datetime
      return "isdate"
    when :integer
      return "integer"
    when :decimal, :fixnum
      return "decimal"
    else
      return nil
    end
  end

  def render_field_label mf, show_prefix = false
    content_tag(:span,mf.label(show_prefix),{:class=>"fld_lbl",:entity_type_ids=>entity_type_ids(mf)})
  end

  def merge_css_attributes a, b
    a = a.is_a?(String) ? [a] : a
    b = b.is_a?(String) ? [b] : b

    ((a.nil? ? [] : a) + (b.nil? ? [] : b)).uniq.compact
  end

  def favicon_links
    # Icons + raw html generated using http://realfavicongenerator.net/

    # We should probably do some browser sniffing to eliminate sending browser specific tags that aren't
    # meant for the current request's browser.
    tags = []
    tags << tag('link', rel: "apple-touch-icon", sizes:"57x57", href: path_to_image("apple-touch-icon-57x57.png"))
    tags << tag('link', rel: "apple-touch-icon", sizes:"60x60", href: path_to_image("apple-touch-icon-60x60.png"))
    tags << tag('link', rel: "apple-touch-icon", sizes:"57x57", href: path_to_image("apple-touch-icon-72x72.png"))
    tags << tag('link', rel: "apple-touch-icon", sizes:"72x72", href: path_to_image("apple-touch-icon-76x76.png"))
    tags << tag('link', rel: "apple-touch-icon", sizes:"76x76", href: path_to_image("apple-touch-icon-114x114.png"))
    tags << tag('link', rel: "apple-touch-icon", sizes:"114x114", href: path_to_image("apple-touch-icon-120x120.png"))
    tags << tag('link', rel: "apple-touch-icon", sizes:"120x120", href: path_to_image("apple-touch-icon-144x144.png"))
    tags << tag('link', rel: "apple-touch-icon", sizes:"152x152", href: path_to_image("apple-touch-icon-152x152.png"))
    tags << tag('link', rel: "apple-touch-icon", sizes:"180x180", href: path_to_image("apple-touch-icon-180x180.png"))
    tags << tag('link', rel: "icon", type:"image/png", href: path_to_image("favicon-32x32.png"), sizes:"32x32")
    tags << tag('link', rel: "icon", type:"image/png", href: path_to_image("favicon-194x194.png"), sizes:"194x194")
    tags << tag('link', rel: "icon", type:"image/png", href: path_to_image("favicon-96x96.png"), sizes:"96x96")
    tags << tag('link', rel: "icon", type:"image/png", href: path_to_image("android-chrome-192x192.png"), sizes:"192x192")
    tags << tag('link', rel: "icon", type:"image/png", href: path_to_image("favicon-16x16.png"), sizes:"16x16")
    # The date in the ico name is to force IE to update the icon image..otherwise if the user has the old favicon.ico
    # loaded, IE will not check for a new one.  The only other alternative is having the users clear their browsing history.
    tags << tag('link', rel: "shortcut icon", href: path_to_image("favicon.ico"))
    tags << tag('meta', name: "msapplication-TileColor", content: "#2b5797")
    tags << tag('meta', name: "msapplication-TileImage", content: path_to_image("mstile-144x144.png"))
    tags << tag('meta', name: "theme-color", content: "#ffffff")

    tags.join("\n").html_safe
  end
end
