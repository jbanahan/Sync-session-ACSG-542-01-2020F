describe 'hideMessage', () ->
  it "should do post", () ->
    spyOn $, 'post'
    Chain.hideMessage 'abc'
    expect($.post).toHaveBeenCalledWith('/hide_message/abc')

describe 'sendEmailAttachments', () ->
  it 'should post correct parameters to correct URL', () ->
    spyOn $, 'post'
    Chain.sendEmailAttachments("Entry", "10", "me@there.com", "Test subject", "Test body", ["22", "88"])
    expect(jQuery.post).toHaveBeenCalledWith('/attachments/email_attachable/Entry/10', { to_address : 'me@there.com', email_subject : 'Test subject', email_body : 'Test body', ids_to_include : [ '22', '88' ] })

describe 'addPagination', () ->
  it "should create pagination widget", () ->
    target = affix('#my_target')
    base_url = '/x'
    current_page = 3
    total_pages = 7
    Chain.addPagination '#my_target', base_url, current_page, total_pages
    expect($('#my_target').find('a[href="/x?page=1"]').length).toEqual 1
    expect($('#my_target').find('a[href="/x?page=2"]').length).toEqual 1
    expect($('#my_target').find('a[href="/x?page=4"]').length).toEqual 1
    expect($('#my_target').find('a[href="/x?page=7"]').length).toEqual 1
    expect($('#my_target').find('select option[value="1"]').length).toEqual 1
    expect($('#my_target').find('select option[value="7"]').length).toEqual 1