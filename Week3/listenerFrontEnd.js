var p = document.querySelector('p');
var windowWidth = window.matchMedia('(max-width: 600px)');

function screenWidthTester(e) {
    if (e.matches) {
        p.textContent = "This is a small screen!";
        document.body.style.backgroundColor = 'red';
    } else {
        p.textContent = "This is a good size screen.";
        document.body.style.backgroundColor = 'blue';
    }
}

windowWidth.addListener(screenWidthTester)