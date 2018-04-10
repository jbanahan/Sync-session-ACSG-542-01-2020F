function entryActivitySummary() {
  $('#nav-action-bar > .btn-group').append('<button title="Download" id="ent_download" class="btn_link btn navbar-btn btn-default"><i class="fa fa-download"></i></button>');
    $('#ent_download').click(function() {
      $.ajax('/api/v1/'+window.location.pathname+'/download',{
        type:'POST',
        headers: {
          Accept : "application/json",
          "Content-Type": "application/json"
        },
        success: function() { 
          $('.panel-success, .panel-danger, .panel-info').remove();
          var p = Chain.makeAlertPanel("Your report has been scheduled. You'll receive a system message when it finishes.");
          $('#main-container').prepend(p);
          window.scrollTo(0,0);
        },
        error: function(response) {
          $('.panel-success, .panel-danger, .panel-info').remove();
          var msg = response.responseJSON ? response.responseJSON.errors.join(" ") : "A server error occurred. Please wait and try again.";
          var p = Chain.makeErrorPanel(msg);
          $('#main-container').prepend(p);
          window.scrollTo(0,0);
        }
      });
  });
}
