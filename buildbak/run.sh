#!/bin/sh
cd /usr/local/myblog;
hexo clean;
hexo g;
hexo s;
tail -f /dev/null;
