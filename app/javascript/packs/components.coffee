@components = angular.module 'ChainComponents', ['angucomplete-alt']

# Add this to your controller to get HTTP errors handled for you.
# It's errorMessage property will be auto populated with any errors from the chainHttpErrorInterceptor
# You can optionally set the responseErrorHandler to a function that takes the rejection object from the http response and does something special with it.  (See ShipmentCtrl for an implementation example)
@components.service 'chainErrorHandler', ->
  {
    errorMessage: null
    clear: ->
      @.errorMessage = null
    responseErrorHandler: null
  }

# listens for HTTP errors and passes them to the chainErrorHandler which should be added to you controller
@components.factory 'chainHttpErrorInterceptor', ['$q','chainErrorHandler',($q,chainErrorHandler) ->
  {
    error: null
    responseError: (rejection) ->
      em = "Server error."
      data = rejection.data
      if data.errors
        em = data.errors.join('<br />')
      chainErrorHandler.errorMessage = (em)
      if chainErrorHandler.responseErrorHandler
        chainErrorHandler.responseErrorHandler(rejection)
      $q.reject(rejection)
  }
]

# Make a bootstrap panel with view content and button to edit w/ modal
#
# view-template = url of template for view content
# edit-if = show the edit button if true
# edit-template = url of modal content
# panel-title = title of view panel
# before-edit = method called before modal is displayed
# on-save = method called when save is clicked on modal
# panel-class = class for panel (panel-default, panel-primary, etc)
@components.directive 'chainViewEdit', ->
  {
    restrict: 'E'
    scope: {
      viewTemplate: '@'
      editTemplate: '@'
      panelTitle: '@'
      panelClass: '@'
      editIf: '='
      beforeEdit: '&'
      onSave: '&'
      modalClass: '@'
    }
    templateUrl: '/partials/components/chain_view_edit.html'
    link: (scope,el,attrs) ->
      scope.outerScope = scope.$parent
      jqEl = $(el)
      jqEl.find('.chain-edit-btn').click ->
        scope.$apply ->
          scope.beforeEdit() if scope.beforeEdit
          scope.$broadcast('chain:view-edit:open')
        jqEl.find('[chain-view-edit-modal]:first').modal('show')
      jqEl.find('.chain-save-btn').click ->
        scope.$apply ->
          scope.onSave() if scope.onSave
          scope.$broadcast('chain:view-edit:save')
        jqEl.find('[chain-view-edit-modal]:first').modal('hide')
  }

# Transcludes it's content in a wrapper that hides the content and replaces it with a loading message
# whenever the loading-flag property is set to "loading"
@components.directive 'chainLoadingWrapper', ->
  {
    restrict: 'E'
    scope: {
      loadingFlag: '@'
    }
    transclude: true
    templateUrl: '/partials/components/loading.html'
  }

@components.directive 'focusWhen', ['$timeout','$parse', ($timeout, $parse) ->
  {
    link: (scope, element, attrs) ->
      model = $parse(attrs.focusWhen)
      scope.$watch model, (value) ->
        if value == true
          $timeout ->
            element[0].focus()
            element[0].scrollIntoView()
      element.bind 'blur', ->
         scope.$apply(model.assign(scope, false))
  }
]

#Boolean filter for writing text, works similar to a ternary operator like:
# <div>{{x==1 | ifTrue : "I'm True" : "I'm not true"}}
@components.filter 'ifTrue', ->
  (input,tVal,fVal) ->
    if input then tVal else fVal

@components.filter 'chainSkipReadOnlyFields', [ ->
  (fields) ->
    return [] unless fields && fields.length > 0
    $.grep(fields,(fld) ->
      return (if fld.read_only==true then null else fld)
    )
]

@components.filter 'chainViewFriendlyFields', [ ->
  (fields) ->
    return [] unless fields && fields.length > 0
    $.grep fields, (fld) ->
      return null if fld.user_id_field
      return null if fld.user_field && !fld.user_full_name_field
      return fld
]

@components.directive 'chainTextileView', [ ->
  {
    restrict: 'AE'
    scope: {
      ngModel: '='
    }
    template: "<div class='textile-view'></div>"
    link: (scope,el,attrs) ->
      if scope.ngModel && scope.ngModel.length > 0
        $(el).html(textile.convert(scope.ngModel))
      else
        $(el).html('')
    }
]


@components.directive 'chainTextileEdit', [ ->
  {
    restrict: 'AE'
    scope: {
      ngModel: '='
      defaultView: '@'
    }
    template: "<div>
      <div ng-show='showPreview' class='text-prev'>
      </div>
      <div ng-hide='showPreview'>
        <textarea class='form-control' ng-model='ngModel'></textarea>
      </div>
      <div class='text-right'>
        <div ng-hide='showPreview'><a class='btn btn-sm' href='' ng-click='togglePreview()'>preview</a></div>
        <div ng-show='showPreview'><a class='btn btn-sm' href='' ng-click='togglePreview()'>close preview</a></div>
      </div>
    </div>"
    link: (scope,el,attrs) ->
      scope.showPreview = scope.defaultView == 'preview'
      scope.togglePreview = ->
        scope.showPreview = !scope.showPreview
      scope.$watch 'ngModel', (newVal,oldVal) ->
        $(el).find('div.text-prev').html(textile.convert(newVal))
      this
  }
]

# creates a bootstrap panel like:
# <chain-panel panel-title='Errors' panel-message="obj.error_message" panel-type='panel-danger' />
#
# auto hides / shows if message is set
@components.directive 'chainPanel', [ ->
  {
    restrict: 'AE'
    scope: {
      panelTitle: '@'
      panelMessage: '='
      panelType: '@'
    }
    template: "<div ng-show='panelMessage && panelMessage.length>0'><div class='card' ng-class='panelType'><div class='card-header'>{{panelTitle}}</div><div class='card-body'><p ng-bind-html='panelMessage'></p></div></div></div>"
    link: (scope,el,attrs) ->
      this
  }
]
# based on: http://coding-issues.blogspot.in/2013/10/angularjs-blur-directive.html
# should be able to remove this when we upgrade to a newer angularjs version that supports this natively
@components.directive('ngBlur', ['$parse', ($parse) ->
  (scope, element, attr) ->
    fn = $parse(attr['ngBlur'])
    element.bind 'blur', (event) ->
      scope.$apply ->
        fn(scope, {$event: event})
])

