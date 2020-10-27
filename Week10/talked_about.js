$('#todo-form').submit(function () {
    $.post({
        url: '/save',
        data: {"item": $('#todo-input').val()},
        dataType: 'json',
        // This line caused issues in the Week 7 project
        contentType: 'application/json'
    })
});

$(document).on( 'click', 'button.delete', function (e) {
    //var id = $(this).attr("id")
    var id = e.target.id
    $.ajax({
        url: "/?id=" + id,
        type: 'DELETE',
        // This line was missing from the demo and that's my fault
        success: $('placeholder').find('#'+ id).parent().remove()
    })
});
