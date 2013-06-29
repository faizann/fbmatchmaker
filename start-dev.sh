#!/bin/sh
# NOTE: mustache templates need \ because they are not awesome.
exec erl -pa ebin edit deps/*/ebin -boot start_sasl \
    -sname fbmatchmaker_dev \
    -s ssl \
    -s apns \
    -s fbmatchmaker \
    -s reloader \
    -config sys.config