# Shows the message from the given binding in a modal every time it changes.
# Closes the modal if the message is changed to blank, nil or undefined
# The title attribute becomes the modal header title
@components.directive 'chainModalMessage', ['$timeout',($timeout) ->
  {
    scope: {
      messageObject: '='
      messageProperty: '@'
      clearOnClose: '='
    }
    template: "<div class='modal fade'><div class='modal-dialog'><div class='modal-content'><div class='modal-header'><button type='button' class='close' data-dismiss='modal' aria-hidden='true'>&times;</button><h3>{{title}}</h3></div>
      <div class='modal-body'><p>{{message()}}</p></div>
      <div class='modal-footer'><button class='btn btn-secondary' data-dismiss='modal' aria-hidden='true'>Close</button></div>
      </div></div></div>"
    link: (scope,el,attrs) ->
      scope.title = attrs.title

      scope.message = ->
        scope.messageObject[scope.messageProperty]

      if scope.clearOnClose
        el.find('.modal').on 'hide.bs.modal', ->
          $timeout -> #prevents $digest already in progress error while also making sure $apply is called
            scope.messageObject[scope.messageProperty] = ''

      scope.$watch 'messageObject[messageProperty]', (newVal,oldVal) ->
        if newVal && newVal.length > 0
          el.find('.modal').modal('show')
        else
          el.find('.modal').modal('hide')
      this
  }
]
# Full action bar replacement that loads up the action bar with the transcluded content.
# Use in conjunction with the @no_action_bar = true option in the rails controller which will hide the normal action bar in the layout
@components.directive 'chainActionBar', [ ->
  {
    transclude: true
    template: "<div id='action_bar' ng-show='!noChrome' class='navbar fixed-bottom'><ul class='nav navbar-nav'><li id='nav-action-bar'><span ng-transclude></span></li></ul></div>"
    replace: true
    link: (scope,el,attrs) ->
      scope.$evalAsync ->
        el.find('button').addClass('navbar-btn')
      this
  }
]

# file upload form based on: http://hayageek.com/ajax-file-upload-jquery/
# requires: jquery.form.js
@components.directive 'chainAttach', [ ->
  {
    restrict: 'A'
    scope: {
      chainAttach: '='
      attachableId: '@'
      attachableType: '@'
    }
    template: "<form class='form-inline' role='form' action='/attachments' method='post' enctype='multipart/form-data'>
      <div class='row'>
        <div class='col-4'>
          <input type='hidden' name='attachment[attachable_type]' value='{{attachableType}}' />
          <input type='hidden' name='attachment[attachable_id]' value='{{attachableId}}' />
          <input type='file' size='60' name='attachment[attached]' class='form-control' />
        </div>
      </div>
      <div class='row'>
        <div class='col-2' style='margin-top: 5px'>
          <input type='submit' value='Upload' class='btn btn-sm btn-success' style='display:none;'>
        </div>
      </div>
    </form>
    <div class='progress progress-striped active'>
      <div class='progress-bar' role='progress-bar'>
        <span class='sr-only'>Uploading</span>
      </div>
    </div>
    <div class='att-msg'></div>
      "
    link: (scope,el,attrs) ->
      el.find('div.progress').hide()
      fileEl = el.find('form input[type="file"]')
      fileEl.on('change', ->
        if $(this).val()
          el.find('form input[type="submit"]').show()
        else
          el.find('form input[type="submit"]').hide()
      )
      options = {
        dataType: 'json'
        beforeSend: ->
          if el.find('form input[type="file"]').val()
            el.find('form').hide()
            el.children('div.progress').show()
            #clear everything
            el.find('div.progress div.progress-bar').width('0%')
            el.find('div.att-msg').html('Upload starting')
            el.find('div.progress').show()
          else
            el.find('div.att-msg').html('You must select a file to upload.')
        uploadProgress: (event, position, total, percentComplete) ->
          el.find('div.progress div.progress-bar').width(percentComplete+"%")
          if percentComplete == 100
            el.find('div.att-msg').html("Processing Upload")
          else
            el.find('div.att-msg').html(percentComplete+'% Uploaded')
        success: (data) ->
          el.find('div.att-msg').html('')
          el.find('form input[type="file"]').val('')
          el.find('form input[type="submit"]').hide()
          el.find('form').show()
          scope.chainAttach.attachments = data.attachments
          scope.$apply()
        complete: (response) ->
          el.find('div.progress').hide()
        error: (response) ->
          json = response.responseJSON
          message = ""
          if json && json.errors && json.errors.length > 0
            message += error for error in json.errors
          else
            message = 'There was an error uploading this file.'

          message += ' Please reload the page.'
          el.find('div.att-msg').addClass('error').text(message)
      }
      el.find('form').ajaxForm(options)
  }
]


