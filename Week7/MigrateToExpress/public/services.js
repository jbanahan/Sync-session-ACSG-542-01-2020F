$('#todo-form').submit(function () {
    $.post({
        url: '/',
        data: JSON.stringify({"item": $('#todo-input').val()}),
        dataType: 'json'
    })
})