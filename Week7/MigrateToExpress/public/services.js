$('#todo-form').submit(function () {
    $.post({
        url: '/',
        data: {"item": $('#todo-input').val()},
        dataType: 'json'
    })
})