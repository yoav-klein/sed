#!/bin/bash

sed -n -E '/^deb http/{s/(.*)/\&\& echo "\1" >> \/etc\/apt\/sources.list \\/;p}' sources.list