@components.directive 'chainAttachmentPanel', ['$http',($http) ->
  {
    restrict: 'A'
    scope: {
      attachments: "="
      attachable: "="
      attachableType: "@"
      attachableId: "@"
      canAttach: "="
    }
    template: '<div class="card">
        <div class="card-header vandegrift-header">Attachments</div>
        <div class="card-body"
          <ul class="list-group">
            <li ng-repeat="att in attachments" class="list-group-item">
              <button class="btn btn-sm btn-danger float-right" ng-click="deleteAttachment(att.id)" href="javascript:;" ng-if="canAttach"><i class="fa fa-trash"></i></button>
              <a href="/attachments/{{att.id}}/download" target="_blank">{{att.name}} <span class="badge">{{att.size}}</span></a>
            </li>
          </ul>
        </div>
        <div class="card-footer" ng-if="canAttach">
          <div chain-attach="attachable" attachable-type="{{attachableType}}" attachable-id="{{attachableId}}"></div>
        </div>'

    controller: ['$scope',($scope) ->
      $scope.deleteAttachment = (attId) ->
        if window.confirm("Are you sure you want to delete this attachment?")
          $http.delete("/api/v1/" + $scope.attachableType+"/" + $scope.attachableId + "/attachment/" + attId + ".json").then(((resp) ->
              attachments = (attachment for attachment in $scope.attachments when attachment.id != attId)
              $scope.attachments = attachments
            ), ((resp) ->
              window.alert("Failed to delete this attachment.")
            )
          )
    ]
  }
]


@components.directive 'chainActionButton', ['$parse',($parse) ->
  {
    restrict: 'A'
    link: (scope,el,attrs) ->
      bId = el.attr('id')
      newButton = $('#nav-action-bar #chain-action-button-'+bId)
      if newButton.length == 0
        el.hide()
        actionBar = $('#nav-action-bar')
        actionBar.append("<button class='btn btn-secondary' id='chain-action-button-"+bId+"'>"+el.html()+"</button>")
        newButton = actionBar.find('#chain-action-button-'+bId)
        newButton.on('click', ->
          $('#'+bId).click()
        )

      if attrs.chainShow
        scope.$watch $parse(attrs.chainShow)(scope), (newVal,oldVal) ->
          if newVal
            newButton.show()
          else
            newButton.hide()
  }
]
# moves the transcluded content into the action bar
# each instance must have a unique ID attribute
@components.directive 'chainActionBarItem', [ ->
  {
    transclude: true
    template: "<div class='chainActionBarWrap' style='display:inline;' ng-transclude></div>"
    link: (scope,el,attrs) ->
      d = el.find('div.chainActionBarWrap')
      d.attr('action-bar-item-id',el.attr('id'))
      existingEl = $('#nav-action-bar div.chainActionBarWrap[action-bar-item-id="'+el.attr('id')+'"]')
      existingEl.remove()
      $("#nav-action-bar").append(d)
      d.find('button').button()
    }
]

# creates a modal dialog box with a link based on the title attributes and transcludes the content into the body of the dialog.  There will be an "OK" button to close the dialog.
@components.directive 'chainMessageBox', [ ->
  {
    scope: {
      title: '=title'
      asButton: '=asButton'
      extraClass: '=extraClass'
      buttonIconClass: '@buttonIconClass'
    }
    transclude: true
    template: "<div class='dialog_content_wrap' ng-transclude></div>"
    link: (scope,el,attrs) ->
      if scope.asButton
        buttonContent = scope.title
        if scope.buttonIconClass
          buttonContent = "<i class='"+scope.buttonIconClass+"'></i>"
        el.prepend("<button class='btn chainMessageBoxLauncher "+scope.extraClass+"' title='"+scope.title+"'>"+buttonContent+"</button>")
      else
        el.prepend("<a class='btn chainMessageBoxLauncher "+scope.extraClass+"'>"+scope.title+'</a>')
      d = el.find("div.dialog_content_wrap")
      d.dialog({
        modal: true
        autoOpen: false
        buttons: {
          "OK": ->
            $(this).dialog('close')
          }
        }
      )
      el.find(".chainMessageBoxLauncher").click(->
        d.dialog('open')
      )

      scope.$on('$destroy', ->
        el.find(".chainMessageBoxLauncher").off('click')
        d.dialog('destroy')
        d.html("")
        el = null
        d = null
      )
    }
]

@components.directive 'chainFieldView', ['$compile', ($compile) ->
  {
    restrict: 'E'
    scope: {
      model: '='
      field: '='
    }
    template: ""
    link: (scope, el, attrs) ->
      getHtml = (scope) ->
        if !scope.field or !scope.model
          return ''
        val = scope.model[scope.field.uid]
        return '' if (typeof val != 'boolean') && (!val || val.length == 0)

        if scope.field.data_type == 'date'
          return moment(val).format('YYYY-MM-DD')

        if scope.field.data_type == 'datetime'
          return moment(val).format('YYYY-MM-DD HH:mm ZZ')

        if scope.field.data_type == 'text'
          return $compile(angular.element('<pre>'+val+'</pre>'))(scope)

        if scope.field.data_type == 'boolean'
          checkedClass = if val then 'fa-check-square-o' else 'fa-times'
          return $compile(angular.element('<i class="fa '+checkedClass+'" model-field-uid="'+scope.field.uid+'"></i>'))(scope)

        return val

      html = getHtml(scope)
      $(el).html(html)
  }
]

