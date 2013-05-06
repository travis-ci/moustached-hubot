## Hubot scripts for moustache grooming

A collection of Hubot scripts from your friendly folks at Travis CI.

Includes support for:

- [OpsGenie](http://opsgenie.com). Run "help genie" for a list of commands
- [StatusPage.io](http://statuspage.io). Run "help status" for a list of commands

### Installation

Add the repository to your hubot's package.json:

```
dependencies: {
  "moustached-hubot": "git://github.com/travis-ci/moustached-hubot.git"
}
```

Include the package in your hubot's external-scripts.json

```
["moustached-hubot"]
```

### TODO

- Support for on-call schedule manipulation (forwards, who's on call, etc.) #opsgenie
- Support for scheduled maintenance #statuspage

### License

See LICENSE file.

Copyright (c) 2013 Travis CI GmbH
