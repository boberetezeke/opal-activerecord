# Opal: ActiveRecord

## Installation

Add this line to your application's Gemfile:

    gem 'opal-activerecord'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install opal-activerecord


## Usage

Inside your `application.js.rb`:

```ruby
require 'active_record'                 # to require the whole active record lib
```

## Testing

There are two ways to run tests. You can run them inside of MRI
for ease of testing and better debuggability or you can run them
using Opal (as this is how it will actually be used).

* To run in Opal do - rake
* To run in MRI do - rspec spec

In addition to this, you can run the spec against the real active
record to make sure the tests duplicate the functionality there. To
run that:

* run_with_real_active_record=true rspec spec

## Supported Subset of ActiveRecord/ActiveModel

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

opal-activerecord is Copyright © 2014 Steve Tuckner. It is free software, and may be redistributed under the terms specified in the LICENSE file (an MIT License).
