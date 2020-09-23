var socket = io.connect('http://localhost:8005')

socket.on('fred', message);

function message(msg) {
    $('#banner').replaceWith("<div id='banner'>" + msg + "</div>")
}

// dom manipulation
$(function () {
    $('#send-message').submit(function () {
        message($('#message').val());
        socket.emit('fred', $('#message').val());
        clear();
        return false;
    });

    function clear () {
        $('#message').val('').focus();
    };
});