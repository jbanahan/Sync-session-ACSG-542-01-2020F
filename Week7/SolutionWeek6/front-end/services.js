$('#todo-form').submit(function () {
    $.post({
        url: '/save',
        data: JSON.stringify( { "item": $('#thing').val() } ),
        dataType: 'json',
        contentType: 'application/json'
    })
});

function getAllItems() {
    $.getJSON({
        url: '/list',
        success: function (data){
            console.log(data.docs)
            var list = [];
            $.each(data.docs, function (i, item) {
                list.push( "<li>" + item.item + "</li>" );
            })

            $( "<ul/>", {
                html: list.join( "" )
            }).appendTo( "placeholder" );
        }
    });
}

getAllItems();