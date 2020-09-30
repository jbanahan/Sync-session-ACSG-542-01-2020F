/* Do not commit this code into your projects!

function getRandomCat() {
    var element = document.querySelector('#myPlacement');
    var newElement = document.createElement('img');
    newElement.setAttribute('src', 'http://lorempixel.com/500/600/cats');
    element.parentNode.replaceChild(newElement, element);
}*/

function getRandomCat() {
    $(document).ready(function (){
        $("#myPlacement").replaceWith("<img src='http://lorempixel.com/500/600/cats'>")
    })
}

getRandomCat();