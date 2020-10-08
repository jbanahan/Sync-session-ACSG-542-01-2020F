$('#todo-form').submit(function () {
    $.post({
        url: '/save',
        data: {"item": $('#todo-input').val()},
        dataType: 'json'
    })
});

$(document).on('click', 'button.delete', function (event) {
    //var id = event.target.id;
    var id = $(this).attr("id")
    $.ajax({
        url: "/?id=" + id,
        type: 'DELETE'
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