@components.directive 'chainFieldInput', ['$compile','fieldValidatorSvc', ($compile,fieldValidatorSvc) ->
  {
    restrict: 'E'
    scope: {
      model: '='
      field: '='
      inputClass: '@'
    }
    template: "<input type='text' ng-model='model[field.uid]' class='{{inputClass}}' />"
    link: (scope, el, attrs) ->
      jqEl = $(el)
      inp = jqEl.find('input')
      realInput = inp
      if scope.field.select_options
        inp.remove()
        sel = $compile(angular.element('<select ng-model="model[field.uid]" class="{{inputClass}}"></select>'))(scope)
        jqEl.append(sel)
        realInput = sel
        sel.append("<option value=''></option>")
        sel.append("<option value='"+opt[0]+"'>"+opt[1]+"</option>") for opt in scope.field.select_options
      else if scope.field.autocomplete
        url = scope.field.autocomplete.url
        unless inp.is(':data(autocomplete)')
          jqEl.append('<span class="ui-front"></span>')
          jqEl.find('span.ui-front').append(inp)
          inp.autocomplete({
            source:(req,add) ->
              $.getJSON(url+req.term, (data) ->
                r = []
                v = null
                for h in data
                  v = (if scope.field.autocomplete.field then h[scope.field.autocomplete.field] else h)
                  r.push(v)
                add(r)
              )
            select: (event,ui) ->
              scope.$apply ->
               scope.model[scope.field.uid] = ui.item.label

          })
      else if scope.field.data_type=='text'
        inp.remove()
        ta = $compile(angular.element('<textarea ng-model="model[field.uid]" class="{{inputClass}}"></textarea>'))(scope)
        realInput = ta
        jqEl.append(ta)
      else if scope.field.data_type=='boolean'
        inp.remove()
        cb = $compile(angular.element('<div><input type="checkbox" ng-model="model[field.uid]"></div>'))(scope)
        realInput = ta
        jqEl.append(cb)
      else
        inputTypes = {
          number: 'number'
          integer: 'number'
          decimal: 'number'
          date: 'date'
          datetime: 'datetime-local'
        }
        updatedInputType = inputTypes[scope.field.data_type]
        if updatedInputType
          inp.attr('type',updatedInputType)

      if scope.field.remote_validate
        realInput.on 'blur', ->
          scope.$apply ->
            parent = realInput.parent()
            errorBlock = parent.find('.chain-field-input-errmsgs')[0]
            fieldValidatorSvc.validate(scope.field,scope.model[scope.field.uid]).then (resp) ->
              if resp.errors.length > 0
                parent.addClass('has-error')
                if !errorBlock
                  errorBlock = $compile(angular.element('<div class="text-danger text-right chain-field-input-errmsgs"></div>'))(scope)
                  realInput.after(errorBlock)
                $(errorBlock).html(resp.errors.join(' '))
              else
                parent.removeClass('has-error')
                $(errorBlock).html('') if errorBlock
  }
]

@components.directive 'chainHtsInput', ->
  {
    restrict: 'E'
    scope: {
      model: '='
      field: '='
      countryIso: '@'
      inputClass: '@'
    }
    template: "<span class='ui-front'><input type='text' ng-model='model[field.uid]' class='{{inputClass}}' /></span>"
    link: (scope, el, attrs) ->
      jqEl = $(el)
      inp = jqEl.find('input')
      unless inp.is(':data(autocomplete)')
        inp.autocomplete({
          source:(req,add) ->
            $.getJSON('/official_tariffs/auto_complete?country_iso='+scope.countryIso+'&hts='+req.term, (data) ->
              r = []
              v = null
              r.push(h) for h in data
              add(r)
            )
          select: (event,ui) ->
            scope.$apply ->
              scope.model[scope.field.uid] = ui.item.label
        })
  }

@components.service 'userListCache', ['$http',($http) ->
  {
    users: []
    waiting: false
    getListForCurrentUser: (callback) ->
      if @.users.length == 0
        svc = this

        $http.get('/api/v1/users/enabled_users').then( (data) ->
          svc.users = []
          for c in data.data
            cName = c.company.name
            for u in c.company.users
              u.company_name = cName
              svc.users.push u
          callback(svc.users)
        )
      else
        callback(@.users)
  }
]

# shows the user a drop down to select a user and sets the
# selected user id into the passed in object
# <div user-list="myUserIdVariable"></div>
# optionally adding form-control="true" to the div will make the select object have the boostrap friendly form-control class
@components.directive 'chainUserList', ['$parse','$http','userListCache',($parse,$http,userListCache) ->
  {
    scope: {
      chainUserList: "="
    }
    template: "<select ng-model='chainUserList' ng-options='u.id as u.full_name group by u.company_name for u in users'></select>"
    link: (scope,el,attrs) ->
      if $(el).attr('form-control') == 'true'
        $(el).find('select').addClass('form-control')
      userListCache.getListForCurrentUser (users) ->
        scope.users = users
    }
]
@components.directive 'chainMessages', [ ->
  {
    scope: {
      errors: "=",
      notices: "="
    }
    templateUrl: "html/chain_messages.html"
    }
]
@components.directive 'chainDatePicker', [ ->
  {
    scope: {
      chainDatePicker: "="
    }
    template: "<input type='text' disabled='disabled' />",
    link: (scope,el,attrs) ->
      el.find('input').datepicker({
        buttonText: 'Select Date',
        dateFormat: 'yy-mm-dd',
        onSelect: (text,dp) ->
          scope.$apply ->
            scope.chainDatePicker = text
        showOn: 'button'
        }
      ).next(".ui-datepicker-trigger").addClass("btn btn-secondary")
      #add watch to update
      deregister = scope.$watch 'chainDatePicker', (newVal) ->
        el.find('input').val(newVal)

      # Remove the watch so el can get cleaned up
      scope.$on('$destroy', ->
        deregister()
        input = el.find('input')
        if input.datepicker('widget')
          # Clear the onSelect for this datepicker so the scope is no longer referenced by the onSelect closure
          # Typically, we'd want to destroy the datepicker, but for some reason the destroy is blowing up because
          # the internal instance found in the destroy method is undefined (not sure if it's a jquery bug or usage bug)
          input.datepicker("option", "onSelect", ->

          )
      )
  }
]

# TODO buy license for flags http://icondrawer.com/free.php -->
@components.directive 'chainFlag', [ ->
  {
    restrict: 'E'
    scope: {
      isoCode: "@"
      imgClass: "@"
    }
    template:'<img ng-show="isoCode && isoCode.length == 2" class="{{imgClass}}" ng-src="/images/flags/{{isoCode.toLowerCase()}}.png" title="Flag of {{isoCode}}" />'
    link: (scope,el,attrs) ->
        'placeholder'
  }
]

