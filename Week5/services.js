$('#some-form').submit(function () {
    $.post({
        url: '/',
        data: JSON.stringify({"thing": $('#some-input').val()}),
        dataType: 'json'
    })
})