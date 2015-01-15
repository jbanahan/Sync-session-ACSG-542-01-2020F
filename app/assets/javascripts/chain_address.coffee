root = exports ? this
root.ChainAddress =
  initAddresses: () ->
    $(document).on 'click', '[google-maps-src][google-maps-target]', (evt) ->
      evt.preventDefault()
      t = $(this)
      target = $(t.attr('google-maps-target'))
      isActive = t.hasClass('google-maps-active')
      $('.google-maps-active').removeClass('google-maps-active')
      if isActive
        target.removeClass('google-maps-wrap')
        target.html('')
        html = ""
      else
        t.addClass('google-maps-active')
        target.addClass('google-maps-wrap')
        html = "<iframe src='"+t.attr('google-maps-src')+"'></iframe><div class='text-right text-warning'><small>Map locations are approximate based on the address text provided.</small></div>"
      target.html(html)