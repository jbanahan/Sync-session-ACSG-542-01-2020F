var socket = io.connect('http://localhost:8001')

socket.on('connect', function () {
    $('chat').addClass('connected');
})

socket.on('user message', message);

function message(from, msg) {
    $('#lines').append($('<p>').append($('<b>').text(from)), msg)
}

socket.on('nicknames', function (nicknames) {
    $('#nicknames').empty().append($('<span>Online: </span>'))
    for (var i in nicknames) {
        $('#nicknames').append($('<b>').text(nicknames[i]));
    }
})

// dom manipulation
$(function () {
    $('#set-nickname').submit(function (ev) {
        socket.emit('nickname', $('#nick').val(), function (set) {
            if (!set) {
                clear();
                return $('#chat').addClass('nickname-set');
            }
        });
        return false;
    });

    $('#send-message').submit(function () {
        message('me', $('#message').val());
        socket.emit('user message', $('#message').val());
        clear();
        $('#lines').get(0).scrollTop = 10000000;
        return false;
    });

    function clear () {
        $('#message').val('').focus();
    };
});