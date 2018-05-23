# fluent-plugin-event-collector

[Fluentd](https://fluentd.org/) filter plugin to do something.

Event Collector merges multiple Fluentd events into a single event with key fields concatenated. The terminating event should be designated with a special key value pair, however unfinished events will timeout and be emitted normally.  For example with the key field `message` and the event key `request_id`, the two events:

```json
{'request_id' => '123abc', 'foo' => 'bar', 'message' => 'Hello'}
{'request_id' => '123abc', 'foo' => 'baz', 'message' => 'World!', 'complete' => 'true'}
```

will be emitted as

```json
{'request_id' => '123abc', 'foo' => 'bar', 'message' => 'Hello World!', 'complete' => 'true'}
```

All non-key fields follow a last write wins model, however multiple key fields are allowed.

## Installation

### RubyGems

```
$ gem install fluent-plugin-event-collector
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-event-collector"
```

And then execute:

```
$ bundle
```

## Configuration

You can generate configuration template:

```
$ fluent-plugin-config-format filter event_collector
```

You can copy and paste generated documents here.

## Copyright

* Copyright(c) 2018- Adam Hart
* License
  * Apache License, Version 2.0
