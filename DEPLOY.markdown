This is mostly a not to my self, so I don't forget it.

To make a release, do:

    rake version:bump:patch
    rake release
    rake build
    gem push pkg/handsoap-*.gem

You need `jeweleer` and `gemcutter`, as well as login credentials for gemcutter.
