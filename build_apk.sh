#!/bin/bash
cd /c/project/my_nexus
/c/Users/cine1/Documents/flutter/bin/flutter build apk --release 2>&1
echo "BUILD_EXIT_CODE=$?"
