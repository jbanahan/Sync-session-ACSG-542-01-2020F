describe 'StateToggleButtonSvc', ->

  beforeEach module('ChainComponents')

  describe 'stateToggleButtonSvc', ->

    http = svc = null

    beforeEach inject((_stateToggleButtonSvc_,$httpBackend) ->
      svc = _stateToggleButtonSvc_
      http = $httpBackend
    )

    afterEach ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'getButtons', ->
      it 'should get button objects', ->
        resp = {state_toggle_buttons:[
          {id:1,button_text:'btxt1',button_confirmation:'bconf1',core_module_path:'orders',base_object_id:10}
          {id:2,button_text:'btxt2',button_confirmation:'bconf2',core_module_path:'orders',base_object_id:10}
        ]}

        http.expectGET('/api/v1/orders/10/state_toggle_buttons.json').respond resp

        btns = null
        svc.getButtons('Orders',10).then (httpResp) ->
          btns = httpResp

        http.flush()

        expect(btns).toEqual resp

    describe 'toggleButton', ->
      it 'should toggle button', ->
        button = {id:1,button_text:'btxt1',button_confirmation:'bconf1',core_module_path:'orders',base_object_id:10}
        resp = {ok:'ok'}
        http.expectPOST('/api/v1/orders/10/toggle_state_button.json',{button_id:1}).respond resp

        wasCalled = false
        svc.toggleButton(button).then (httpResp) ->
          wasCalled = true

        http.flush()

        expect(wasCalled).toBeTruthy()