@components.directive 'chainSearchCriteria', ['$compile', 'chainSearchOperators', ($compile,chainSearchOperators) ->
  # Note:
  # The boundItem JSON object requires a search_criterions key containing a list of the criteria
  # already created for that object.
  {
    scope: {
      crit: "=chainSearchCriterion"
      boundItem: "=boundItem"
      modelFields: "=modelFields"
    }

    templateUrl: "html/chain_search_criteria.html"

    controller: ['$scope', ($scope) ->
      $scope.operators = chainSearchOperators.ops

      $scope.removeCriterion = (crit) ->
        criterions = $scope.boundItem.search_criterions
        criterions.splice($.inArray(crit, criterions ),1)

      $scope.addCriterion = (toAddId) ->
        toAdd = {value: ''}
        mf = findByMfid $scope.modelFields, toAddId
        toAdd.mfid = mf.mfid
        toAdd.datatype = mf.datatype
        toAdd.label = mf.label
        toAdd.operator = $scope.operators[toAdd.datatype][0].operator
        $scope.boundItem.search_criterions.push toAdd

      findByMfid = (ary,uid) ->
        for m in ary
          return m if m.mfid==uid
        return null

      registrations = []

      #remove criterions that are deleted
      registrations.push($scope.$watch 'boundItem.search_criterions', ((newValue, oldValue, watchScope) ->
          return unless watchScope.boundItem && watchScope.boundItem.search_criterions && watchScope.boundItem.search_criterions.length > 0
          for c in watchScope.boundItem.search_criterions
            watchScope.removeCriterion(c) if c && c.deleteMe  # Not sure why, but I've seen console errors due to c being null here.
        ), true
      )
    ]
  }
]

