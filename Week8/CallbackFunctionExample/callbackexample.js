//  This example taken from:
//  https://developer.mozilla.org/en-US/docs/Glossary/Callback_function

function greeting (name) {
    alert('Hello ' + name);
}

function processUserInput(callback) {
    var name = prompt('Please enter your name.');
    callback(name);
}

processUserInput(greeting);