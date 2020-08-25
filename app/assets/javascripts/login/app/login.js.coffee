$(document).ready () ->
    appendNewsArticle = (article) ->
      publishedOn = moment(article.publishOn).format('LL')
      articleUrl = 'https://www.vandegriftinc.com/news/' + article.urlId
      articleTitle = article.title
      bodyText = article.body
      bodyText = bodyText.replace(/<[^>]+>/g, '')
      shortBody = bodyText.substring(0, 250)
      html = '<div class="px-2">'
      html += '<p>' + publishedOn + '</p>'
      html += '<a href="' + articleUrl + '" target="_blank"><h4>' + articleTitle + '</h4></a>'
      html += '<p>' + shortBody + '... </p><hr/></div>'
      jQuery('#news-box').append html
      return

    $('#user_session_id').focus()

    $('#registration-modal').on 'shown.bs.modal', ->
      $('#registration-email').focus()
      return

    $('#forgot-password-modal').on 'shown.bs.modal', ->
      $('#reset-password-email').focus()
      return

    $.ajax
      dataType: 'json'
      url: 'https://vandegrift-news.s3.amazonaws.com/latest_news.json'
      success: (data) ->
        win = $(window)
        # Append at least four articles or up to the screen height, but not beyond the number of articles
        i = 0
        while i < data.items.length and (i < 4 or $(document).height() - win.height() <= win.scrollTop())
          appendNewsArticle data.items[i]
          i++
        return

    $('#registration_form').on 'submit', (e) ->
      target = $(e.target)
      e.preventDefault()
      $('#registration-modal').modal 'hide'
      $.ajax
        type: 'post'
        url: target.attr('action')
        data: target.serialize()
        success: (r) ->
          `var panel`
          if r.flash.errors
            panel = Chain.makeErrorPanel(r.flash.errors)
            $('.container-fluid').first().prepend panel
          else
            panel = Chain.makeSuccessPanel(r.flash.notice)
            $('.container-fluid').first().prepend panel
          return
        error: (r) ->
          panel = Chain.makeErrorPanel('There was a problem with the server. Please wait a minute, and try again.')
          $('.container-fluid').first().prepend panel
          return
      return
    return