@components.directive 'chainSearchCriterion', ['$compile','chainSearchOperators',($compile,chainSearchOperators) ->
  {
    scope: {
      crit: "=chainSearchCriterion"
      modelFields: "=modelFields"
    }
    templateUrl: "html/chain_search_criterion.html"
    controller: ['$scope',($scope) ->
      $scope.operators = chainSearchOperators.ops

      $scope.getMatchingModelFieldTypes = (datatypes, excludeMfId) ->
        match = []
        for field in @.modelFields
          if excludeMfId != field.mfid
            for type in datatypes
              if field.datatype == type
                match.push(field)
                break
        match

      $scope.findByMfid = (ary,mfid) ->
        for m in ary
          return m if m.mfid==mfid
        null

      # parent controller needs to $watch for deleteMe and do the actual work of removing the object!
      $scope.remove = (crit) ->
        crit.deleteMe = true

      $scope.renderTextInput = (data_type, opr) ->
        switch opr
          when "in", "notin"
            return "<textarea rows='8' ng-model='crit.value' class='form-control'/><div><small class='muted'>Enter one value per line.</small></div>"
          when "null", "notnull"
            return ""

        return "<" + (if (data_type == "text") then "textarea rows='2'" else "input type='text'") + " ng-model='crit.value' class='form-control' />"

      $scope.renderInput = (rScope, el) ->
        dateStepper = false #true means apply jStepper to a relative date field
        v_str = "<input type='text' ng-model='crit.value' class='form-control' />"
        switch rScope.crit.datatype
          when "string", "integer", "fixnum", "decimal"
            v_str = rScope.renderTextInput rScope.crit.datatype, rScope.crit.operator
          when "date", "datetime"
            if chainSearchOperators.isRelative rScope.crit.datatype, rScope.crit.operator
              v_str = "<input type='text' ng-model='crit.value' class='form-control' />"
              dateStepper = true
            else if chainSearchOperators.isNoValue rScope.crit.datatype, rScope.crit.operator
              v_str = ""
            else if rScope.modelFields && chainSearchOperators.isFieldRelative rScope.crit.datatype, rScope.crit.operator
              # Angular doesn't appear to have a way to select the first option from the select box as a default, so using a new scope
              # property and setting the crit.value ahead of time is the only way to not have a blank option value show in the select box
              rScope.matchingModelFields = rScope.getMatchingModelFieldTypes ['date', 'datetime'], rScope.crit.mfid
              if rScope.matchingModelFields.length > 0 && !rScope.findByMfid(rScope.matchingModelFields, rScope.crit.value)
                rScope.crit.value = rScope.matchingModelFields[0].mfid

              v_str = "<select ng-model='crit.value' ng-options='f.mfid as f.label for f in matchingModelFields' class='form-control'></select>"
            else if /regexp/.test rScope.crit.operator
              v_str = rScope.renderTextInput rScope.crit.datatype, rScope.crit.operator
            else
              v_str = "<div style='display:inline;' chain-date-picker='crit.value'></div>"
          when "boolean"
            v_str = ""
          when "text"
            v_str = rScope.renderTextInput rScope.crit.datatype, rScope.crit.operator

        v = $compile(v_str)(rScope)
        va = $(el).find(".value_area")
        va.html(v)

        switch rScope.crit.datatype
          when "integer", "fixnum"
            va.find('input').jStepper({allowDecimals: false})
          when "decimal"
            va.find('input').jStepper()
        va.find('input').jStepper() if dateStepper

    ],

    link: (scope, el, attrs) ->
      deregister = scope.$watch 'crit.operator', ((newVal,oldVal, cbScope) ->

        # Reset the criterion value for date types when moving between operators that have different value types (ie. date -> field or date -> # days,etc)
        if cbScope.crit.datatype=='date' || cbScope.crit.datatype=='datetime'
          if !chainSearchOperators.isCompatibleDateOperators cbScope.crit.datatype, newVal, oldVal
            cbScope.crit.value = ""

        cbScope.renderInput(cbScope, el)
      ), false

      scope.$on('$destroy', ->
        deregister()
        deregister = null
      )

      scope.renderInput(scope, el)
      null
  }
]
@components.service 'chainSearchOperators', [ ->
  {
    findOperator: (datatype, name) ->
      opList = @.ops[datatype]
      op = null
      if opList
        for o in opList
          if o.operator == name
            op = o
            break
      op

    isRelative: (datatype, operator) ->
      op = @.findOperator datatype, operator
      if op then op.relative else false

    isFieldRelative: (datatype, operator) ->
      op = @.findOperator datatype, operator
      if op then op.fieldRelative else false

    isFieldRelativeOffset: (datatype, operator) ->
      op = @.findOperator datatype, operator
      if op then op.fieldRelativeOffset else false

    isCompatibleDateOperators: (datatype, newOperatorString, oldOperatorString) ->
      newOp = @.findOperator datatype, newOperatorString
      oldOp = @.findOperator datatype, oldOperatorString

      compatible = false
      if newOp? and oldOp?
        if newOp.relative
          compatible = oldOp.relative == true
        else if newOp.fieldRelative
          compatible = oldOp.fieldRelative == true
        else
          compatible = (!oldOp.relative? && !oldOp.fieldRelative?)

      return compatible

    isNoValue: (datatype, operator) ->
      op = @.findOperator datatype, operator
      if op then op.noValue else false


    # If you add an operator to this list, you MUST add it to the CRITERION hash in search_criterion.rb
    ops: {
      date: [
        {operator: 'eq', label: 'Equals'}
        {operator: 'eqf', label: 'Equals (Field Including Time)', fieldRelative: true}
        {operator: 'eqfd', label: 'Equals (Field)', fieldRelative: true}
        {operator: 'nq', label: 'Not Equal To'}
        {operator: 'nqf', label: 'Not Equal To (Field Including Time)', fieldRelative: true}
        {operator: 'nqfd', label: 'Not Equal To (Field)', fieldRelative: true}
        {operator: 'gt', label: 'After'}
        {operator: 'lt', label: 'Before'}
        {operator: 'bda', label: 'Before _ Days Ago', relative: true}
        {operator: 'ada', label: 'After _ Days Ago', relative: true}
        {operator: 'bdf', label: 'Before _ Days From Now', relative: true}
        {operator: 'adf', label: 'After _ Days From Now', relative: true}
        {operator: 'bma', label: 'Before _ Months Ago', relative: true}
        {operator: 'ama', label: 'After _ Months Ago', relative: true}
        {operator: 'bmf', label: 'Before _ Months From Now', relative: true}
        {operator: 'amf', label: 'After _ Months From Now', relative: true}
        {operator: 'pm', label: 'Previous _ Months', relative: true}
        {operator: 'cmo', label: 'Current Month', noValue: true}
        {operator: 'pqu', label: 'Previous _ Quarters', relative: true}
        {operator: 'cqu', label: 'Current Quarter', noValue: true}
        {operator: 'pfcy', label: 'Previous _ Full Calendar Years', relative: true}
        {operator: 'cytd', label: 'Current Year To Date', noValue: true}
        {operator: 'null', label: 'Is Empty', noValue: true}
        {operator: 'notnull', label: 'Is Not Empty', noValue: true}
        {operator: 'afld', label: 'After (Field)', fieldRelative: true}
        {operator: 'bfld', label: 'Before (Field)', fieldRelative: true}
        {operator: 'dt_regexp', label: 'Regex'}
        {operator: 'dt_notregexp', label: 'Not Regex'}
        ]
      datetime: [
        {operator: 'eq', label: 'Equals'}
        {operator: 'eqf', label: 'Equals (Field Including Time)', fieldRelative: true}
        {operator: 'eqfd', label: 'Equals (Field)', fieldRelative: true}
        {operator: 'nq', label: 'Not Equal To'}
        {operator: 'nqf', label: 'Not Equal To (Field Including Time)', fieldRelative: true}
        {operator: 'nqfd', label: 'Not Equal To (Field)', fieldRelative: true}
        {operator: 'gteq', label: 'After'}
        {operator: 'lt', label: 'Before'}
        {operator: 'bda', label: 'Before _ Days Ago', relative: true}
        {operator: 'ada', label: 'After _ Days Ago', relative: true}
        {operator: 'bdf', label: 'Before _ Days From Now', relative: true}
        {operator: 'adf', label: 'After _ Days From Now', relative: true}
        {operator: 'bma', label: 'Before _ Months Ago', relative: true}
        {operator: 'ama', label: 'After _ Months Ago', relative: true}
        {operator: 'bmf', label: 'Before _ Months From Now', relative: true}
        {operator: 'amf', label: 'After _ Months From Now', relative: true}
        {operator: 'pm', label: 'Previous _ Months', relative: true}
        {operator: 'cmo', label: 'Current Month', noValue: true}
        {operator: 'pqu', label: 'Previous _ Quarters', relative: true}
        {operator: 'cqu', label: 'Current Quarter', noValue: true}
        {operator: 'pfcy', label: 'Previous _ Full Calendar Years', relative: true}
        {operator: 'cytd', label: 'Current Year To Date', noValue: true}
        {operator: 'null', label: 'Is Empty', noValue: true}
        {operator: 'notnull', label: 'Is Not Empty', noValue: true}
        {operator: 'afld', label: 'After (Field)', fieldRelative: true}
        {operator: 'bfld', label: 'Before (Field)', fieldRelative: true}
        {operator: 'dt_regexp', label: 'Regex'}
        {operator: 'dt_notregexp', label: 'Not Regex'}
        ]
      integer: [
        {operator: 'eq', label: 'Equals'}
        {operator: 'nq', label: 'Not Equal To'}
        {operator: 'gt', label: 'Greater Than'}
        {operator: 'lt', label: 'Less Than'}
        {operator: 'sw', label: 'Starts With'}
        {operator: 'ew', label: 'Ends With'}
        {operator: 'nsw', label: 'Does Not Start With'}
        {operator: 'new', label: 'Does Not End With'}
        {operator: 'co', label: 'Contains'}
        {operator: 'in', label: 'One Of'}
        {operator: 'notin', label: 'Not One Of'}
        {operator: 'null', label: 'Is Empty'}
        {operator: 'notnull', label: 'Is Not Empty'}
        {operator: 'regexp', label: 'Regex'}
        {operator: 'notregexp', label: 'Not Regex'}
        ]
      decimal: [
        {operator: 'eq', label: 'Equals'}
        {operator: 'nq', label: 'Not Equal To'}
        {operator: 'gt', label: 'Greater Than'}
        {operator: 'lt', label: 'Less Than'}
        {operator: 'sw', label: 'Starts With'}
        {operator: 'ew', label: 'Ends With'}
        {operator: 'nsw', label: 'Does Not Start With'}
        {operator: 'new', label: 'Does Not End With'}
        {operator: 'co', label: 'Contains'}
        {operator: 'in', label: 'One Of'}
        {operator: 'notin', label: 'Not One Of'}
        {operator: 'null', label: 'Is Empty'}
        {operator: 'notnull', label: 'Is Not Empty'}
        {operator: 'regexp', label: 'Regex'}
        {operator: 'notregexp', label: 'Not Regex'}
        ]
      fixnum: [
        {operator: 'eq', label: 'Equals'}
        {operator: 'nq', label: 'Not Equal To'}
        {operator: 'gt', label: 'Greater Than'}
        {operator: 'lt', label: 'Less Than'}
        {operator: 'sw', label: 'Starts With'}
        {operator: 'ew', label: 'Ends With'}
        {operator: 'nsw', label: "Does Not Start With"}
        {operator: 'new', label: "Does Not End With"}
        {operator: 'co', label: 'Contains'}
        {operator: 'in', label: 'One Of'}
        {operator: 'notin', label: 'Not One Of'}
        {operator: 'null', label: 'Is Empty'}
        {operator: 'notnull', label: 'Is Not Empty'}
        {operator: 'regexp', label: 'Regex'}
        {operator: 'notregexp', label: 'Not Regex'}
        ]
      string: [
        {operator: 'eq', label: 'Equals'}
        {operator: 'nq', label: 'Not Equal To'}
        {operator: 'sw', label: 'Starts With'}
        {operator: 'ew', label: 'Ends With'}
        {operator: 'nsw', label: "Does Not Start With"}
        {operator: 'new', label: "Does Not End With"}
        {operator: 'co', label: 'Contains'}
        {operator: 'nc', label: "Doesn't Contain"}
        {operator: 'in', label: 'One Of'}
        {operator: 'notin', label: 'Not One Of'}
        {operator: 'null', label: 'Is Empty'}
        {operator: 'notnull', label: 'Is Not Empty'}
        {operator: 'regexp', label: 'Regex'}
        {operator: 'notregexp', label: 'Not Regex'}
        ]
      text: [
        {operator: 'eq', label: 'Equals'}
        {operator: 'nq', label: 'Not Equal To'}
        {operator: 'sw', label: 'Starts With'}
        {operator: 'ew', label: 'Ends With'}
        {operator: 'nsw', label: "Does Not Start With"}
        {operator: 'new', label: "Does Not End With"}
        {operator: 'co', label: 'Contains'}
        {operator: 'nc', label: "Doesn't Contain"}
        {operator: 'in', label: 'One Of'}
        {operator: 'notin', label: 'Not One Of'}
        {operator: 'null', label: 'Is Empty'}
        {operator: 'notnull', label: 'Is Not Empty'}
        {operator: 'regexp', label: 'Regex'}
        {operator: 'notregexp', label: 'Not Regex'}
        ]
      boolean: [
        {operator: 'notnull', label: 'Yes'}
        {operator: 'null', label: 'No'}
        {operator: 'regexp', label: 'Regex'}
        {operator: 'notregexp', label: 'Not Regex'}
        ]
      }
    }
]
@components.directive 'chainSearchResult', ['$http', '$location', '$q', 'localStorageService',($http, $location, $q, localStorageService) ->
  {
    scope: {
      searchResult: "=chainSearchResult"
      page: "="
      errors: "="
      notices: "="
      urlPrefix: "@src"
      noChrome: "@"
      perPage: "="
      canceller: "=?"
      loading: "=?"
    }
    transclude: true
    templateUrl: "html/search_result.html"
    controller: ['$scope',($scope) ->

      $scope.loadedSearchId = null

      storageIdentifier = (scope) ->
        scope.urlPrefix+"~"+scope.searchResult.id

      clearSearchSelections = (scope) ->
        localStorageService.remove(storageIdentifier(scope), "sessionStorage")

      writeSearchSelections = (scope) ->
        o = {rows: scope.bulkSelected, all: scope.allSelected}
        localStorageService.set(storageIdentifier(scope), angular.toJson(o), "sessionStorage")

      getSearchSelections = (scope) ->
        obj = localStorageService.get(storageIdentifier(scope), "sessionStorage")
        obj = angular.fromJson(obj) if obj
        obj

      $scope.searchSelectionsRead = false

      #load selection state values from stored search selections
      readSearchSelections = (scope, searchId) ->
        usedIds = []
        o = getSearchSelections(scope)
        if o
          scope.bulkSelected = o.rows
          scope.selectAll() if o.all
          for r in scope.searchResult.rows
            if $.inArray(r.id,scope.bulkSelected)>=0 && $.inArray(r.id,usedIds)==-1
              r.bulk_selected = true
              usedIds.push r.id
        $scope.searchSelectionsRead = true

      loadResultPage = (scope, searchId, page) ->
        p = if page==undefined then 1 else page
        sr  = scope.searchResult
        for key, value of sr
          delete sr[key] unless key=='id'

        url = scope.urlPrefix+searchId+'.json?page='+p #need to specify json here because of this rails bug https://github.com/rails/rails/issues/9940
        if scope.perPage
          url += "&per_page=" + scope.perPage

        successHandler = (response) ->
          data = response.data
          # This is primarily just a backup check to make sure we're not attempting to load a page that doesn't exist, if
          # we do, just jump to the first page of the search results (note, this incurs another http request)
          if data.total_pages==undefined || data.total_pages == 0 || data.total_pages >= page
            sr = scope.searchResult
            sr[key] = value for key, value of data

            scope.errors.push "Your search was too big.  Only the first " + scope.searchResult.total_pages + " pages are being shown."  if scope.errors && scope.searchResult.too_big

            scope.loadedSearchId = scope.searchResult.id
            readSearchSelections scope, data.id
            $http.get(scope.urlPrefix+searchId+'/total_objects.json').then((resp) ->
              sr.total_objects = resp.data.total_objects
              scope.loading = false
            )
          else
            loadResultPage(scope, searchId, 1)

        errorHandler = (resp) ->
          if scope.errors
            if resp.status == 404
              scope.errors.push "This search with id "+id+" could not be found."
            else if resp.status == -1 # request cancelled through 'Save' button
              scope.canceller.cancelled.resolve()
            else
              scope.errors.push "An error occurred while loading this search result. Please reload and try again."

        scope.loading = true
        $http.get(url, {timeout: scope.canceller && scope.canceller.cancel.promise}).then(successHandler,errorHandler)

      onSearchLoaded = (saved, scope) ->
        # We want to clear bulkSelections in this case since the user saved the setup (which will
        # re-run the search and likely invalidate existing bulk selections)
        if saved
          clearSearchSelections scope
          scope.selectNone()

        if scope.searchResult.id != scope.loadedSearchId
          loadResultPage(scope, scope.searchResult.id, scope.page)

      #return array of valid page numbers for the current search result
      $scope.pageNumberArray = ->
        if $scope.searchResult && $scope.searchResult.total_pages
          [1..$scope.searchResult.total_pages]
        else
          [1]

      #return true if the given row's id is different than the previous rows id
      $scope.newObjectRow = (idx) ->
        return true if idx==0
        myRowId = $scope.searchResult.rows[idx].id
        lastRowId = $scope.searchResult.rows[idx-1].id
        return myRowId!=lastRowId && idx>0

      #return the classes that should be applied to a result row based on it's position and whether it's the first instance of a new row key
      $scope.classesForRow = (idx) ->
        return [] if idx==0
        r = []
        r.push 'search_row_break' if $scope.newObjectRow(idx)
        r

      #
      # Bulk action handling
      #

      #active list of selected bulk actions
      $scope.bulkSelected = []
      $scope.allSelected = false
      $scope.selectPageCheck = false

      #clear selection
      $scope.selectNone = ->
        $scope.bulkSelected = []
        $scope.allSelected = false
        r.bulk_selected = false for r in $scope.searchResult.rows if $scope.searchResult.rows

      if $location.search()['clearSelection'] is 'true'
        # Unset the selections then remove the parameter
        clearSearchSelections($scope)
        $location.search('clearSelection', null)

      $scope.selectAll = ->
        $scope.allSelected = true
        r.bulk_selected = true for r in $scope.searchResult.rows

      $scope.selectPage = ->
        r.bulk_selected = true for r in $scope.searchResult.rows

      #run a bulk action
      $scope.executeBulkAction = (bulkAction) ->
        selectedItems = $scope.bulkSelected
        sId = (if $scope.allSelected then $scope.searchResult.search_run_id else null)
        cb = null
        cb = eval(bulkAction.callback) if bulkAction.callback
        if cb
          BulkActions.submitBulkAction selectedItems, sId, bulkAction.path, 'post', cb
        else
          BulkActions.submitBulkAction selectedItems, sId, bulkAction.path, 'post'
        null

      #pagination
      $scope.firstPage = ->
        $scope.searchResult.page = 1

      $scope.lastPage = ->
        $scope.searchResult.page = $scope.searchResult.total_pages

      $scope.nextPage = ->
        $scope.searchResult.page++

      $scope.previousPage = ->
        $scope.searchResult.page--

      registrations = []

      registrations.push($scope.$watch 'allSelected', (newValue,oldValue, cbScope) ->
        writeSearchSelections(cbScope) unless newValue==oldValue
      )

      registrations.push($scope.$watch 'searchResult', ((newValue,oldValue, cbScope) ->
        if newValue && newValue.rows
          selectedIds = []
          nonSelectedIds = []
          visitedIds = []
          for r in newValue.rows
            # skip any ids we've already seen.  This happens when we're showing an object
            # with multiple lines (.ie entry w/ multiple invoices)
            if $.inArray(r.id,visitedIds) < 0
              visitedIds.push r.id
              if r.bulk_selected
                selectedIds.push r.id
              else
                nonSelectedIds.push r.id

          # remove the non-selected ids from the scope
          # we can't just clear it because we don't want to lose items from other pages that were loaded
          # by the searchSelections
          for nsId in nonSelectedIds
            idx = $.inArray(nsId,cbScope.bulkSelected)
            cbScope.bulkSelected.splice(idx,1) if idx >= 0
            cbScope.allSelected = false

          # put the selected items into the scope
          for sId in selectedIds
            cbScope.bulkSelected.push sId unless $.inArray(sId,cbScope.bulkSelected)>=0


        cbScope.selectPageCheck = false
        writeSearchSelections cbScope if $scope.searchSelectionsRead
        ), true #true means "deep search"
      )

      #
      # End bulk action handling
      #
      registrations.push($scope.$watch 'searchResult.id', (newVal, oldVal, cbScope) ->
        if newVal!=undefined && !isNaN(newVal) && newVal!=cbScope.loadedSearchId
          onSearchLoaded cbScope.searchResult.saved, cbScope
        if newVal==undefined
          cbScope.loadedSearchId = null
      )

      $scope.$on('$destroy', ->
        deregister() for deregister in registrations
        registrations = null
      )
    ]
  }
]