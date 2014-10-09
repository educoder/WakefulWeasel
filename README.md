WakefulWeasel
=============

Pub/Sub for use with DrowsyDromedary, based on Faye.

See https://github.com/zuk/Backbone.Drowsy and https://github.com/zuk/DrowsyDromedary.

## Installation

    git clone https://github.com/educoder/WakefulWeasel.git
    npm install


## Configuration
WakefulWeasel is looking for a `config.json` in order to configure various settings. If no `config.json` file is present the following will be assumed:

```
port     7777
mount    /faye
timeout  30
```
Please note that *no persistance* will be enabled since no DrowsyDromedary instance is specified.

Use the provided `config.example.json`, copy it to `config.json` and change the values accordingly.

If you remove the `username` or `password` setting WakefulWeasel will **not** send the `Basic auth` header to the DrowsyDromedary server.
Should you use Drowsy with `Basic auth` enabled you **must** provide the correct `username` and `password` in your `config.json` or otherwise WakefulWeasel will not be able to persist data!

**Warning:** Do not add your username and password to any version control!
**Warning 2:** Never use Basic auth without HTTPS unless you are debugging locally!

## Start

Copy config.json.example into config.json and change values in config.json to suit your setup

    node weasel.js

