$('#todo-form').submit(function () {
    $.post({
        url: '/save',
        data: JSON.stringify( { "item": $('#thing').val() } ),
        dataType: 'json',
        contentType: 'application/json'
    })
});

$(document).on('click', 'button.delete', function (event) {
    var id = event.target.id;
    $.ajax({
        url: "/?id=" + id,
        type: 'DELETE',
        success: $('placeholder').find('#' + id).parent().remove()
    })
})

function getAllItems() {
    $.getJSON({
        url: '/list',
        success: function (data){
            console.log(data)
            var list = [];
            $.each(data.docs, function (i, item) {
                console.log(item.item);
                list.push( "<li>" + item.item + "<button type='button' class='btn btn-danger btn-sm delete' id='"+item._id+"'>x</button></li>" );
            })

            $( "<ul/>", {
                html: list.join( "" )
            }).appendTo( "placeholder" );
        }
    });
}

getAllItems();