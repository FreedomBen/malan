# Still a WIP

# Command created by combining top two answers:
# - https://stackoverflow.com/a/4210072/2062384
# - https://stackoverflow.com/a/15736463/2062384

if [ -z "$1" ]; then
  echo "Error:  Pass first arg as Capitalized old name.  Example:  Malan"
  exit 1
fi

if [ -z "$2" ]; then
  echo "Error:  Pass second arg as Capitalized new name.  Example:  Lynky"
  exit 1
fi

OLD_NAME_CAP="$1"
NEW_NAME_CAP="$2"

OLD_NAME_LOWER="$(echo $OLD_NAME_CAP | awk '{ print tolower($0) }')"
NEW_NAME_LOWER="$(echo $NEW_NAME_CAP | awk '{ print tolower($0) }')"

OLD_NAME_UPPER="$(echo $OLD_NAME_CAP | awk '{ print toupper($0) }')"
NEW_NAME_UPPER="$(echo $NEW_NAME_CAP | awk '{ print toupper($0) }')"

# For examining inputs
#echo $OLD_NAME_CAP
#echo $NEW_NAME_CAP
#echo $OLD_NAME_LOWER
#echo $NEW_NAME_LOWER
#echo $OLD_NAME_UPPER
#echo $NEW_NAME_UPPER
#exit 1

# Replace tokens in files
for file in $(find . -type f -not \( -path './.git/*' -o -path './_build/*' -o -path './pgdata/*' -o -path './deps/*' \) | xargs); do
  echo $file;
  
  # Can (mostly) safely just sed the Capitalized and ALL CAPS versions
  sed -i -e "s/${OLD_NAME_CAP}/${NEW_NAME_CAP}/g" "$file";
  sed -i -e "s/${OLD_NAME_UPPER}/${NEW_NAME_UPPER}/g" "$file";

  # lower case isn't as safe.  Do these variations
  sed -i -e "s/:${OLD_NAME_LOWER}/:${NEW_NAME_LOWER}/g" "$file";
  sed -i -e "s/${OLD_NAME_LOWER}_web/${NEW_NAME_LOWER}_web/g" "$file";
  sed -i -e "s/${OLD_NAME_LOWER}_pod/${NEW_NAME_LOWER}_pod/g" "$file";
  sed -i -e "s/${OLD_NAME_LOWER}_dev/${NEW_NAME_LOWER}_dev/g" "$file";
  sed -i -e "s/${OLD_NAME_LOWER}_test/${NEW_NAME_LOWER}_test/g" "$file";
  sed -i -e "s/${OLD_NAME_LOWER}_postgres/${NEW_NAME_LOWER}_postgres/g" "$file";
done

# Explain how to rename files.  Needs work because 
echo "You probably want to rename the following files:"

for file in $(find . -iname "*${OLD_NAME_LOWER}*" -not \( -path './.git/*' -o -path './_build/*' -o -path './pgdata/*' -o -path './deps/*' \)); do
  newname="$(echo "$file" | sed -e "s/${OLD_NAME_LOWER}/${NEW_NAME_LOWER}/g")"
  #echo "Renaming '$file' to '$newname'"
  echo mv "$file" "$newname"
done


#CAP_VARIATIONS_END=(
#  ''
#  'Web'
#)
#
#CAP_VARIATIONS_BEGIN=(
#)
#
#LOWER_VARIATIONS_BEGIN=(
#  ':'
#)
#
#LOWER_VARIATIONS_END=(
#  '_pod'
#  '_dev'
#  '_test'
#)
#
#sed_term ()
#{
#  local old=$1
#  local new=$2
#  sed -i -e "s/${old}/${new}/g" "$i";
#}
#
#
#replace_term ()
#{
#  local old=$1
#  local new=$2
#  for i in $(findref -n "$1" | sed -e 's/:.*//g' | sort | uniq); do
#    #sed_term "$1" "$2"
#    sed -i -e "s/${old}/${new}/g" "$i";
#  done
#}
#
#
#  replace_term "${OLD_NAME}_pod" "${NEW_NAME}_pod"
#
#
#replace_term "${OLD_NAME}_pod" "${NEW_NAME}_pod"
#
#replace_term ":${OLD_LOWER}" ":${NEW_LOWER}"
