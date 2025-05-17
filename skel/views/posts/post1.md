# Parrot

Parrot is a static website build tool developed to create my own blog.

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

## Testing

    $ rspec spec
    $ rspec -f d    # view test with description
    $ rspec -f d --tag focus  # run only focussed sections, usefull for debugging

## Contributing

[github](https://github.com/deepakkumarnd/parrot)

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
