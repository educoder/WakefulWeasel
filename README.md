WakefulWeasel
=============

Pub/Sub for use with DrowsyDromedary, based on Faye.

See https://github.com/zuk/Backbone.Drowsy and https://github.com/zuk/DrowsyDromedary.

## Installation

    git clone https://github.com/educoder/WakefulWeasel.git
    npm install


## Start

Copy `config.json.example` into `config.json` and change values in config.json to suit your setup

    coffee weasel.coffee

or

    node weasel.js


### DrowsyDromedary

To enable persistence via DrowsyDromedary, make sure you have a `drowsy` key in your config with
keys as per `config.json.example`.

To disable Drowsy persistence, just remove the `drowsy` key from your config.

### MQTT

To enable the MQTT relay, make sure you have a `mqtt` key in the config. A `mqtt.broker_url` value
is required. The URL format is described at https://github.com/adamvr/MQTT.js/wiki/mqtt#mqttconnectbrokerurl-options.
`mqtt.client_options` can also be provied, as per https://github.com/adamvr/MQTT.js/wiki/client#mqttclientstreambuilder-options.


