#!/usr/bin/env bash

for i in $(findref -n '\s+use MalanWeb.ConnCase' test/ \
  | awk -F : '{ print $1 }' \
  | sort \
  | uniq)
do
  echo "Changing '$i'"
  sed -i -E -e 's/\s+use MalanWeb.ConnCase.*/  use MalanWeb.ConnCase, async: true/g' "$i"
done

for i in $(findref -n '\s+use Malan.DataCase' test/ \
  | awk -F : '{ print $1 }' \
  | sort \
  | uniq)
do
  echo "Changing '$i'"
  sed -i -E -e 's/\s+use Malan.DataCase.*/  use Malan.DataCase, async: true/g' "$i"
done
