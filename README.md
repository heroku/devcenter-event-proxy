# Deprecated

# devcenter-event-proxy

Receive a logplex stream, turn it into event-manager-api `publish` calls.

At a higher level, take a structured log stream with embedded (Dev Center style) events and populate the event-manager-api database `all_events` table. This is then one of the data sources for data warehouse, allowing us to do interesting things when measure a user's interaction with Heroku at a holistic level.

Currently, the proxy is very specific to DC events and event_types.

## Event format

Logs sent across in this JSON format:

```
{
 "user_heroku_uid":"351369@users.heroku.com","user_email":"aguy@gmail.com","article_id":650,"article_slug":"quickstart",
 "article_status":"published","article_title":"Getting Started with Heroku","article_owner_id":58,"article_owner_email":"jon@heroku.com",
 "at":"2013-01-04T18:59:18+00:00","event_type":"ArticleRead","component": "devcenter"
}
```

Will be parsed into the following which is then sent to event-manager-api and inserted into the `all_events` table.

```
{
  :actor_id=>351369, :actor=>"aguy@gmail.com", :target_id=>650, :target=>"quickstart", :owner_id=>58,
  :owner=>"jon@heroku.com", :timestamp=>1357325958, :action=>"view-article",
  :attributes=>{:article_status=>"published", :article_title=>"Getting Started with Heroku"},
  :component => "devcenter"
}
```

The proxy can handle log streams from multiple apps simultaneously. The easiest way to bring online new apps is probably to have them conform to the currently recognized log format vs. adding [a new parser](https://github.com/heroku/devcenter-event-proxy/blob/master/lib/parsers/devcenter_message_parser.rb) to handle a different format.

## Monitoring

```
$ heroku addons:open librato
```

https://metrics.librato.com/dashboards/7502?source=delivere

There should be no errors shown, and the event deliveries should be around 10-40/min depending on time of day. 99p response times should be in the low 100s of ms.

![](http://f.cl.ly/items/2b0m2S131Y0V0f0B3q0q/Image%202014-01-08%20at%201.11.47%20PM.png)
