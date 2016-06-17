# Parrot

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'parrot', git: 'git@github.com:42races/parrot.git'

And then execute:

    $ bundle

You will need to have babel-cli installed to compile js files

    $ npm install --save-dev --global babel-cli

## Usage

**Creating a new html5 app**
    
    $ parrot new blog

**Build to app**
    
    $ cd blog
    $ parrot build

**Start server**

    $ parrot serve

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request



parrot new application_name
parrot serve
parrot build