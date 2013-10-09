describe 'hideMessage', () ->
  it "should do post", () ->
    spyOn $, 'post'
    Chain.hideMessage 'abc'
    expect($.post).toHaveBeenCalledWith('/hide_message/abc')
