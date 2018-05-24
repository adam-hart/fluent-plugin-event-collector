# fluent-plugin-event-collector

[Fluentd](https://fluentd.org/) filter plugin to aggregate events based on a common field key.

Event Collector merges multiple Fluentd events into a single event with key fields concatenated. The terminating event should be designated with a special key value pair, however unfinished events will timeout and be emitted normally.  For example with the key field `message` and the event key `request_id`, the two events:

```
{'request_id' => '123abc', 'foo' => 'bar', 'message' => 'Hello'}
{'request_id' => '123abc', 'foo' => 'baz', 'message' => 'World!', 'complete' => 'true'}
```

will be emitted as

```
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

* **event_key** (string) (required): The event key used to identify groupings of events.
* **end_tag_key** (string) (required): The event key used to identify the last event in a group.
* **end_tag_value** (string) (required): The value in end_tag_key that identifies the last event in a group.
* **merge_fields** (array) (optional): The event field keys to be concatenated across event groups.
  * Default value: `[]`.
* **merge_field_delimeter** (string) (optional): The delimeter to be added between merge field values.
  * Default value: ` `.
* **event_timeout** (integer) (optional): The timeout for events that have received no closing tag.
  * Default value: `30`.

## Copyright

* Copyright(c) 2018- Adam Hart
* License
  * Apache License, Version 2.0
