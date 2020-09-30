$('#some-form').submit(function () {
    $.post({
        url: '/save',
        data: JSON.stringify({"thing": $('#some-input').val()}),
        dataType: 'json'
    })
})

function getAllItems() {
    $.getJSON({
        // On your back-end or server side
        //  } else if (req.method === "GET" && req.url === "/list") {
        //    New stuff!
        //  } else {
        url: '/list',
        success: function (data) {
            var list = [];
            $.each(data.docs, function (i, item) {
                list.push("<li>" + item.item + "</li>");
            })

            $("<ul>", {
                html: list.join("")
            }).appendTo("#list");
        }
    })
}
