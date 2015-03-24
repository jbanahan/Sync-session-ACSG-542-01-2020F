describe 'getButtons', ->
  it "should get buttons", ->
    coreModulePath = 'companies'
    objId = '10'
    spyOn(jQuery,'ajax').andReturn('hello')
    expect(ChainStateButtons.getButtons(coreModulePath,objId)).toEqual('hello')
    expected = {
      url: '/api/v1/companies/10/state_toggle_buttons.json'
      contentType: 'application/json'
      type: 'GET'
      dataType: 'json'
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json"
      }
    }
    expect(jQuery.ajax).toHaveBeenCalledWith(expected)

describe 'toggleButton', ->
  it "should make ajax call", ->
    coreModulePath = 'companies'
    objId = '10'
    buttonId = '50'
    spyOn(jQuery,'ajax').andReturn('hello')
    expect(ChainStateButtons.toggleButton(coreModulePath,objId,buttonId)).toEqual('hello')
    expected = {
      url: '/api/v1/companies/10/toggle_state_button.json'
      method: 'POST'
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json"
      }
      data: JSON.stringify({button_id: '50'})
    }
    expect(jQuery.ajax).toHaveBeenCalledWith(expected)
