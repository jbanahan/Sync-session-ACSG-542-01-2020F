function entryActivitySummary() {
  $('#nav-action-bar > .btn-group').append('<button title="Download" id="ent_download" class="btn_link btn navbar-btn btn-secondary"><i class="fa fa-download"></i></button>');
  $('#ent_download').click(function() {
    $.ajax('/api/v1/'+window.location.pathname+'/download',{
      type:'POST',
      headers: {
        Accept : "application/json",
        "Content-Type": "application/json"
      },
      success: function() { 
        $('.alert-success, .alert-danger, .alert-info').remove();
        var p = Chain.makeAlertPanel("Your report has been scheduled. You'll receive a system message when it finishes.");
        $('#main-container').prepend(p);
        window.scrollTo(0,0);
      },
      error: function(response) {
        $('.alert-success, .alert-danger, .alert-info').remove();
        var msg = response.responseJSON ? response.responseJSON.errors.join(" ") : "A server error occurred. Please wait and try again.";
        var p = Chain.makeErrorPanel(msg);
        $('#main-container').prepend(p);
        window.scrollTo(0,0);
      }
    });
  });
  $('#nav-action-bar > .btn-group').append('<button title="Email" id="ent_email" class="btn_link btn navbar-btn btn-secondary"><i class="fa fa-envelope"></i></button>');
  $('#ent_email').click(function() { $('#email-modal').modal('show'); });
  $('#send_email').click(function() {
    $.ajax('/api/v1/'+window.location.pathname+'/email',{
      type:'POST',
      headers: {
        Accept : "application/json",
        "Content-Type": "application/json"
      },
      data: JSON.stringify(emailFields()),
      success: function() { 
        $('.alert-success, .alert-danger, .alert-info').remove();
        clearModalFields();
        $('#email-modal').modal('hide');
        var p = Chain.makeAlertPanel("Your report will be emailed shortly.");
        $('#main-container').prepend(p);
        window.scrollTo(0,0);
      },
      error: function(response) {
        $('.alert-success, .alert-danger, .alert-info').remove();
        $('#email-modal').modal('hide');
        var msg = response.responseJSON ? response.responseJSON.errors.join(" ") : "A server error occurred. Please wait and try again.";
        var p = Chain.makeErrorPanel(msg);
        $('#main-container').prepend(p);
        window.scrollTo(0,0);
      }
    });
  });
  function emailFields() {
    return { "addresses": $('#email-to').val(), 
             "subject": $('#email-subject').val(), 
             "body": $('#email-body').val(),
             "mailing_list": $("#email-mailing-list").val() };
  }
  function clearModalFields() {
    $('#email-to').val("");
    $('#email-subject').val("");
    $('#email-body').val("");
  }
}
