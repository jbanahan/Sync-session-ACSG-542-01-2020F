function getRandomCat(tag) {
    $(document).ready(function() {
        $(tag).replaceWith('<img src=\'http://lorempixel.com/500/600/cats\'>');
        $(tag).replaceWith('<img src=\'http://lorempixel.com/500/600/cats\'>');
        $(tag).replaceWith('<img src=\'http://lorempixel.com/500/600/cats\'>');
    })
}

getRandomCat('placeholder1')
getRandomCat('placeholder2')
getRandomCat('placeholder3')