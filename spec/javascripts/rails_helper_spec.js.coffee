#=require rails_helper

describe 'RailsHelper', ->
  describe 'authToken', ->
    it 'should set / get token', ->
      RailsHelper.authToken('abc')
      expect(RailsHelper.authToken()).toEqual('abc')
  describe 'prepRailsForm', ->
    beforeEach ->
      loadFixtures('basic_form.html')
      RailsHelper.authToken('atok')

    it 'should set auth token', ->
      RailsHelper.prepRailsForm($("form"),"/xyz","post")
      tok = $("form").find("div[style='margin:0;padding:0;display:inline'] input[name='authenticity_token'][type='hidden'][value='atok']")
      expect(tok).toExist()
    it 'should not set auth token for get', ->
      RailsHelper.prepRailsForm($("form"),"/xyz","get")
      tok = $("form").find("div[style='margin:0;padding:0;display:inline'] input[name='authenticity_token'][type='hidden'][value='atok']")
      expect(tok).not.toExist()
    it 'should set action', ->
      RailsHelper.prepRailsForm($("form"),"/xyz","post")
      expect($("form[action='/xyz']")).toExist()
    it 'should set methods for post', ->
      RailsHelper.prepRailsForm($("form"),"/xyz","post")
      expect($("form[method='post']")).toExist()
      expect($("form input[name='_method']")).not.toExist()
    it 'should set methods for put', ->
      RailsHelper.prepRailsForm($("form"),"/xyz","put")
      expect($("form[method='post']")).toExist()
      expect($("form input[name='_method'][value='put']")).toExist()
    it 'should set methods for delete', ->
      RailsHelper.prepRailsForm($("form"),"/xyz","delete")
      expect($("form[method='post']")).toExist()
      expect($("form input[name='_method'][value='delete']")).toExist()
    it 'should set utf-8', ->
      RailsHelper.prepRailsForm($("form"),"/xyz","post")
      utf = $("form").find("div[style='margin:0;padding:0;display:inline'] input[name='utf8'][type='hidden']")
      expect(utf).toExist()
